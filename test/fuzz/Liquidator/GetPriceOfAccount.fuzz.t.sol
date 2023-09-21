/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Fuzz tests for the "getPriceOfAccount" of contract "Liquidator".
 */
contract GetPriceOfAccount_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_getPriceOfAccount_NotForSale(address accountAddress) public {
        (uint256 price, bool inAuction) = liquidator.getPriceOfAccount(accountAddress);

        assertEq(price, 0);
        assertEq(inAuction, false);
    }

    function testSuccess_getPriceOfAccount_BeforeCutOffTime(
        uint32 startTime,
        uint16 halfLifeTime,
        uint32 currentTime,
        uint16 cutoffTime,
        uint128 openDebt,
        uint8 startPriceMultiplier,
        uint8 minPriceMultiplier
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(currentTime - startTime < cutoffTime);
        vm.assume(openDebt > 0);
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);

        // Given: An Account is in auction
        uint64 base = uint64(1e18 * 1e18 / LogExpMath.pow(2 * 1e18, uint256(1e18 / halfLifeTime)));

        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);
        vm.warp(currentTime);

        // When: Get the price of the Account
        (uint256 price, bool inAuction) = liquidator.getPriceOfAccount(address(proxyAccount));

        // And: The price is calculated outside correctly
        uint256 auctionTime = (uint256(currentTime) - uint256(startTime)) * 1e18;
        uint256 multiplier = (startPriceMultiplier - minPriceMultiplier) * LogExpMath.pow(base, auctionTime)
            + 1e18 * uint256(minPriceMultiplier);
        uint256 expectedPrice = uint256(openDebt) * multiplier / 1e20;

        // Then: The price is calculated correctly
        assertEq(price, expectedPrice);
        assertEq(inAuction, true);
    }

    function testSuccess_getPriceOfAccount_AfterCutOffTime(
        uint32 startTime,
        uint16 halfLifeTime,
        uint32 currentTime,
        uint16 cutoffTime,
        uint128 openDebt,
        uint8 startPriceMultiplier,
        uint8 minPriceMultiplier
    ) public {
        // Preprocess: Set up the fuzzed variables
        vm.assume(currentTime > startTime);
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(currentTime - startTime >= cutoffTime);
        vm.assume(openDebt > 0);
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        vm.assume(minPriceMultiplier < 91);

        // Given: An Account is in auction
        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);
        vm.stopPrank();

        vm.warp(startTime);

        vm.prank(address(pool));
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);
        vm.warp(currentTime);

        // When: Get the price of the Account
        (uint256 price, bool inAuction) = liquidator.getPriceOfAccount(address(proxyAccount));

        // And: The price is calculated outside correctly
        uint256 expectedPrice = uint256(openDebt) * minPriceMultiplier / 1e2;

        // Then: The price is calculated correctly
        assertEq(price, expectedPrice);
        assertEq(inAuction, true);
    }
}
