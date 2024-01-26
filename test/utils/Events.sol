/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

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

    event AuctionStarted(address indexed account, address indexed creditor, uint128 openDebt);
    event Borrow(
        address indexed account, address indexed by, address to, uint256 amount, uint256 fee, bytes3 indexed referrer
    );
    event CreditApproval(address indexed account, address indexed owner, address indexed beneficiary, uint256 amount);
    event InterestSynced(uint256 interest);
    event PoolStateUpdated(uint256 totalDebt, uint256 totalLiquidity, uint80 interestRate);
    event LiquidationWeightTrancheUpdated(uint16 liquidationWeight);
    event Repay(address indexed account, address indexed from, uint256 amount);
    event InterestWeightTrancheUpdated(address indexed tranche, uint8 indexed trancheIndex, uint16 interestWeight);
    event TreasuryWeightsUpdated(uint16 interestWeight, uint16 liquidationWeight);
    event TranchePopped(address tranche);
    event ValidAccountVersionsUpdated(uint256 indexed accountVersion, bool valid);

    /* //////////////////////////////////////////////////////////////
                            LIQUIDATOR
    ////////////////////////////////////////////////////////////// */

    event AuctionCurveParametersSet(
        uint64 base, uint32 cutoffTime, uint16 startPriceMultiplier, uint16 minPriceMultiplier
    );
    event AuctionFinished(
        address indexed account,
        address indexed creditor,
        uint256 openDebt,
        uint256 initiationReward,
        uint256 terminationReward,
        uint256 penalty,
        uint256 badDebt,
        uint256 surplus
    );

    /* //////////////////////////////////////////////////////////////
                            TRANCHE
    ////////////////////////////////////////////////////////////// */

    event LockSet(bool status);
    event AuctionInProgressSet(bool status);
}
