/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the "setAuctionCurveParameters" of contract "Liquidator".
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
    function testRevert_setAuctionCurveParameters_NonOwner(
        address unprivilegedAddress_,
        uint16 halfLifeTime,
        uint16 cutoffTime
    ) public {
        vm.assume(unprivilegedAddress_ != users.creatorAddress);

        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_BaseTooHigh(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 8 * 60 * 60);

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("LQ_SACP: halfLifeTime too high");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_BaseTooLow(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime < 2 * 60);

        // Given When Then: a owner attempts to set the discount rate, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("LQ_SACP: halfLifeTime too low");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_AuctionCutoffTimeTooHigh(uint16 halfLifeTime, uint16 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);

        vm.assume(cutoffTime > 18 * 60 * 60);

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("LQ_SACP: cutoff too high");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_AuctionCutoffTimeTooLow(uint16 halfLifeTime, uint16 cutoffTime)
        public
    {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);

        vm.assume(cutoffTime < 1 * 60 * 60);

        // Given When Then: a owner attempts to set the max auction time, but it is not in the limits
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("LQ_SACP: cutoff too low");
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testRevert_setAuctionCurveParameters_PowerFunctionReverts(uint8 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 15 * 60);
        vm.assume(cutoffTime > 10 * 60 * 60);
        vm.assume(cutoffTime < 18 * 60 * 60);

        vm.startPrank(users.creatorAddress);
        vm.expectRevert();
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();
    }

    function testSuccess_setAuctionCurveParameters_Base(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 2 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);
        vm.assume(cutoffTime > 1 * 60 * 60);
        vm.assume(cutoffTime < 2 * 60 * 60);

        uint256 expectedBase = 1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime));

        // Given: the owner is the users.creatorAddress
        vm.startPrank(users.creatorAddress);
        // When: the owner sets the discount rate
        vm.expectEmit(true, true, true, true);
        emit AuctionCurveParametersSet(uint64(expectedBase), cutoffTime);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        vm.stopPrank();

        // Then: the discount rate is correctly set
        assertEq(liquidator.base(), expectedBase);
    }

    function testSuccess_setAuctionCurveParameters_cutoffTime(uint16 halfLifeTime, uint16 cutoffTime) public {
        // Preprocess: limit the fuzzing to acceptable levels
        vm.assume(halfLifeTime > 1 * 60 * 60);
        vm.assume(halfLifeTime < 8 * 60 * 60);
        vm.assume(cutoffTime > 1 * 60 * 60);
        vm.assume(cutoffTime < 8 * 60 * 60);

        // Given: the owner is the users.creatorAddress
        vm.prank(users.creatorAddress);
        // When: the owner sets the max auction time
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);

        // Then: the max auction time is set
        assertEq(liquidator.cutoffTime(), cutoffTime);
    }
}
