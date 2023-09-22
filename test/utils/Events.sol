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
                            LIQUIDATOR
    ////////////////////////////////////////////////////////////// */

    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight);
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

    /* //////////////////////////////////////////////////////////////
                            TRANCHE
    ////////////////////////////////////////////////////////////// */

    event LockSet(bool status);
    event AuctionFlagSet(bool status);
}
