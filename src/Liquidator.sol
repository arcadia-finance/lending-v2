/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LogExpMath } from "./libraries/LogExpMath.sol";
import { ERC20, SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { Owned } from "../lib/solmate/src/auth/Owned.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";
import { RiskModule } from "../lib/accounts-v2/src/RiskModule.sol";

contract Liquidator is Owned, ILiquidator {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The unit for fixed point numbers with 4 decimals precision.
    uint16 internal constant ONE_4 = 10_000;
    // Sets the begin price of the auction.
    // Defined as a percentage of openDebt, 4 decimals precision -> 15_000 = 150%.
    uint16 internal startPriceMultiplier;
    // Sets the minimum price the auction converges to.
    // Defined as a percentage of openDebt, 4 decimals precision -> 6000 = 60%.
    uint16 internal minPriceMultiplier;
    // The base of the auction price curve (exponential).
    // Determines how fast the auction price drops per second, 18 decimals precision.
    uint64 internal base;
    // Maximum time that the auction declines, after which price is equal to the minimum price set by minPriceMultiplier.
    // Time in seconds, with 0 decimals precision.
    uint32 internal cutoffTime;

    // Map Account => auctionInformation.
    mapping(address => AuctionInformation) public auctionInformation;

    // Struct with additional information about the auction of a specific Account.
    struct AuctionInformation {
        uint128 startDebt; // The open debt, same decimal precision as baseCurrency.
        uint32 startTime; // The timestamp the auction started.
        bool inAuction; // Flag indicating if the auction is still ongoing.
        uint16 startPriceMultiplier; // 4 decimals precision.
        uint16 minPriceMultiplier; // 4 decimals precision.
        uint32 cutoffTime; // Maximum time that the auction declines.
        address creditor; // The creditor that issued the debt.
        address[] assetAddresses; // The addresses of the assets in the Account. The order of the assets is the same as in the Account.
        uint32[] assetShares; // The distribution of the assets in the Account. It is in 6 decimal precision -> 1000000 = 100%, 100000 = 10% . The order of the assets is the same as in the Account.
        uint256[] assetAmounts; // The amount of assets in the Account. The order of the assets is the same as in the Account.
        uint256[] assetIds; // The ids of the assets in the Account. The order of the assets is the same as in the Account.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AuctionCurveParametersSet(uint64 base, uint32 cutoffTime);
    event AuctionFinished(address indexed account, address indexed creditor, uint128 startDebt);
    event MinimumPriceMultiplierSet(uint16 minPriceMultiplier);
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) {
        startPriceMultiplier = 15_000;
        minPriceMultiplier = 6000;
        cutoffTime = 14_400; //4 hours
        base = 999_807_477_651_317_446; //3600s halflife, 14_400 cutoff
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when the liquidateAccount function is called on an account that is already in an auction.
    error Liquidator_AuctionOngoing();
    // Thrown when cutOffTime is above maximum value.
    error Liquidator_CutOffTooHigh();
    // Thrown when cutOffTime is below minimum value.
    error Liquidator_CutOffTooLow();
    // Thrown if the auction was not successfully ended.
    error Liquidator_EndAuctionFailed();
    // Thrown when halfLifeTime is above maximum value.
    error Liquidator_HalfLifeTimeTooHigh();
    // Thrown when halfLifeTime is below minimum value.
    error Liquidator_HalfLifeTimeTooLow();
    // Thrown when the auction has not yet expired.
    error Liquidator_InvalidBid();
    // Thrown when the start price multiplier is above the maximum value.
    error Liquidator_MultiplierTooHigh();
    // Thrown when the start price multiplier is below minimum value.
    error Liquidator_MultiplierTooLow();
    // Thrown when an Account is not for sale.
    error Liquidator_NotForSale();
    // Thrown when caller is not valid.
    error Liquidator_Unauthorized();

    /*///////////////////////////////////////////////////////////////
                    AUCTION PRICE CURVE PARAMETERS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the parameters (base and cutOffTime) of the auction price curve (decreasing power function).
     * @param halfLifeTime The base is not set directly, but it's derived from a more intuitive parameter, the halfLifeTime:
     * The time ΔT_hl (in seconds with 0 decimals) it takes for the power function to halve in value.
     * @dev The relation between the base and the halfLife time (ΔT_hl):
     * The power function is defined as: N(t) = N(0) * (1/2)^(t/ΔT_hl).
     * Or simplified: N(t) = N(O) * base^t => base = 1/[2^(1/ΔT_hl)].
     * @param cutoffTime_ The Maximum time that the auction declines,
     * after which price is equal to the minimum price set by minPriceMultiplier.
     * @dev Setting a very short cutoffTime can be used by rogue owners to rug the junior tranche!!
     * Therefore the cutoffTime has hardcoded constraints.
     * @dev All calculations are done with 18 decimals precision.
     */
    function setAuctionCurveParameters(uint32 halfLifeTime, uint32 cutoffTime_) external onlyOwner {
        //Checks that new parameters are within reasonable boundaries.
        if (halfLifeTime <= 120) revert Liquidator_HalfLifeTimeTooLow(); // 2 minutes
        if (halfLifeTime >= 28_800) revert Liquidator_HalfLifeTimeTooHigh(); // 8 hours
        if (cutoffTime_ <= 3600) revert Liquidator_CutOffTooLow(); // 1 hour
        if (cutoffTime_ >= 64_800) revert Liquidator_CutOffTooHigh(); // 18 hours

        //Derive base from the halfLifeTime.
        uint64 base_ = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, 1e18 / halfLifeTime));

        //Check that LogExpMath.pow(base, timePassed) does not error at cutoffTime (due to numbers smaller than minimum precision).
        //Since LogExpMath.pow is a strictly decreasing function checking the power function at cutoffTime
        //guarantees that the function does not revert on all timestamps between start of the auction and the cutoffTime.
        LogExpMath.pow(base_, uint256(cutoffTime_) * 1e18);

        //Store the new parameters.
        base = base_;
        cutoffTime = cutoffTime_;

        emit AuctionCurveParametersSet(base_, cutoffTime_);
    }

    /**
     * @notice Sets the start price multiplier for the liquidator.
     * @param startPriceMultiplier_ The new start price multiplier, with 4 decimals precision.
     * @dev The start price multiplier is a multiplier that is used to increase the initial price of the auction.
     * Since the value of all assets are discounted with the liquidation factor, and because pricing modules will take a conservative
     * approach to price assets (eg. floor-prices for NFTs), the actual value of the assets being auctioned might be substantially higher
     * as the open debt. Hence the auction starts at a multiplier of the openDebt, but decreases rapidly (exponential decay).
     */
    function setStartPriceMultiplier(uint16 startPriceMultiplier_) external onlyOwner {
        if (startPriceMultiplier_ <= 10_000) revert Liquidator_MultiplierTooLow();
        if (startPriceMultiplier_ >= 30_100) revert Liquidator_MultiplierTooHigh();
        startPriceMultiplier = startPriceMultiplier_;

        emit StartPriceMultiplierSet(startPriceMultiplier_);
    }

    /**
     * @notice Sets the minimum price multiplier for the liquidator.
     * @param minPriceMultiplier_ The new minimum price multiplier, with 4 decimals precision.
     * @dev The minimum price multiplier sets a lower bound to which the auction price converges.
     */
    function setMinimumPriceMultiplier(uint16 minPriceMultiplier_) external onlyOwner {
        if (minPriceMultiplier_ >= 9100) revert Liquidator_MultiplierTooHigh();
        minPriceMultiplier = minPriceMultiplier_;

        emit MinimumPriceMultiplierSet(minPriceMultiplier_);
    }

    /*///////////////////////////////////////////////////////////////
                      LIQUIDATION INITIATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiate the liquidation of a specific account.
     * @param account The address of the account to be liquidated.
     * @dev We do not check if the address passed is an actual Arcadia Account.
     * A malicious msg.sender can pass a self created contract as Account (not an actual Arcadia-Account) that implemented startLiquidation().
     * This would successfully start an auction and the malicious non-Account would be in auction indefinitely,
     * but this does not block or impact any current or future 'real' auctions of Arcadia-Accounts.
     */
    function liquidateAccount(address account) external {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];

        // Check if the account is already in an auction.
        if (auctionInformation_.inAuction) revert Liquidator_AuctionOngoing();

        // Set the inAuction flag to true.
        auctionInformation_.inAuction = true;

        // Check if the Account is insolvent and if it is, start the liquidation in the Account.
        // startLiquidation will revert if the Account is still solvent.
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address creditor,
            uint256 debt,
            RiskModule.AssetValueAndRiskFactors[] memory assetValues
        ) = IAccount(account).startLiquidation(msg.sender);

        // Store the Account information.
        auctionInformation_.assetAddresses = assetAddresses;
        auctionInformation_.assetIds = assetIds;
        auctionInformation_.assetAmounts = assetAmounts;
        auctionInformation_.creditor = creditor;
        auctionInformation_.startDebt = uint128(debt);

        // Store the relative value of each asset (the "assetShare"), with respect to the total value of the Account.
        // These will be used to calculate the price of bids to partially liquidate the Account.
        auctionInformation_.assetShares = _getAssetShares(assetValues);

        // Store the auction price-curve parameters.
        // This ensures that changes of the price-curve parameters do not impact ongoing auctions.
        auctionInformation_.startPriceMultiplier = startPriceMultiplier;
        auctionInformation_.minPriceMultiplier = minPriceMultiplier;
        auctionInformation_.startTime = uint32(block.timestamp);
        auctionInformation_.cutoffTime = cutoffTime;
    }

    /**
     * @notice Calculate the relative value of each asset, with respect to the total value of the Account.
     * @param assetValues An array with the values of each asset in the Account.
     * @return assetDistributions An array of asset distribution percentages (in tenths of a percent, e.g., 10_000 represents 100%).
     */
    function _getAssetShares(RiskModule.AssetValueAndRiskFactors[] memory assetValues)
        internal
        pure
        returns (uint32[] memory assetDistributions)
    {
        uint256 length = assetValues.length;
        uint256 totalValue;
        for (uint256 i; i < length;) {
            unchecked {
                totalValue += assetValues[i].assetValue;
                ++i;
            }
        }
        assetDistributions = new uint32[](length);
        for (uint256 i; i < length;) {
            unchecked {
                // The asset distribution is calculated as a percentage of the total value of the assets.
                // "assetValue" is a uint256 in baseCurrency units, will never overflow
                assetDistributions[i] = uint32(assetValues[i].assetValue * ONE_4 / totalValue);
                ++i;
            }
        }
    }

    /*///////////////////////////////////////////////////////////////
                      LIQUIDATION BIDS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Places a bid.
     * @param account The contract address of the Account being liquidated.
     * @param askedAssetAmounts Array with the assets-amounts the bidder wants to buy.
     * @param endAuction_ Bool indicating that the auction can be ended after the bid..
     * @dev We use a dutch auction: price of the assets constantly decreases.
     * @dev The bidder is not obliged to set endAuction to True if the account is healthy after the bid,
     * but they are incentivised to do so by earning an additional "auctionTerminationReward".
     */
    function bid(address account, uint256[] memory askedAssetAmounts, bool endAuction_) external {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        // Calculate the current auction price of the assets being bought.
        uint256 totalShare = _calculateTotalShare(auctionInformation_, askedAssetAmounts);
        uint256 price = _calculateBidPrice(auctionInformation_, totalShare);

        // Transfer an amount of "price" in "baseCurrency" to the LendingPool to repay the Accounts debt.
        // The LendingPool will call a "transferFrom" from the bidder to the pool -> the bidder must approve the LendingPool.
        // If the amount transferred would exceed the debt, the surplus is paid out to the Account Owner and earlyTerminate is True.
        uint128 startDebt = auctionInformation_.startDebt;
        bool earlyTerminate =
            ILendingPool(auctionInformation_.creditor).auctionRepay(startDebt, price, account, msg.sender);

        // Transfer the assets to the bidder.
        IAccount(account).auctionBid(
            auctionInformation_.assetAddresses, auctionInformation_.assetIds, askedAssetAmounts, msg.sender
        );

        // If all the debt is repaid, the auction must be ended, even if the bidder did not set endAuction to true.
        if (earlyTerminate) {
            // Happy flow: All debt is repaid.
            // Stop the auction, no need to do a health check for the account since it has no debt anymore.
            auctionInformation_.inAuction = false;

            emit AuctionFinished(account, auctionInformation_.creditor, startDebt);
        }
        // If not all debt is repaid the bidder can still earn a termination incentive by ending the auction
        // if the Account is in a healthy state after the bid.
        // "_endAuction()" will silently fail without reverting, if the auction was not successfully ended.
        else if (endAuction_) {
            _endAuction(account, auctionInformation_);
        }
    }

    /**
     * @notice Calculates the share of the initial assets the bidder wants to buy.
     * @param auctionInformation_ The auction information.
     * @param askedAssetAmounts Array with the assets-amounts the bidder wants to buy.
     * @return totalShare The share of initial assets the bidder wants to buy, 4 decimals precision.
     * @dev totalShare is calculated based on the relative value of the assets when the auction was initiated.
     */
    function _calculateTotalShare(AuctionInformation storage auctionInformation_, uint256[] memory askedAssetAmounts)
        internal
        view
        returns (uint256 totalShare)
    {
        uint256[] memory assetAmounts = auctionInformation_.assetAmounts;
        uint32[] memory assetShares = auctionInformation_.assetShares;
        if (assetAmounts.length != askedAssetAmounts.length) {
            revert Liquidator_InvalidBid();
        }

        for (uint256 i; i < askedAssetAmounts.length;) {
            unchecked {
                // ToDo: check that there is no way we can get an amount 0 for an asset in an Account.
                totalShare += askedAssetAmounts[i] * assetShares[i] / assetAmounts[i];
                ++i;
            }
        }
    }

    /**
     * @notice Function returns the current auction price given time passed and a bid.
     * @param auctionInformation_ The auction information.
     * @param totalShare The share of initial assets the bidder wants to buy,
     * calculated based on the relative value of the assets when the auction was initiated.
     * @return price The price for which the bid can be purchased, denominated in the baseCurrency.
     * @dev We use a dutch auction: price of the assets constantly decreases.
     * @dev Price P(t) decreases exponentially over time: P(t) = Debt * S * [(SPM - MPM) * base^t + MPM]:
     * Debt: The total debt of the Account at the moment the auction was initiated.
     * S: The share of the assets being bought in the bid.
     * SPM: The startPriceMultiplier defines the initial price: P(0) = Debt * S * SPM (4 decimals precision).
     * MPM: The minPriceMultiplier defines the asymptotic end price for P(∞) = Debt * MPM (4 decimals precision).
     * base: defines how fast the exponential curve decreases (18 decimals precision).
     * t: time passed since start auction (in seconds, 18 decimals precision).
     * @dev LogExpMath was made in solidity 0.7, where operations were unchecked.
     */
    function _calculateBidPrice(AuctionInformation storage auctionInformation_, uint256 totalShare)
        internal
        view
        returns (uint256 price)
    {
        unchecked {
            // Calculate the time passed since the auction started.
            uint256 timePassed = block.timestamp - auctionInformation_.startTime;

            // Bring to 18 decimals precision, as required by LogExpMath.pow()
            // No overflow possible: uint32 * uint64.
            timePassed = timePassed * 1e18;

            // Cache minPriceMultiplier.
            uint256 minPriceMultiplier_ = auctionInformation_.minPriceMultiplier;

            // Calculate askPrice as: P = Debt * S * [(SPM - MPM) * base^t + MPM]
            // P: price, denominated in the baseCurrency.
            // Debt: The initial debt of the Account, denominated in the baseCurrency.
            // S: The share of assets being bought, 4 decimals precision
            // SPM and MPM: multipliers to scale the price curve, 4 decimals precision.
            // base^t: the exponential decay over time of the price (strictly smaller than 1), has 18 decimals precision.
            // Since the result must be denominated in the baseCurrency, we need to divide by 1e26 (1e18 + 1e4 + 1e4).
            // No overflow possible: uint128 * uint32 * uint18 * uint18.
            price = (
                auctionInformation_.startDebt * totalShare
                    * (
                        LogExpMath.pow(base, timePassed) * (auctionInformation_.startPriceMultiplier - minPriceMultiplier_)
                            + 1e18 * uint256(minPriceMultiplier_)
                    )
            ) / 1e26;
        }
    }

    /*///////////////////////////////////////////////////////////////
                    LIQUIDATION TERMINATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Ends an auction and settles the liquidation.
     * @param account The contract address of the account in liquidation.
     */
    function endAuction(address account) external {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];

        // Check if the account is being auctioned.
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        bool success = _endAuction(account, auctionInformation_);
        if (!success) revert Liquidator_EndAuctionFailed();
    }

    /**
     * @notice Ends an auction and settles the liquidation.
     * @param account The contract address of the account in liquidation.
     * @param auctionInformation_ The struct containing all the auction information.
     * @dev There are four different conditions on which an auction can be successfully ended.
     * This function will check three of the four conditions (the fourth is already checked in the bid-function):
     *  1) The Account is back in a healthy state (collateral value is equal or bigger than the used margin).
     *  2) There are no remaining assets in the Account left to sell.
     *  3) The Auction did not finish within the cutoff-period.
     *  4) All open debt was repaid (not checked within this function).
     * @dev If the third condition is met, an emergency process is triggered.
     * The auction will be stopped and the remaining assets of the Account will be transferred to the Liquidator owner.
     * The tranches of the liquidity pool will pay for the bad debt.
     * The protocol will sell/auction the assets manually to recover the debt.
     * The protocol will later "donate" these proceeds back to the
     * impacted Tranches, this last step is not enforced by the smart contracts.
     * While this process is not fully trustless, it is the only way to solve an extreme unhappy flow,
     * where an auction did not end within cutoffTime (due to market or technical reasons).
     */
    function _endAuction(address account, AuctionInformation storage auctionInformation_)
        internal
        returns (bool success)
    {
        // Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation_.inAuction = false;

        // Cache variables.
        uint256 startDebt = auctionInformation_.startDebt;
        address creditor = auctionInformation_.creditor;

        uint256 collateralValue = IAccount(account).getCollateralValue();
        uint256 usedMargin = IAccount(account).getUsedMargin();

        // Check the different conditions to end the auction.
        if (collateralValue >= usedMargin) {
            // Happy flow: Account is back in a healthy state.
            ILendingPool(creditor).settleLiquidationHappyFlow(account, startDebt, msg.sender);
        } else if (collateralValue == 0) {
            // Unhappy flow: All collateral is sold.
            ILendingPool(creditor).settleLiquidationUnhappyFlow(account, startDebt, msg.sender);
        } else if (block.timestamp - auctionInformation_.startTime > auctionInformation_.cutoffTime) {
            // Unhappy flow: Auction did not end within the cutoffTime.
            ILendingPool(creditor).settleLiquidationUnhappyFlow(account, startDebt, msg.sender);
            // All remaining assets are transferred to the owner of Liquidator.sol,
            // And a manual (trusted) liquidation has to be done.
            IAccount(account).auctionBoughtIn(owner);
        } else {
            // None of the conditions to end the auction are met.
            return false;
        }

        emit AuctionFinished(account, auctionInformation_.creditor, uint128(startDebt));
        return true;
    }
}
