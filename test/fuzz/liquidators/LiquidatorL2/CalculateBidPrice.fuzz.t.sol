/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LogExpMath } from "../../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the function "_calculateBidPrice" of contract "LiquidatorL2".
 */
// forge-lint: disable-next-item(divide-before-multiply,unsafe-typecast)
contract CalculateBidPrice_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_calculateBidPrice_AfterCutoff(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint32 timePassed,
        uint112 amountLoaned,
        uint256 askedShare
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The account auction is initiated.
        amountLoaned = uint112(bound(amountLoaned, 1 + 1, (type(uint112).max / 300) * 100));
        initiateLiquidation(amountLoaned);

        // And: A timestamp far beyond the cutoffTime, where the price curve underflows the LogExpMath precision.
        timePassed = uint32(bound(timePassed, 30 days, type(uint32).max));
        vm.warp(block.timestamp + timePassed);

        // When: calculateBidPrice is called.
        // Then: It reverts in LogExpMath (matches the PowerFunctionReverts pattern, no clean selector).
        vm.expectRevert();
        liquidator.calculateBidPrice(address(account), askedShare);
    }

    function testFuzz_Success_calculateBidPrice_WithinCutoff(
        uint32 halfLifeTime,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint32 timePassed,
        uint96 minimumMargin,
        uint112 amountLoaned,
        uint256 askedShare
    ) public {
        // Given: Valid auction curve parameters.
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60), (8 * 60 * 60))); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60), (8 * 60 * 60))); // > 1 hour && < 8 hours
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 10_000, 30_000));
        minPriceMultiplier = uint8(bound(minPriceMultiplier, 0, 9000));
        askedShare = bound(askedShare, 0, 1e6);

        vm.prank(users.owner);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime, startPriceMultiplier, minPriceMultiplier);

        // And: The account auction is initiated, with a minimumMargin that is priced into the auction.
        amountLoaned = uint112(bound(amountLoaned, 2, (uint256(type(uint112).max) / 300) * 100 - minimumMargin));
        initiateLiquidation(minimumMargin, amountLoaned);

        (uint128 startDebt,, uint32 startTime,) = liquidator.getAuctionInformationPartOne(address(account));

        // And: A timestamp within the cutoffTime.
        timePassed = uint32(bound(timePassed, 0, cutoffTime));
        vm.warp(uint256(startTime) + timePassed);

        // When: calculateBidPrice is called.
        uint256 price = liquidator.calculateBidPrice(address(account), askedShare);

        // Then: The price equals the price-curve formula, with the minimumMargin included in the debt term.
        uint256 expectedPrice =
            ((uint256(startDebt) + minimumMargin)
                    * askedShare
                    * (LogExpMath.pow(liquidator.getBase(), uint256(timePassed) * 1e18)
                        * (liquidator.getStartPriceMultiplier() - liquidator.getMinPriceMultiplier())
                        + 1e18
                        * uint256(liquidator.getMinPriceMultiplier()))) / 1e26;
        assertEq(price, expectedPrice);
    }
}
