pragma solidity 0.8.22;

import { stdError } from "../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";
import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";
import { TrancheErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "Tranche Wrapper".
 */
contract Redeem_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_redeem_ZeroAssets(address receiver, address owner) public {
        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(TrancheErrors.ZeroAssets.selector);
        trancheWrapper.redeem(0, receiver, owner);
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
        trancheWrapper.mint(shares, owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.redeem(shares, receiver, owner);
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.prank(owner);
        trancheWrapper.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.redeem(sharesAllowed, receiver, owner);
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.redeem(sharesRedeemed, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_redeem_Locked(
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(owner);
        vm.expectRevert(TrancheErrors.Locked.selector);
        trancheWrapper.redeem(sharesRedeemed, receiver, owner);
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.prank(owner);
        trancheWrapper.redeem(sharesRedeemed, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.totalAssets(), sharesMinted - sharesRedeemed);
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.prank(owner);
        trancheWrapper.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        trancheWrapper.redeem(sharesRedeemed, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.totalAssets(), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.allowance(owner, beneficiary), sharesAllowed - sharesRedeemed);
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
        trancheWrapper.mint(sharesMinted, owner);

        vm.prank(owner);
        trancheWrapper.approve(beneficiary, type(uint256).max);

        vm.startPrank(beneficiary);
        trancheWrapper.redeem(sharesRedeemed, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.maxRedeem(owner), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.totalAssets(), sharesMinted - sharesRedeemed);
        assertEq(trancheWrapper.allowance(owner, beneficiary), type(uint256).max);
        assertEq(asset.balanceOf(address(pool)), sharesMinted - sharesRedeemed);
        assertEq(asset.balanceOf(receiver), sharesRedeemed);
    }
}
