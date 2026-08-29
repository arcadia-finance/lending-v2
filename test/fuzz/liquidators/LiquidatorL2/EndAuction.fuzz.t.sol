/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LendingPool } from "../../../../src/LendingPool.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "LiquidatorL2".
 */
// forge-lint: disable-next-item(divide-before-multiply,unsafe-typecast)
contract EndAuction_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();

        // Set grace period to 0.
        vm.prank(users.riskManager);
        registry.setRiskParameters(address(pool), 0, 0 minutes, type(uint64).max);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_endAuction_NotForSale() public {
        // Given: The account is not being auctioned.
        // When: endAuction is called.
        // Then: It reverts.
        vm.prank(users.owner);
        vm.expectRevert(LiquidatorErrors.NotForSale.selector);
        liquidator.endAuction(address(account));
    }

    function testFuzz_Revert_endAuction_SequencerDown(address caller, uint112 amountLoaned, uint32 startedAt) public {
        // Given: The account auction is initiated.
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(0, amountLoaned);

        // And: The sequencer is down.
        sequencerUptimeOracle.setLatestRoundData(1, startedAt);

        // When: endAuction is called.
        // Then: It reverts.
        vm.prank(caller);
        vm.expectRevert(LiquidatorErrors.SequencerDown.selector);
        liquidator.endAuction(address(account));
    }

    function testFuzz_Revert_endAuction_EndAuctionFailed_SequencerUpDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The sequencer did not go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, 0, block.timestamp));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The auction is not yet expired.
        vm.warp(block.timestamp + timePassed);

        // When: endAuction is called.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(LiquidatorErrors.EndAuctionFailed.selector);
        liquidator.endAuction(address(account));
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuction_EndAuctionFailed_SequencerDownDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The sequencer went down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, block.timestamp, type(uint32).max - cutoffTime));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The auction is not yet expired, and the oracle is kept active.
        vm.warp(sequencerStartedAt + timePassed);
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // When: endAuction is called.
        // Then: It reverts.
        vm.startPrank(randomAddress);
        vm.expectRevert(LiquidatorErrors.EndAuctionFailed.selector);
        liquidator.endAuction(address(account));
        vm.stopPrank();
    }

    function testFuzz_Success_endAuction_AfterCutoff_SequencerUpDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The sequencer did not go down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, 0, block.timestamp));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // And: The auction expired (cutoffTime passed), and the oracle is kept active.
        vm.warp(block.timestamp + timePassed);
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // When: endAuction is called.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); // Ignore exact calculations.
        // Then: The unhappy flow settles.
        emit LendingPool.AuctionFinished(
            address(account),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        liquidator.endAuction(address(account));
        vm.stopPrank();

        // And: The Account is transferred to the Account recipient and the auction is ended.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
        assertEq(liquidator.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }

    function testFuzz_Success_endAuction_AfterCutoff_SequencerDownDuringAuction(
        uint32 halfLifeTime,
        uint32 sequencerStartedAt,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, cutoffTime + 1, type(uint32).max - block.timestamp));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // And: The sequencer went down during the auction.
        sequencerStartedAt = uint32(bound(sequencerStartedAt, block.timestamp, type(uint32).max - timePassed));
        sequencerUptimeOracle.setLatestRoundData(0, sequencerStartedAt);

        // And: The auction expired counting from the sequencer restart, and the oracle is kept active.
        vm.warp(sequencerStartedAt + timePassed);
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));

        // When: endAuction is called.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, false); // Ignore exact calculations.
        // Then: The unhappy flow settles.
        emit LendingPool.AuctionFinished(
            address(account),
            address(pool),
            uint128(amountLoaned + 1),
            initiationReward,
            terminationReward,
            liquidationPenalty,
            0,
            0
        );
        liquidator.endAuction(address(account));
        vm.stopPrank();

        // And: The Account is transferred to the Account recipient and the auction is ended.
        assertEq(account.owner(), liquidator.getAssetRecipient(address(pool)));
        assertEq(liquidator.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }
}
