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

    // Precision used is 4 decimals
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
        address originalOwner; // The address of the original owner of the Account.
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
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);
    event MinimumPriceMultiplierSet(uint16 minPriceMultiplier);
    event AuctionFinished(
        address indexed account, address indexed creditor, uint128 startDebt, uint128 totalBids, uint128 badDebt
    );

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
    // Thrown when the Account has no bad debt in current situation
    error Liquidator_NoBadDebt();
    // Thrown when an Account is not for sale.
    error Liquidator_NotForSale();
    // Thrown when the auction has not yet expired.
    error Liquidator_AuctionNotExpired();
    // Thrown when the bid function is called with invalid asset amounts or ids.
    error Liquidator_InvalidBid();
    // Thrown when the endAuction called and the account is still unhealthy
    error Liquidator_AccountNotHealthy();
    // Thrown when halfLifeTime is below minimum value.
    error Liquidator_HalfLifeTimeTooLow();
    // Thrown when halfLifeTime is above maximum value.
    error Liquidator_HalfLifeTimeTooHigh();
    // Thrown when cutOffTime is below minimum value.
    error Liquidator_CutOffTooLow();
    // Thrown when cutOffTime is above maximum value.
    error Liquidator_CutOffTooHigh();
    // Thrown when the start price multiplier is below minimum value.
    error Liquidator_MultiplierTooLow();
    // Thrown when the start price multiplier is above the maximum value.
    error Liquidator_MultiplierTooHigh();
    // Thrown when caller is not valid.
    error Liquidator_Unauthorized();
    // Thrown if the Account still has remaining value.
    error Liquidator_AccountValueIsNotZero();

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
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
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Initiate the liquidation of a specific account.
     * @param account The address of the account to be liquidated.
     * @dev This function is used to start the liquidation process for a given account. It performs the following steps:
     * 1. Sets the initiator address to the sender and flags the account as being in an auction.
     * 2. Calls the `startLiquidation` function on the `IAccount` contract to check if the account is solvent
     *    and start the liquidation process within the account.
     * 3. Checks if the account has debt in the lending pool and, if so, increments the auction in progress counter.
     * 4. Records the start time and asset distribution for the auction.
     * 5. Emits an `AuctionStarted` event to notify observers about the initiation of the liquidation.
     */
    function liquidateAccount(address account) external {
        // Check if the account is already in an auction.
        if (auctionInformation[account].inAuction) revert Liquidator_AuctionOngoing();

        // Set the inAuction flag to true.
        auctionInformation[account].inAuction = true;

        // Call Account to check if account is insolvent and if it is insolvent start the liquidation in the Account.
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address owner_,
            address creditor,
            uint256 debt,
            RiskModule.AssetValueAndRiskFactors[] memory riskValues
        ) = IAccount(account).startLiquidation(msg.sender);

        // Fill the auction struct
        auctionInformation[account].startDebt = uint128(debt);
        auctionInformation[account].startPriceMultiplier = startPriceMultiplier;
        auctionInformation[account].minPriceMultiplier = minPriceMultiplier;
        auctionInformation[account].startTime = uint32(block.timestamp);
        auctionInformation[account].assetShares = _getAssetDistribution(riskValues);
        auctionInformation[account].assetAddresses = assetAddresses;
        auctionInformation[account].assetIds = assetIds;
        auctionInformation[account].assetAmounts = assetAmounts;
        auctionInformation[account].cutoffTime = cutoffTime;
        auctionInformation[account].creditor = creditor;
        auctionInformation[account].originalOwner = owner_;
    }

    /**
     * @notice Calculate asset distribution percentages based on provided risk values.
     * @param riskValues_ An array of risk values for assets.
     * @return assetDistributions An array of asset distribution percentages (in tenths of a percent, e.g., 10_000 represents 100%).
     */
    function _getAssetDistribution(RiskModule.AssetValueAndRiskFactors[] memory riskValues_)
        internal
        pure
        returns (uint32[] memory assetDistributions)
    {
        uint256 length = riskValues_.length;
        uint256 totalValue;
        for (uint256 i; i < length;) {
            unchecked {
                totalValue += riskValues_[i].assetValue;
                ++i;
            }
        }
        assetDistributions = new uint32[](length);
        for (uint256 i; i < length;) {
            unchecked {
                // The asset distribution is calculated as a percentage of the total value of the assets.
                // assetvalue is a uint256 in basecurrency units, will never overflow
                assetDistributions[i] = uint32(riskValues_[i].assetValue * ONE_4 / totalValue);
                ++i;
            }
        }
    }

    /**
     * @notice Places a bid.
     * @param account The contract address of the Account being liquidated.
     * @param askedAssetAmounts Array with the assets-amounts the bidder wants to buy.
     * @param endAuction Bool indicating if the bidder wants to end the auction.
     * @dev We use a dutch auction: price of the assets constantly decreases.
     */
    function bid(address account, uint256[] memory askedAssetAmounts, bool endAuction) external {
        // Check if the account is already in an auction.
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        // Calculate the current auction price.
        uint256 askedShare = _calculateAskedShare(auctionInformation_, askedAssetAmounts);
        uint256 price = _calculateBidPrice(auctionInformation_, askedShare);

        // Repay the debt of the account.
        bool earlyTerminate = ILendingPool(auctionInformation_.creditor).auctionRepay(
            auctionInformation_.startDebt, auctionInformation_.originalOwner, price, account, msg.sender
        );

        // Transfer the assets to the bidder.
        IAccount(account).auctionBid(
            auctionInformation_.assetAddresses, auctionInformation_.assetIds, askedAssetAmounts, msg.sender
        );

        // If all the debt is paid back, end the auction early.
        // No need to do a health check for the account since it has no debt anymore.
        if (earlyTerminate) {
            // Stop the auction
            auctionInformation[account].inAuction = false;
        }
        // If not all debt is repaid the bidder can still earn a termination incentive by ending the auction
        // if the Account is in a healthy state after the bid.
        // "_knockDown()" will silently fail if the Account would be unhealthy without reverting.
        else if (endAuction) {
            _knockDown(account, auctionInformation_);
        }
    }

    /**
     * @notice Calculates the share of total assets the bidder wants to buy.
     * @param auctionInformation_ The auction information.
     * @param askedAssetAmounts Array with the assets-amounts the bidder wants to buy.
     * @return askedShare The share of total assets the bidder wants to buy, 6 decimals precision.
     * calculated based on the relative value of the assets when the auction was initiated.
     * @dev We use a dutch auction: price of the assets constantly decreases.
     */
    function _calculateAskedShare(AuctionInformation storage auctionInformation_, uint256[] memory askedAssetAmounts)
        internal
        view
        returns (uint256 askedShare)
    {
        uint256[] memory assetAmounts = auctionInformation_.assetAmounts;
        uint32[] memory assetShares = auctionInformation_.assetShares;
        if (assetAmounts.length != askedAssetAmounts.length) {
            revert Liquidator_InvalidBid();
        }

        // Calculate the share of total assets the bidder wants to buy.
        for (uint256 i; i < askedAssetAmounts.length;) {
            unchecked {
                // ToDo: check that there is no way we can get an amount 0 for an asset in an Account.
                askedShare += assetShares[i] * askedAssetAmounts[i] / assetAmounts[i];
                ++i;
            }
        }
    }

    /**
     * @notice Function returns the current auction price given time passed and a bid.
     * @param auctionInformation_ The auction information.
     * @param askedShare The share of total assets the bidder wants to buy,
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
    function _calculateBidPrice(AuctionInformation storage auctionInformation_, uint256 askedShare)
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
            // S: The share of assets being bought, 6 decimals precision
            // SPM and MPM: multipliers to scale the price curve, 4 decimals precision.
            // base^t: the exponential decay over time of the price (strictly smaller than 1), has 18 decimals precision.
            // Since the result must be denominated in the baseCurrency, we need to divide by 1e26 (1e18 + 1e4 + 1e4).
            // No overflow possible: uint128 * uint32 * uint18 * uint8.
            price = (
                auctionInformation_.startDebt * askedShare
                    * (
                        LogExpMath.pow(base, timePassed) * (auctionInformation_.startPriceMultiplier - minPriceMultiplier_)
                            + 1e18 * uint256(minPriceMultiplier_)
                    )
            ) / 1e26;
        }
    }

    /**
     * @notice Ends an auction after the cutoff period.
     * @param account The account to end the liquidation for.
     */
    function endAuctionAfterCutoff(address account) external {
        // Check if the account is already in an auction.
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        // Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[account].inAuction = false;

        uint256 timePassed;
        unchecked {
            timePassed = block.timestamp - auctionInformation_.startTime;
        }
        if (timePassed <= auctionInformation_.cutoffTime) revert Liquidator_AuctionNotExpired();

        _endAuction(
            account, auctionInformation_.originalOwner, auctionInformation_.creditor, auctionInformation_.startDebt
        );
    }

    /**
     * @notice Ends an auction when the remaining value of assets is zero.
     * @param account The account to end the liquidation for.
     */
    function endAuctionNoRemainingValue(address account) external {
        // Check if the account is already in an auction.
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        // Stop the auction, this will prevent any possible reentrance attacks.
        auctionInformation[account].inAuction = false;

        // Check if the Account has no remaining value.
        uint256 accountValue = IAccount(account).getAccountValue(IAccount(account).baseCurrency());
        if (accountValue != 0) revert Liquidator_AccountValueIsNotZero();

        _endAuction(
            account, auctionInformation_.originalOwner, auctionInformation_.creditor, auctionInformation_.startDebt
        );
    }

    /**
     * @notice Ends an auction, settles the liquidation and transfers all remaining assets of the Account to the procotol owner.
     * @param account The account to end the liquidation for.
     */
    function _endAuction(address account, address originalOwner, address creditor, uint256 startDebt) internal {
        ILendingPool(creditor).settleLiquidation(account, originalOwner, startDebt, msg.sender, 0);

        // Transfer all the left-over assets to the protocol owner.
        IAccount(account).auctionBoughtIn(owner);

        emit AuctionFinished(account, creditor, uint128(startDebt), 0, 0);
    }

    /**
     * @notice Ends an auction when an Account has remaining debt and is healthy.
     * @param account The account to end the liquidation for.
     */
    function knockDown(address account) external {
        // Check if the account is already in an auction.
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        if (!auctionInformation_.inAuction) revert Liquidator_NotForSale();

        _knockDown(account, auctionInformation_);
    }

    /**
     * @notice Ends an auction when an Account has remaining debt and is healthy.
     * @param account The account to end the liquidation for.
     * @param auctionInformation_ The struct containing all the info of that specific auction.
     */
    function _knockDown(address account, AuctionInformation storage auctionInformation_) internal {
        // Set the inAuction flag to false.
        auctionInformation[account].inAuction = false;

        (bool success,,) = IAccount(account).isAccountHealthy(0, 0);
        if (!success) revert Liquidator_AccountNotHealthy();

        uint256 startDebt = auctionInformation_.startDebt;

        // Call settlement of the debt in the creditor
        ILendingPool(auctionInformation_.creditor).settleLiquidation(
            account, auctionInformation_.originalOwner, startDebt, msg.sender, 0
        );

        emit AuctionFinished(account, auctionInformation_.creditor, uint128(startDebt), 0, 0);
    }
}
