/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/// @notice Abstract contract containing all the events emitted by the protocol.
abstract contract Events {
    /* //////////////////////////////////////////////////////////////
                     INTEREST RATE MODULE
    ////////////////////////////////////////////////////////////// */

    event InterestRate(uint80 interestRate);

    /* //////////////////////////////////////////////////////////////
                        LENDING POOL GUARDIAN
    ////////////////////////////////////////////////////////////// */

    event PauseUpdate(
        bool repayPauseUpdate,
        bool withdrawPauseUpdate,
        bool borrowPauseUpdate,
        bool PauseUpdate,
        bool liquidationPauseUpdate
    );

    /* //////////////////////////////////////////////////////////////
                            LENDING POOL
    ////////////////////////////////////////////////////////////// */

    event TrancheAdded(address indexed tranche, uint8 indexed index, uint16 interestWeight, uint16 liquidationWeight);
    event InterestWeightSet(uint256 indexed index, uint16 weight);
    event LiquidationWeightSet(uint256 indexed index, uint16 weight);
    event TranchePopped(address tranche);
    event TreasuryInterestWeightSet(uint16 weight);
    event TreasuryLiquidationWeightSet(uint16 weight);
    event OriginationFeeSet(uint8 originationFee);
    event BorrowCapSet(uint128 borrowCap);
    event SupplyCapSet(uint128 supplyCap);
    event CreditApproval(address indexed account, address indexed owner, address indexed beneficiary, uint256 amount);
    event Borrow(
        address indexed account, address indexed by, address to, uint256 amount, uint256 fee, bytes3 indexed referrer
    );
    event Repay(address indexed account, address indexed from, uint256 amount);
    event MaxLiquidationFeesSet(uint80 maxInitiatorFee, uint80 maxClosingFee);
    event FixedLiquidationCostSet(uint96 fixedLiquidationCost);
    event AccountVersionSet(uint256 indexed accountVersion, bool valid);
    event LendingPoolWithdrawal(address indexed receiver, uint256 assets);

    /* //////////////////////////////////////////////////////////////
                            LIQUIDATOR
    ////////////////////////////////////////////////////////////// */

    // note: to delete when removing old liquidator contract
    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight);
    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight, uint8 closingRewardWeight);
    event AuctionCurveParametersSet(uint64 base, uint16 cutoffTime);
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);
    event MinimumPriceMultiplierSet(uint8 minPriceMultiplier);
    event AuctionStarted(address indexed account, address indexed creditor, address baseCurrency, uint128 openDebt);
    event AuctionFinished(
        address indexed account,
        address indexed creditor,
        address baseCurrency,
        uint128 price,
        uint128 badDebt,
        uint128 initiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder
    );
    event AuctionFinished_NEW(
        address indexed account,
        address indexed creditor,
        address baseCurrency,
        uint128 totalBids,
        uint128 badDebt,
        uint128 initiatorReward,
        uint128 closingReward,
        uint128 liquidationPenalty,
        uint128 remainder
    );

    /* //////////////////////////////////////////////////////////////
                            TRANCHE
    ////////////////////////////////////////////////////////////// */

    event LockSet(bool status);
    event AuctionFlagSet(bool status);
}
