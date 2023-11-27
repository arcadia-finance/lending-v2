/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the function "setAuctionCurveParameters" of contract "Liquidator".
 */
contract SetAuctionCurveParameters_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setAuctionCurveParameters_NonOwner(
        address unprivilegedAddress_,
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_BaseTooHigh(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, 28_800 + 1, type(uint32).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(HalfLifeTimeTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_HalfLifeTimeTooLow(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, 0, 120 - 1));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(HalfLifeTimeTooLow.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_AuctionCutoffTimeTooHigh(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, 120, 28_800));

        cutoffTime = uint32(bound(cutoffTime, 64_800 + 1, type(uint32).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(CutOffTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_AuctionCutoffTimeTooLow(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, 120, 28_800));

        cutoffTime = uint32(bound(cutoffTime, 0, 3600 - 1));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(CutOffTooLow.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_PowerFunctionReverts(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        halfLifeTime = uint32(bound(halfLifeTime, 120, 300));
        cutoffTime = uint32(bound(cutoffTime, 64_000, 64_800));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert();
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_StartPriceMultiplierTooHigh(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        // Set halfLifeTime above 1800 instead of 120 to avoid reverting power function.
        halfLifeTime = uint32(bound(halfLifeTime, 1800, 28_800));
        cutoffTime = uint32(bound(cutoffTime, 3600, 64_800));

        startPriceMultiplier = uint16(bound(startPriceMultiplier, 30_000 + 1, type(uint16).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(MultiplierTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_StartPriceMultiplierTooLow(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        // Set halfLifeTime above 1800 instead of 120 to avoid reverting power function.
        halfLifeTime = uint32(bound(halfLifeTime, 1800, 28_800));
        cutoffTime = uint32(bound(cutoffTime, 3600, 64_800));

        startPriceMultiplier = uint16(bound(startPriceMultiplier, 0, 10_000 - 1));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(MultiplierTooLow.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Revert_setAuctionCurveParameters_MinPriceMultiplierTooHigh(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        // Set halfLifeTime above 1800 instead of 120 to avoid reverting power function.
        halfLifeTime = uint32(bound(halfLifeTime, 1800, 28_800));
        cutoffTime = uint32(bound(cutoffTime, 3600, 64_800));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));

        minPriceMultiplier = uint16(bound(minPriceMultiplier, 9000 + 1, type(uint16).max));

        vm.startPrank(users.creatorAddress);
        vm.expectRevert(MultiplierTooHigh.selector);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();
    }

    function testFuzz_Success_setAuctionCurveParameters(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint16 minPriceMultiplier
    ) public {
        // Set halfLifeTime above 1800 instead of 120 to avoid reverting power function.
        halfLifeTime = uint32(bound(halfLifeTime, 1800, 28_800));
        cutoffTime = uint32(bound(cutoffTime, 3600, 64_800));
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint16(bound(minPriceMultiplier, 0, 9000));

        uint256 expectedBase = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime));

        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit AuctionCurveParametersSet(uint64(expectedBase), cutoffTime, startPriceMultiplier, minPriceMultiplier);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);
        vm.stopPrank();

        assertEq(liquidator.getBase(), expectedBase);
        assertEq(liquidator.getCutoffTime(), cutoffTime);
        assertEq(liquidator.getStartPriceMultiplier(), startPriceMultiplier);
        assertEq(liquidator.getMinPriceMultiplier(), minPriceMultiplier);
    }
}
