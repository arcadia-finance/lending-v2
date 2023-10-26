/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LogExpMath } from "./libraries/LogExpMath.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { ERC20, SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount_NEW } from "./interfaces/IAccount_NEW.sol";
import { ILendingPool_NEW } from "./interfaces/ILendingPool_NEW.sol";
import { Owned } from "lib/solmate/src/auth/Owned.sol";
import { ILiquidator_NEW } from "./interfaces/ILiquidator_NEW.sol";
import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract Liquidator_NEW is Owned {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Reentrancy lock.
    uint256 locked;

    // Sets the begin price of the auction.
    // Defined as a percentage of openDebt, 2 decimals precision -> 150 = 150%.
    uint16 internal startPriceMultiplier;
    // Sets the minimum price the auction converges to.
    // Defined as a percentage of openDebt, 2 decimals precision -> 60 = 60%.
    uint8 internal minPriceMultiplier;
    // The base of the auction price curve (exponential).
    // Determines how fast the auction price drops per second, 18 decimals precision.
    uint64 internal base;
    // Maximum time that the auction declines, after which price is equal to the minimum price set by minPriceMultiplier.
    // Time in seconds, with 0 decimals precision.
    uint16 internal cutoffTime;
    // Fee paid to the Liquidation Initiator.
    // Defined as a fraction of the openDebt with 2 decimals precision.
    // Absolute fee can be further capped to a max amount by the creditor.
    uint8 internal initiatorRewardWeight;
    // Penalty the Account owner has to pay to the trusted Creditor on top of the open Debt for being liquidated.
    // Defined as a fraction of the openDebt with 2 decimals precision.
    uint8 internal penaltyWeight;

    // Map Account => auctionInformation.
    mapping(address => AuctionInformation) public auctionInformation;

    // Struct with additional information about the auction of a specific Account.
    struct AuctionInformation {
        uint256 startPrice;
        uint128 startDebt; // The open debt, same decimal precision as baseCurrency.
        uint32 startTime; // The timestamp the auction started.
        uint256 totalBids; // The total amount of baseCurrency that has been bid on the auction.
        bool inAuction; // Flag indicating if the auction is still ongoing.
        uint80 maxInitiatorFee; // The max initiation fee, same decimal precision as baseCurrency.
        address initiator; // The address of the initiator of the auction.
        uint8 initiatorRewardWeight; // 2 decimals precision.
        uint8 penaltyWeight; // 2 decimals precision.
        uint8 closingRewardWeight; // 2 decimals precision.
        address trustedCreditor; // The creditor that issued the debt.
        address[] assetAddresses; // The addresses of the assets in the Account. The order of the assets is the same as in the Account.
        uint32[] assetShares; // The distribution of the assets in the Account. it is in 6 decimal precision -> 1000000 = 100%, 100000 = 10% . The order of the assets is the same as in the Account.
        uint256[] assetAmounts; // The amount of assets in the Account. The order of the assets is the same as in the Account.
        uint256[] assetIds; // The ids of the assets in the Account. The order of the assets is the same as in the Account.
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight);
    event AuctionCurveParametersSet(uint64 base, uint16 cutoffTime);
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);
    event MinimumPriceMultiplierSet(uint8 minPriceMultiplier);
    event AuctionStarted(address indexed account, address indexed creditor, address baseCurrency, uint128 openDebt);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) {
        locked = 1;
        initiatorRewardWeight = 1;
        penaltyWeight = 5;
        startPriceMultiplier = 150;
        minPriceMultiplier = 60;
        cutoffTime = 14_400; //4 hours
        base = 999_807_477_651_317_446; //3600s halflife, 14_400 cutoff
    }

    /* //////////////////////////////////////////////////////////////
                                ERRORS
    ////////////////////////////////////////////////////////////// */

    // Thrown when the liquidateAccount function is called on an account that is already in an auction.
    error Liquidator_AuctionOngoing();

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier nonReentrant() {
        require(locked == 1, "L: REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Sets the liquidation weights.
     * @param initiatorRewardWeight_ Fee paid to the Liquidation Initiator.
     * @param penaltyWeight_ Penalty paid by the Account owner to the trusted Creditor.
     * @dev Each weight has 2 decimals precision (50 equals 0,5 or 50%).
     */
    function setWeights(uint256 initiatorRewardWeight_, uint256 penaltyWeight_) external onlyOwner {
        require(initiatorRewardWeight_ + penaltyWeight_ <= 11, "LQ_SW: Weights Too High");

        initiatorRewardWeight = uint8(initiatorRewardWeight_);
        penaltyWeight = uint8(penaltyWeight_);

        emit WeightsSet(uint8(initiatorRewardWeight_), uint8(penaltyWeight_));
    }

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
    function setAuctionCurveParameters(uint16 halfLifeTime, uint16 cutoffTime_) external onlyOwner {
        //Checks that new parameters are within reasonable boundaries.
        require(halfLifeTime > 120, "LQ_SACP: halfLifeTime too low"); // 2 minutes
        require(halfLifeTime < 28_800, "LQ_SACP: halfLifeTime too high"); // 8 hours
        require(cutoffTime_ > 3600, "LQ_SACP: cutoff too low"); // 1 hour
        require(cutoffTime_ < 64_800, "LQ_SACP: cutoff too high"); // 18 hours

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
     * @param startPriceMultiplier_ The new start price multiplier, with 2 decimals precision.
     * @dev The start price multiplier is a multiplier that is used to increase the initial price of the auction.
     * Since the value of all assets are discounted with the liquidation factor, and because pricing modules will take a conservative
     * approach to price assets (eg. floor-prices for NFTs), the actual value of the assets being auctioned might be substantially higher
     * as the open debt. Hence the auction starts at a multiplier of the openDebt, but decreases rapidly (exponential decay).
     */
    function setStartPriceMultiplier(uint16 startPriceMultiplier_) external onlyOwner {
        require(startPriceMultiplier_ > 100, "LQ_SSPM: multiplier too low");
        require(startPriceMultiplier_ < 301, "LQ_SSPM: multiplier too high");
        startPriceMultiplier = startPriceMultiplier_;

        emit StartPriceMultiplierSet(startPriceMultiplier_);
    }

    /**
     * @notice Sets the minimum price multiplier for the liquidator.
     * @param minPriceMultiplier_ The new minimum price multiplier, with 2 decimals precision.
     * @dev The minimum price multiplier sets a lower bound to which the auction price converges.
     */
    function setMinimumPriceMultiplier(uint8 minPriceMultiplier_) external onlyOwner {
        require(minPriceMultiplier_ < 91, "LQ_SMPM: multiplier too high");
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
     * 2. Calls the `checkAndStartLiquidation` function on the `IAccount_NEW` contract to check if the account is solvent
     *    and start the liquidation process within the account.
     * 3. Checks if the account has debt in the lending pool and, if so, increments the auction in progress counter.
     * 4. Calculates the starting price for the liquidation based on the account's debt.
     * 5. Records the start time and asset distribution for the auction.
     * 6. Emits an `AuctionStarted` event to notify observers about the initiation of the liquidation.
     */
    function liquidateAccount(address account) external nonReentrant {
        // Check if the account is already in an auction.
        if (auctionInformation[account].inAuction) revert Liquidator_AuctionOngoing();

        // Store the initiator address and set the inAuction flag to true.
        auctionInformation[account].initiator = msg.sender;
        auctionInformation[account].inAuction = true;

        // Call Account to check if account is solvent and if it is solvent start the liquidation in the Account.
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address creditor,
            uint256 debt,
            RiskModule.AssetValueAndRiskVariables[] memory riskValues
        ) = IAccount_NEW(account).checkAndStartLiquidation();

        // Check if the account has debt in the lending pool and if so, increment auction in progress counter.
        ILendingPool_NEW(creditor).startLiquidation(account, debt);

        // Fill the auction struct
        auctionInformation[account].startPrice = _calculateStartPrice(debt);
        auctionInformation[account].startTime = uint32(block.timestamp);
        auctionInformation[account].assetShares = _getAssetDistribution(riskValues);

        // Emit event
        emit AuctionStarted(account, creditor, assetAddresses[0], uint128(debt));
    }

    /**
     * @notice Calculate the starting price for a liquidation based on the specified debt amount.
     * @param debt The amount of debt for which to calculate the starting price.
     * @return startPrice The calculated starting price, expressed as a fraction of the debt.
     * @dev This function is an internal view function, and it calculates the starting price for a liquidation
     *      based on a given debt amount. The start price is determined by multiplying the debt by the
     *      `startPriceMultiplier` and dividing the result by 100.
     */
    function _calculateStartPrice(uint256 debt) internal view returns (uint256 startPrice) {
        startPrice = debt * startPriceMultiplier / 100;
    }

    /**
     * @notice Calculate asset distribution percentages based on provided risk values.
     * @param riskValues_ An array of risk values for assets.
     * @return assetDistributions An array of asset distribution percentages (in tenths of a percent, e.g., 10,000 represents 100%).
     */
    function _getAssetDistribution(RiskModule.AssetValueAndRiskVariables[] memory riskValues_)
        internal
        pure
        returns (uint32[] memory assetDistributions)
    {
        uint256 length = riskValues_.length;
        uint256 totalValue;
        for (uint256 i; i < length;) {
            unchecked {
                totalValue += riskValues_[i].valueInBaseCurrency;
            }
            unchecked {
                ++i;
            }
        }
        assetDistributions = new uint32[](length);
        for (uint256 i; i < length;) {
            // The asset distribution is calculated as a percentage of the total value of the assets.
            assetDistributions[i] = uint32(riskValues_[i].valueInBaseCurrency * 1_000_000 / totalValue);
            unchecked {
                ++i;
            }
        }
    }
}
