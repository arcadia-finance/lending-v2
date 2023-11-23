/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/// @notice Abstract contract containing all the events emitted by the protocol.
abstract contract Events {
    /* //////////////////////////////////////////////////////////////
                        LENDING POOL GUARDIAN
    ////////////////////////////////////////////////////////////// */

    event PauseFlagsUpdated(
        bool repayPauseFlagsUpdated,
        bool withdrawPauseFlagsUpdated,
        bool borrowPauseFlagsUpdated,
        bool PauseFlagsUpdated,
        bool liquidationPauseFlagsUpdated
    );

    /* //////////////////////////////////////////////////////////////
                            LENDING POOL
    ////////////////////////////////////////////////////////////// */

    event WeightsSet(uint16 initiationWeight, uint16 penaltyWeight, uint16 terminationWeight);
    event TrancheAdded(address indexed tranche, uint8 indexed index);
    event InterestWeightSet(uint256 indexed trancheIndex, uint16 weight);
    event LiquidationWeightSet(uint256 indexed trancheIndex, uint16 weight);
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
    event MaxLiquidationFeesSet(uint80 maxInitiationFee, uint80 maxTerminationFee);
    event FixedLiquidationCostSet(uint96 fixedLiquidationCost);
    event ValidAccountVersionsUpdated(uint256 indexed accountVersion, bool valid);
    event LendingPoolWithdrawal(address indexed receiver, uint256 assets);
    event AuctionStarted(address indexed account, address indexed creditor, uint128 openDebt);
    event InterestRate(uint80 interestRate);
    event InterestRateParametersUpdated(uint80 interestRate);

    /* //////////////////////////////////////////////////////////////
                            LIQUIDATOR
    ////////////////////////////////////////////////////////////// */

    event AuctionCurveParametersSet(
        uint64 base, uint32 cutoffTime, uint16 startPriceMultiplier, uint16 minPriceMultiplier
    );
    event AuctionFinished(address indexed account, address indexed creditor, uint128 startDebt);

    /* //////////////////////////////////////////////////////////////
                            TRANCHE
    ////////////////////////////////////////////////////////////// */

    event LockSet(bool status);
    event AuctionInProgressSet(bool status);
}
