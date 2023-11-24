/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { AssetValueAndRiskFactors } from "../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { ERC20, SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount } from "./interfaces/IAccount.sol";
import { ILendingPool } from "./interfaces/ILendingPool.sol";
import { ILiquidator } from "./interfaces/ILiquidator.sol";
import { LogExpMath } from "./libraries/LogExpMath.sol";
import { LiquidatorErrors } from "./libraries/Errors.sol";
import { Owned } from "../lib/solmate/src/auth/Owned.sol";

/**
 * @title Liquidator.
 * @author Pragma Labs
 * @notice The Liquidator manages the Dutch auctions, used to sell collateral of unhealthy Arcadia Accounts.
 */
contract Liquidator is Owned, ILiquidator {
    using SafeTransferLib for ERC20;
    /* //////////////////////////////////////////////////////////////
                               CONSTANTS
    ////////////////////////////////////////////////////////////// */

    // The unit for fixed point numbers with 4 decimals precision.
    uint16 internal constant ONE_4 = 10_000;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The base of the auction price curve (decreasing power function).
    // Determines in what time the auction price halves, 18 decimals precision.
    uint64 internal base;
    // The time after which the auction is considered not successful, in seconds.
    uint32 internal cutoffTime;
    // Sets the begin price of the auction, 4 decimals precision.
    uint16 internal startPriceMultiplier;
    // Sets the minimum price the auction converges to, 4 decimals precision.
    uint16 internal minPriceMultiplier;

    // Map Account => auctionInformation.
    mapping(address => AuctionInformation) public auctionInformation;

    // Struct with additional information about the auction of a specific Account.
    struct AuctionInformation {
        // The open debt, denominated in the Creditor's baseCurrency.
        uint128 startDebt;
        // The base of the auction price curve.
        uint64 base;
        // The timestamp after which the auction is considered not successful.
        uint32 cutoffTimeStamp;
        // The timestamp the auction started.
        uint32 startTime;
        // Sets the begin price of the auction, 4 decimals precision.
        uint16 startPriceMultiplier;
        // Sets the minimum price the auction converges to, 4 decimals precision.
        uint16 minPriceMultiplier;
        // Flag indicating if the auction is still ongoing.
        bool inAuction;
        // The time after which the auction is considered not successful, in seconds.
        address creditor;
        // The contract address of each asset in the Account, at the moment the liquidation was initiated.
        address[] assetAddresses;
        // The relative value of each asset in the Account (the "assetShare") with respect to the total value of the Account,
        // at the moment the liquidation was initiated, 4 decimals precision.
        uint32[] assetShares;
        // The amount of each asset in the Account, at the moment the liquidation was initiated.
        uint256[] assetAmounts;
        // The ids of each asset in the Account, at the moment the liquidation was initiated.
        uint256[] assetIds;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event AuctionCurveParametersSet(
        uint64 base, uint32 cutoffTime, uint16 startPriceMultiplier, uint16 minPriceMultiplier
    );
    event AuctionFinished(address indexed account, address indexed creditor, uint128 startDebt);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) {
        // Half life of 3600s.
        base = 999_807_477_651_317_446;
        // 4 hours.
        cutoffTime = 14_400;
        // 150%.
        startPriceMultiplier = 15_000;
        // 60%.
        minPriceMultiplier = 6000;

        emit AuctionCurveParametersSet(999_807_477_651_317_446, 14_400, 15_000, 6000);
    }

    /*///////////////////////////////////////////////////////////////
                    AUCTION PRICE CURVE PARAMETERS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the parameters of the auction price curve (decreasing power function).
     * @param halfLifeTime The base is not set directly, but it's derived from a more intuitive parameter, the halfLifeTime:
     * The time ΔT_hl (in seconds with 0 decimals) it takes for the power function to halve in value.
     * @param cutoffTime_ The time after which the auction is considered not successful.
     * After the cutoffTime, the remaining assets are transferred to the protocol owner to be sold manually.
     * @param startPriceMultiplier_ The start price multiplier, with 4 decimals precision.
     * @param minPriceMultiplier_ The minimum price multiplier, with 4 decimals precision.
     * @dev The relation between the base and the halfLife time (ΔT_hl):
     * The power function is defined as: N(t) = N(0) * (1/2)^(t/ΔT_hl).
     * Or simplified: N(t) = N(O) * base^t => base = 1/[2^(1/ΔT_hl)].
     * @dev Setting a very short cutoffTime can be used by rogue owners to rug the most junior tranche(s)!!
     * Therefore the cutoffTime has hardcoded constraints.
     * @dev The start price multiplier is a multiplier that is used to increase the initial price of the auction.
     * Since the value of all assets are discounted with the liquidation factor, and because pricing modules will take a conservative
     * approach to price assets (eg. floor-prices for NFTs), the actual value of the assets being auctioned might be substantially higher
     * than the open debt. Hence the auction starts at a multiplier of the openDebt, but decreases rapidly (exponential decay).
     * @dev The minimum price multiplier sets a lower bound to which the auction price converges.
     * @dev All calculations are done with 18 decimals precision.
     */
    function setAuctionCurveParameters(
        uint32 halfLifeTime,
        uint32 cutoffTime_,
        uint16 startPriceMultiplier_,
        uint16 minPriceMultiplier_
    ) external onlyOwner {
        // Checks that halfLifeTime and cutoffTime_ are within reasonable boundaries.
        if (halfLifeTime < 120) revert LiquidatorErrors.HalfLifeTimeTooLow(); // 2 minutes.
        if (halfLifeTime > 28_800) revert LiquidatorErrors.HalfLifeTimeTooHigh(); // 8 hours.
        if (cutoffTime_ < 3600) revert LiquidatorErrors.CutOffTooLow(); // 1 hour.
        if (cutoffTime_ > 64_800) revert LiquidatorErrors.CutOffTooHigh(); // 18 hours.

        // Derive base from the halfLifeTime.
        uint64 base_ = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, 1e18 / halfLifeTime));

        // Check that LogExpMath.pow(base, timePassed) does not error at cutoffTime (due to numbers smaller than minimum precision).
        // Since LogExpMath.pow is a strictly decreasing function checking the power function at cutoffTime
        // guarantees that the function does not revert on all timestamps between start of the auction and the cutoffTime.
        LogExpMath.pow(base_, uint256(cutoffTime_) * 1e18);

        // Checks that startPriceMultiplier_ and minPriceMultiplier_ are within reasonable boundaries.
        if (startPriceMultiplier_ < 10_000) revert LiquidatorErrors.MultiplierTooLow();
        if (startPriceMultiplier_ > 30_000) revert LiquidatorErrors.MultiplierTooHigh();
        if (minPriceMultiplier_ > 9000) revert LiquidatorErrors.MultiplierTooHigh();

        // Store the new parameters.
        emit AuctionCurveParametersSet(
            base = base_,
            cutoffTime = cutoffTime_,
            startPriceMultiplier = startPriceMultiplier_,
            minPriceMultiplier = minPriceMultiplier_
        );
    }

    /*///////////////////////////////////////////////////////////////
                      LIQUIDATION INITIATION
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiate the liquidation of an Account.
     * @param account The contract address of the Account to be liquidated.
     * @dev We do not check if the address passed is an actual Arcadia Account.
     * A malicious msg.sender can pass a self created contract as Account (not an actual Arcadia-Account),
     * that implemented startLiquidation().
     * This would successfully start an auction and the malicious non-Account might be in auction indefinitely,
     * but this does not block or impact any current or future 'real' auctions of Arcadia-Accounts.
     */
    function liquidateAccount(address account) external {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];

        // Check if the account is already being auctioned.
        if (auctionInformation_.inAuction) revert LiquidatorErrors.AuctionOngoing();

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
            AssetValueAndRiskFactors[] memory assetValues
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
        auctionInformation_.base = base;
        auctionInformation_.startTime = uint32(block.timestamp);
        auctionInformation_.cutoffTimeStamp = uint32(block.timestamp) + cutoffTime;
        auctionInformation_.startPriceMultiplier = startPriceMultiplier;
        auctionInformation_.minPriceMultiplier = minPriceMultiplier;
    }

    /**
     * @notice Calculate the relative value of each asset, with respect to the total value of the Account.
     * @param assetValues An array with the values of each asset in the Account.
     * @return assetShares An array of asset shares, with 4 decimals precision.
     */
    function _getAssetShares(AssetValueAndRiskFactors[] memory assetValues)
        internal
        pure
        returns (uint32[] memory assetShares)
    {
        uint256 length = assetValues.length;
        uint256 totalValue;
        for (uint256 i; i < length;) {
            unchecked {
                totalValue += assetValues[i].assetValue;
                ++i;
            }
        }
        assetShares = new uint32[](length);
        for (uint256 i; i < length;) {
            unchecked {
                // The asset shares are calculated relative to the total value of the Account.
                // "assetValue" is a uint256 in baseCurrency units, will never overflow.
                assetShares[i] = uint32(assetValues[i].assetValue * ONE_4 / totalValue);
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
     * @param endAuction_ Bool indicating that the auction can be ended after the bid.
     * @dev We use a Dutch auction: price of the assets constantly decreases.
     * @dev The "askedAssetAmounts" array should have equal length as the stored "assetAmounts" array.
     * An amount 0 should be passed for assets the bidder does not want to buy.
     * @dev The bidder is not obliged to set endAuction to True if the account is healthy after the bid,
     * but they are incentivised to do so by earning an additional "auctionTerminationReward".
     */
    function bid(address account, uint256[] memory askedAssetAmounts, bool endAuction_) external {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert LiquidatorErrors.NotForSale();

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
            // Stop the auction, no need to do a health check for the account since it has no debt anymore.
            auctionInformation_.inAuction = false;

            emit AuctionFinished(account, auctionInformation_.creditor, startDebt);
        }
        // If not all debt is repaid, the bidder can still earn a termination incentive by ending the auction
        // if one of the conditions to end the auction is met.
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
            revert LiquidatorErrors.InvalidBid();
        }

        for (uint256 i; i < askedAssetAmounts.length;) {
            unchecked {
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
     * @dev We use a Dutch auction: price of the assets constantly decreases.
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
            // Calculate the time passed since the auction started and bring to 18 decimals precision,
            // as required by LogExpMath.pow()
            // No overflow possible: uint32 * uint64.
            uint256 timePassed = (block.timestamp - auctionInformation_.startTime) * 1e18;

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
                        LogExpMath.pow(auctionInformation_.base, timePassed)
                            * (auctionInformation_.startPriceMultiplier - minPriceMultiplier_)
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
        if (!auctionInformation_.inAuction) revert LiquidatorErrors.NotForSale();

        bool success = _endAuction(account, auctionInformation_);
        if (!success) revert LiquidatorErrors.EndAuctionFailed();
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
     * The Tranches of the liquidity pool will pay for the bad debt.
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
        // Stop the auction.
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
        } else if (block.timestamp > auctionInformation_.cutoffTimeStamp) {
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
