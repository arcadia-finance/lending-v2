/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "redeem" of contract "Tranche".
 */
contract Redeem_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_redeem_Locked(uint128 shares, address receiver, address owner) public {
        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(Locked.selector);
        tranche.redeem(shares, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_redeem_ZeroAssets(address receiver, address owner) public {
        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(ZeroAssets.selector);
        tranche.redeem(0, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_redeem_Unauthorised(
        uint128 shares,
        address receiver,
        address owner,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != owner);
        vm.assume(shares > 0);

        vm.prank(users.liquidityProvider);
        tranche.mint(shares, owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        tranche.redeem(shares, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_redeem_InsufficientApproval(
        uint128 sharesMinted,
        uint128 sharesAllowed,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(beneficiary != owner);
        vm.assume(sharesMinted > 0);
        vm.assume(sharesMinted < sharesAllowed);

        vm.prank(users.liquidityProvider);
        tranche.mint(sharesMinted, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        tranche.redeem(sharesAllowed, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_redeem_InsufficientShares(
        uint128 sharesMinted,
        uint128 sharesRedeemed,
        address owner,
        address receiver
    ) public {
        vm.assume(sharesMinted > 0);
        vm.assume(sharesMinted < sharesRedeemed);

        vm.prank(users.liquidityProvider);
        tranche.mint(sharesMinted, owner);

        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        tranche.redeem(sharesRedeemed, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Success_redeem_ByOwner(
        uint128 sharesMinted,
        uint128 sharesRedeemed,
        address owner,
        address receiver
    ) public {
        vm.assume(sharesMinted > 0);
        vm.assume(sharesRedeemed > 0);
        vm.assume(sharesMinted >= sharesRedeemed);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));

        vm.prank(users.liquidityProvider);
        tranche.mint(sharesMinted, owner);

        vm.prank(owner);
        tranche.redeem(sharesRedeemed, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.totalAssets(), sharesMinted - sharesRedeemed);
        assertEq(asset.balanceOf(address(pool)), sharesMinted - sharesRedeemed);
        assertEq(asset.balanceOf(receiver), sharesRedeemed);
    }

    function testFuzz_Success_redeem_ByLimitedAuthorisedAddress(
        uint128 sharesMinted,
        uint128 sharesAllowed,
        uint128 sharesRedeemed,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(sharesMinted > 0);
        vm.assume(sharesRedeemed > 0);
        vm.assume(sharesMinted >= sharesRedeemed);
        vm.assume(sharesAllowed >= sharesRedeemed);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));
        vm.assume(beneficiary != owner);

        vm.prank(users.liquidityProvider);
        tranche.mint(sharesMinted, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        tranche.redeem(sharesRedeemed, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.totalAssets(), sharesMinted - sharesRedeemed);
        assertEq(tranche.allowance(owner, beneficiary), sharesAllowed - sharesRedeemed);
        assertEq(asset.balanceOf(address(pool)), sharesMinted - sharesRedeemed);
        assertEq(asset.balanceOf(receiver), sharesRedeemed);
    }

    function testFuzz_Success_redeem_ByMaxAuthorisedAddress(
        uint128 sharesMinted,
        uint128 sharesRedeemed,
        address receiver,
        address owner,
        address beneficiary
    ) public {
        vm.assume(sharesMinted > 0);
        vm.assume(sharesRedeemed > 0);
        vm.assume(sharesMinted >= sharesRedeemed);
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));
        vm.assume(beneficiary != owner);

        vm.prank(users.liquidityProvider);
        tranche.mint(sharesMinted, owner);

        vm.prank(owner);
        tranche.approve(beneficiary, type(uint256).max);

        vm.startPrank(beneficiary);
        tranche.redeem(sharesRedeemed, receiver, owner);

        assertEq(tranche.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(tranche.totalAssets(), sharesMinted - sharesRedeemed);
        assertEq(tranche.allowance(owner, beneficiary), type(uint256).max);
        assertEq(asset.balanceOf(address(pool)), sharesMinted - sharesRedeemed);
        assertEq(asset.balanceOf(receiver), sharesRedeemed);
    }
}
