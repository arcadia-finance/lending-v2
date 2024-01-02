/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "Tranche".
 */
contract Withdraw_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_withdraw_Locked(uint128 assets, address receiver, address owner) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(Locked.selector);
        tranche.withdraw(assets, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_AuctionInProgress(uint128 assets, address receiver, address owner) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(AuctionOngoing.selector);
        tranche.withdraw(assets, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_Unauthorised(
        uint128 assets,
        address receiver,
        address owner,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != owner);
        vm.assume(assets > 0);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assets, owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        tranche.withdraw(assets, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_InsufficientApproval(
        uint128 assetsDeposited,
        uint128 sharesAllowed,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(beneficiary != owner);
        vm.assume(assetsDeposited > 0);
        vm.assume(assetsDeposited < sharesAllowed);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assetsDeposited, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        tranche.withdraw(sharesAllowed, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_InsufficientAssets(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address owner,
        address receiver
    ) public {
        vm.assume(assetsDeposited > 0);
        vm.assume(assetsDeposited < assetsWithdrawn);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assetsDeposited, owner);

        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        tranche.withdraw(assetsWithdrawn, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Success_withdraw_ByOwner(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address owner,
        address receiver
    ) public {
        vm.assume(assetsDeposited > 0);
        vm.assume(assetsDeposited >= assetsWithdrawn);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));

        vm.prank(users.liquidityProvider);
        tranche.deposit(assetsDeposited, owner);

        vm.prank(owner);
        tranche.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.totalAssets(), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }

    function testFuzz_Success_withdraw_ByLimitedAuthorisedAddress(
        uint128 assetsDeposited,
        uint128 sharesAllowed,
        uint128 assetsWithdrawn,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(assetsDeposited > 0);
        vm.assume(assetsDeposited >= assetsWithdrawn);
        vm.assume(sharesAllowed >= assetsWithdrawn);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));
        vm.assume(beneficiary != owner);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assetsDeposited, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        tranche.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.totalAssets(), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.allowance(owner, beneficiary), sharesAllowed - assetsWithdrawn);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }

    function testFuzz_Success_withdraw_ByMaxAuthorisedAddress(
        uint128 assetsDeposited,
        uint128 assetsWithdrawn,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(assetsDeposited > 0);
        vm.assume(assetsDeposited >= assetsWithdrawn);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));
        vm.assume(beneficiary != owner);

        vm.prank(users.liquidityProvider);
        tranche.deposit(assetsDeposited, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, type(uint256).max);

        vm.startPrank(beneficiary);
        tranche.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.totalAssets(), assetsDeposited - assetsWithdrawn);
        assertEq(tranche.allowance(owner, beneficiary), type(uint256).max);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }
}
