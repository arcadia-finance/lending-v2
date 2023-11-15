/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "endAuctionAfterCutoff" of contract "Liquidator".
 */

contract EndAuctionAfterCutoff_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
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
    function testFuzz_Revert_endAuctionAfterCutoff_NotForSale(address account_) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.endAuctionAfterCutoff(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_endAuctionAfterCutoff_AuctionNotExpired(
        uint32 halfLifeTime,
        uint24 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60) + 1, (8 * 60 * 60) - 1)); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60) + 1, (8 * 60 * 60) - 1)); // > 1 hour && < 8 hours
        vm.assume(timePassed <= cutoffTime);
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 101, 300));
        vm.assume(minPriceMultiplier < 91);
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // Warp to a timestamp when auction is not yet expired
        vm.warp(block.timestamp + timePassed);

        // call to endAuctionAfterCutoff() should revert as the auction is not yet expired.
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(Liquidator_AuctionNotExpired.selector);
        liquidator.endAuctionAfterCutoff(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_endAuctionAfterCutoff(
        uint32 halfLifeTime,
        uint24 timePassed,
        uint32 cutoffTime,
        uint16 startPriceMultiplier,
        uint8 minPriceMultiplier,
        uint256 amountLoaned
    ) public {
        // Preprocess: Set up the fuzzed variables
        halfLifeTime = uint32(bound(halfLifeTime, (10 * 60) + 1, (8 * 60 * 60) - 1)); // > 10 min && < 8 hours
        cutoffTime = uint32(bound(cutoffTime, (1 * 60 * 60) + 1, (8 * 60 * 60) - 1)); // > 1 hour && < 8 hours
        vm.assume(timePassed > cutoffTime);
        startPriceMultiplier = uint16(bound(startPriceMultiplier, 101, 300));
        vm.assume(minPriceMultiplier < 91);
        amountLoaned = bound(amountLoaned, 1, (type(uint128).max / 150) * 100); // No overflow when debt is increased

        vm.startPrank(users.creatorAddress);
        liquidator.setAuctionCurveParameters(halfLifeTime, cutoffTime);
        liquidator.setStartPriceMultiplier(startPriceMultiplier);
        liquidator.setMinimumPriceMultiplier(minPriceMultiplier);

        // Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // Initiate liquidation
        liquidator.liquidateAccount(address(proxyAccount));

        // Set debt back to initial debt to have right accounting in settleLiquidation.
        debt.setRealisedDebt(uint256(amountLoaned));

        // Warp to a timestamp when auction is expired
        vm.warp(block.timestamp + timePassed);

        // call to endAuctionAfterCutoff() should succeed as the auction is now expired.
        vm.startPrank(users.creatorAddress);
        vm.expectEmit();
        // We use amountLoaned + 1 below as that was the value on the time of liquidateAccount() above.
        emit AuctionFinished(address(proxyAccount), address(pool), uint128(amountLoaned) + 1, 0, 0);
        liquidator.endAuctionAfterCutoff(address(proxyAccount));
        vm.stopPrank();

        // The remaining tokens should be sent to protocol owner
        assertEq(mockERC20.stable1.balanceOf(liquidator.owner()), amountLoaned);
        assert(liquidator.getAuctionIsActive(address(proxyAccount)) == false);
    }
}
