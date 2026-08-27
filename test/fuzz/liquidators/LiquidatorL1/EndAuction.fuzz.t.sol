/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";

import { LendingPool } from "../../../../src/LendingPool.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";
import { stdStorage, StdStorage } from "../../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "LiquidatorL1".
 */
contract EndAuction_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
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
        liquidator_.endAuction(address(account));
    }

    function testFuzz_Revert_endAuction_EndAuctionFailed(
        uint32 halfLifeTime,
        uint32 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        timePassed = uint32(bound(timePassed, 0, cutoffTime - 1));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: The auction is not yet expired and no termination condition is met.
        vm.warp(block.timestamp + timePassed);

        // When: endAuction is called.
        // Then: It reverts.
        vm.prank(randomAddress);
        vm.expectRevert(LiquidatorErrors.EndAuctionFailed.selector);
        liquidator_.endAuction(address(account));
    }

    function testFuzz_Success_endAuction(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint112 usedMargin,
        uint96 minimumMargin,
        address randomAddress
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator_.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // Given: The account auction is initiated.
        usedMargin = uint112(bound(usedMargin, uint256(minimumMargin) + 1, type(uint112).max - 1));
        uint112 amountLoaned = usedMargin - minimumMargin;
        initiateLiquidation(minimumMargin, amountLoaned);

        // And: Account becomes healthy so the auction can be ended.
        debt.setRealisedDebt(uint256(amountLoaned));
        stdstore.target(address(pool))
            .sig(pool.liquidityOf.selector)
            .with_key(address(srTranche))
            .checked_write(amountLoaned);
        pool.setTotalRealisedLiquidity(uint128(amountLoaned));

        (uint256 initiationReward, uint256 terminationReward, uint256 liquidationPenalty) =
            pool.getCalculateRewards(amountLoaned + 1, 0);

        // When: endAuction is called.
        vm.startPrank(randomAddress);
        vm.expectEmit(true, true, true, true);
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
        liquidator_.endAuction(address(account));
        vm.stopPrank();

        // Then: The auction is ended.
        assertEq(liquidator_.getAuctionIsActive(address(account)), false);
        assertEq(account.inAuction(), false);
    }
}
