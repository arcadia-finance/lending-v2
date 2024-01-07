/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "Tranche".
 */
contract Deposit_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_deposit_Locked(uint128 assets, address receiver) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(Locked.selector);
        tranche.deposit(assets, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_ZeroShares(address receiver) public {
        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(ZeroShares.selector);
        tranche.deposit(0, receiver);
        vm.stopPrank();
    }

    function testFuzz_Revert_deposit_AuctionInProgress(uint128 assets, address receiver) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(AuctionOngoing.selector);
        tranche.deposit(assets, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_deposit(uint128 assets, address receiver) public {
        vm.assume(assets > 0);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assets, receiver);

        assertEq(tranche.maxWithdraw(receiver), assets);
        assertEq(tranche.maxRedeem(receiver), assets);
        assertEq(tranche.totalAssets(), assets);
        assertEq(asset.balanceOf(address(pool)), assets);
    }

    function testFuzz_Success_deposit_sync(uint128 assets, address receiver) public {
        vm.assume(assets > 3);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assets / 3, receiver);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assets / 3, receiver);

        vm.warp(block.timestamp + 500);

        vm.prank(users.liquidityProvider);
        vm.expectCall(address(pool), abi.encodeWithSignature("liquidityOfAndSync(address)", address(tranche)));
        tranche.deposit(assets / 3, receiver);
    }
}
