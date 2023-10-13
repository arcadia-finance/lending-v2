///**
// * Created by Pragma Labs
// * SPDX-License-Identifier: BUSL-1.1
// */
//pragma solidity 0.8.19;
//
//import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
//
///**
// * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
// */
//contract EndAuction_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
//    /* ///////////////////////////////////////////////////////////////
//                              SETUP
//    /////////////////////////////////////////////////////////////// */
//
//    function setUp() public override {
//        Liquidator_Fuzz_Test.setUp();
//    }
//
//    /*//////////////////////////////////////////////////////////////
//                              TESTS
//    //////////////////////////////////////////////////////////////*/
//    function testFuzz_Revert_endAuction_NonOwner(address unprivilegedAddress_, address account_, address to) public {
//        vm.assume(unprivilegedAddress_ != users.creatorAddress);
//
//        vm.startPrank(unprivilegedAddress_);
//        vm.expectRevert("UNAUTHORIZED");
//        liquidator.endAuction(account_, to);
//        vm.stopPrank();
//    }
//
//    function testFuzz_Revert_endAuction_NotForSale(address account_, address to) public {
//        vm.startPrank(users.creatorAddress);
//        vm.expectRevert("LQ_EA: Not for sale");
//        liquidator.endAuction(account_, to);
//        vm.stopPrank();
//    }
//
//    function testFuzz_Revert_endAuction_AuctionNotExpired(
//        uint256 openDebt,
//        uint256 realisedLiquidity,
//        uint16 halfLifeTime,
//        uint24 timePassed,
//        uint16 cutoffTime,
//        uint8 startPriceMultiplier,
//        uint8 minPriceMultiplier,
//        uint80 maxInitiatorFee,
//        address to
//    ) public {
//        // Preprocess: Set up the fuzzed variables
//        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
//        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
//        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
//        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
//        vm.assume(timePassed <= cutoffTime);
//        vm.assume(startPriceMultiplier > 100);
//        vm.assume(startPriceMultiplier < 301);
//        vm.assume(minPriceMultiplier < 91);
//        openDebt = bound(openDebt, 1, type(uint64).max);
//        realisedLiquidity = bound(realisedLiquidity, openDebt, type(uint64).max);
//
//        vm.startPrank(users.creatorAddress);
//        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
//        liquidator.setStartPriceMultiplier(startPriceMultiplier);
//        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);
//        vm.stopPrank();
//
//        vm.prank(address(pool));
//        liquidator.startAuction(address(proxyAccount), openDebt, maxInitiatorFee);
//
//        vm.warp(block.timestamp + timePassed);
//
//        vm.startPrank(users.creatorAddress);
//        vm.expectRevert("LQ_EA: Auction not expired");
//        liquidator.endAuction(address(proxyAccount), to);
//        vm.stopPrank();
//    }
//
//    function testFuzz_Success_endAuction(
//        uint256 openDebt,
//        uint256 realisedLiquidity,
//        uint16 halfLifeTime,
//        uint24 timePassed,
//        uint16 cutoffTime,
//        uint8 startPriceMultiplier,
//        uint8 minPriceMultiplier,
//        uint80 maxInitiatorFee
//    ) public {
//        // Preprocess: Set up the fuzzed variables
//        vm.assume(halfLifeTime > 10 * 60); // 10 minutes
//        vm.assume(halfLifeTime < 8 * 60 * 60); // 8 hours
//        vm.assume(cutoffTime < 8 * 60 * 60); // 8 hours
//        vm.assume(cutoffTime > 1 * 60 * 60); // 1 hours
//        vm.assume(timePassed > cutoffTime);
//        vm.assume(startPriceMultiplier > 100);
//        vm.assume(startPriceMultiplier < 301);
//        vm.assume(minPriceMultiplier < 91);
//        openDebt = bound(openDebt, 1, type(uint64).max);
//        realisedLiquidity = bound(realisedLiquidity, openDebt, type(uint64).max);
//        address to = address(69); //Cannot fuzz the bidder address, since any existing contract without onERC721Received will revert
//
//        vm.startPrank(users.creatorAddress);
//        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
//        liquidator.setStartPriceMultiplier(startPriceMultiplier);
//        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);
//        vm.stopPrank();
//
//        vm.prank(address(pool));
//        liquidator.startAuction(address(proxyAccount), openDebt, maxInitiatorFee);
//
//        vm.warp(block.timestamp + timePassed);
//
//        // Set state LendingPool.
//        pool.setLastSyncedTimestamp(uint32(block.timestamp));
//        pool.setTotalRealisedLiquidity(uint128(realisedLiquidity));
//
//        uint256 availableLiquidityBefore = mockERC20.stable1.balanceOf(address(pool));
//
//        // Avoid stack to deep
//        {
//            (,, uint8 initiatorRewardWeight, uint8 penaltyWeight,,,,) =
//                liquidator.getAuctionInformationPartTwo(address(proxyAccount));
//            (uint256 badDebt, uint256 liquidationInitiatorReward,,) = liquidator.calcLiquidationSettlementValues(
//                openDebt, 0, maxInitiatorFee, initiatorRewardWeight, penaltyWeight
//            );
//
//            vm.startPrank(users.creatorAddress);
//            vm.expectEmit(true, true, true, true);
//            emit AuctionFinished(
//                address(proxyAccount),
//                address(pool),
//                address(mockERC20.stable1),
//                0,
//                uint128(badDebt),
//                uint128(liquidationInitiatorReward),
//                0,
//                0
//            );
//            liquidator.endAuction(address(proxyAccount), to);
//            vm.stopPrank();
//        }
//
//        uint256 availableLiquidityAfter = mockERC20.stable1.balanceOf(address(pool));
//
//        assertEq(realisedLiquidity - pool.totalRealisedLiquidity(), openDebt);
//        assertEq(availableLiquidityAfter - availableLiquidityBefore, 0);
//        uint256 index = factory.accountIndex(address(proxyAccount));
//        assertEq(factory.ownerOf(index), to);
//        assertEq(proxyAccount.owner(), to);
//    }
//}
