/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the "buyAccount" of contract "Liquidator".
 */
contract BuyAccount_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testRevert_buyAccount_notForSale(address bidder) public {
        vm.startPrank(bidder);
        vm.expectRevert("LQ_BV: Not for sale");
        liquidator.buyAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testRevert_buyAccount_InsufficientFunds(address bidder, uint128 openDebt, uint136 bidderFunds) public {
        vm.assume(openDebt > 0);
        vm.assume(bidder != address(pool));

        vm.prank(address(pool));
        liquidator.startAuction(address(proxyAccount), openDebt, type(uint80).max);

        (uint256 priceOfAccount,) = liquidator.getPriceOfAccount(address(proxyAccount));
        vm.assume(priceOfAccount > bidderFunds);

        deal(address(mockERC20.stable1), bidder, bidderFunds, true);

        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(liquidator), type(uint256).max);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        liquidator.buyAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testSuccess_buyAccount(
        uint256 openDebt,
        uint256 realisedLiquidity,
        uint256 bidderFunds,
        uint16 halfLifeTime,
        uint24 timePassed,
        uint16 cutoffTime,
        uint8 startPriceMultiplier,
        uint80 maxInitiatorFee
    ) public {
        // Cannot fuzz the bidder address, since any existing contract without onERC721Received will revert.
        address bidder = address(69);

        // Preprocess: Set up the fuzzed variables
        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
        vm.assume(startPriceMultiplier > 100);
        vm.assume(startPriceMultiplier < 301);
        openDebt = bound(openDebt, 1, type(uint64).max);
        realisedLiquidity = bound(realisedLiquidity, openDebt, type(uint64).max);

        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        vm.stopPrank();

        vm.prank(address(pool));
        liquidator.startAuction(address(proxyAccount), openDebt, maxInitiatorFee);

        vm.warp(block.timestamp + timePassed);

        (uint256 priceOfAccount,) = liquidator.getPriceOfAccount(address(proxyAccount));
        bidderFunds = bound(bidderFunds, priceOfAccount, type(uint256).max);

        deal(address(mockERC20.stable1), bidder, bidderFunds, true);

        // Set state LendingPool.
        pool.setLastSyncedTimestamp(uint32(block.timestamp));
        pool.setTotalRealisedLiquidity(uint128(realisedLiquidity));

        uint256 availableLiquidityBefore = mockERC20.stable1.balanceOf(address(pool));

        // Avoid stack to deep
        {
            // Bring variable up to the stack before becoming unreachable (otherwise stack too deep later also)
            uint128 openDebt_stack = uint128(openDebt);
            uint80 maxInitiatorFee_stack = maxInitiatorFee;

            (,, uint8 initiatorRewardWeight, uint8 penaltyWeight,,,,) =
                liquidator.getAuctionInformationPartTwo(address(proxyAccount));
            (uint256 badDebt, uint256 liquidationInitiatorReward, uint256 liquidationPenalty, uint256 remainder) =
            liquidator.calcLiquidationSettlementValues(
                openDebt_stack, priceOfAccount, maxInitiatorFee_stack, initiatorRewardWeight, penaltyWeight
            );

            vm.startPrank(bidder);
            mockERC20.stable1.approve(address(liquidator), type(uint256).max);
            vm.expectEmit(true, true, true, true);
            emit AuctionFinished(
                address(proxyAccount),
                address(pool),
                address(mockERC20.stable1),
                uint128(priceOfAccount),
                uint128(badDebt),
                uint128(liquidationInitiatorReward),
                uint128(liquidationPenalty),
                uint128(remainder)
            );
            liquidator.buyAccount(address(proxyAccount));
            vm.stopPrank();
        }

        uint256 availableLiquidityAfter = mockERC20.stable1.balanceOf(address(pool));

        if (priceOfAccount >= openDebt) {
            assertEq(pool.totalRealisedLiquidity() - realisedLiquidity, priceOfAccount - openDebt);
        } else {
            assertEq(realisedLiquidity - pool.totalRealisedLiquidity(), openDebt - priceOfAccount);
        }
        assertEq(availableLiquidityAfter - availableLiquidityBefore, priceOfAccount);
        assertEq(mockERC20.stable1.balanceOf(bidder), bidderFunds - priceOfAccount);
        uint256 index = factory.accountIndex(address(proxyAccount));
        assertEq(factory.ownerOf(index), bidder);
        assertEq(proxyAccount.owner(), bidder);
    }
}
