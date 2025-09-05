pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdError } from "../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";
import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "Tranche Wrapper".
 */
contract Withdraw_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_withdraw_Unauthorised(
        uint128 assets,
        address receiver,
        address owner,
        address unprivilegedAddress
    ) public {
        vm.assume(unprivilegedAddress != owner);
        vm.assume(assets > 0);

        vm.prank(users.liquidityProvider);
        trancheWrapper.deposit(assets, owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.withdraw(assets, receiver, owner);
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(owner);

        tranche.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.withdraw(sharesAllowed, receiver, owner);
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_Locked(
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(address(pool));
        tranche.lock();

        vm.startPrank(owner);
        vm.expectRevert(TrancheErrors.Locked.selector);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_AuctionInProgress(
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(owner);
        vm.expectRevert(TrancheErrors.AuctionOngoing.selector);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(owner);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.totalAssets(), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }

    function testFuzz_Success_withdraw_ByOwner(
        uint128 initialShares,
        uint128 wrapperShares,
        uint128 ownerShares,
        uint128 initialAssets,
        uint128 withdrawnAssets,
        address owner,
        address receiver
    ) public {
        initialShares = uint128(bound(initialShares, 1, type(uint128).max));
        wrapperShares = uint128(bound(initialShares, 1, initialShares));
        ownerShares = uint128(bound(ownerShares, 1, wrapperShares));
        initialAssets = uint128(bound(initialAssets, 1, type(uint128).max));
        vm.assume(receiver != users.liquidityProvider);
        vm.assume(receiver != address(pool));

        setTrancheState(initialShares, wrapperShares, initialAssets);
        stdstore.target(address(trancheWrapper)).sig(tranche.balanceOf.selector).with_key(owner).checked_write(
            ownerShares
        );
        withdrawnAssets = uint128(bound(withdrawnAssets, 0, trancheWrapper.maxWithdraw(owner)));

        uint256 expectedShares = tranche.previewWithdraw(withdrawnAssets);
        vm.assume(expectedShares > 0);

        vm.prank(owner);
        uint256 actualShares = trancheWrapper.withdraw(withdrawnAssets, receiver, owner);

        assertEq(actualShares, expectedShares);
        assertEq(trancheWrapper.totalAssets(), tranche.convertToAssets(wrapperShares - actualShares));
        assertEq(tranche.totalAssets(), initialAssets - withdrawnAssets);
        assertEq(trancheWrapper.totalSupply(), wrapperShares - actualShares);
        assertEq(tranche.totalSupply(), initialShares - actualShares);
        assertEq(tranche.balanceOf(address(trancheWrapper)), wrapperShares - actualShares);
        assertEq(trancheWrapper.balanceOf(owner), ownerShares - actualShares);
        assertEq(asset.balanceOf(receiver), withdrawnAssets);
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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(owner);
        trancheWrapper.approve(beneficiary, sharesAllowed);

        vm.startPrank(beneficiary);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.totalAssets(), assetsDeposited - assetsWithdrawn);

        assertEq(trancheWrapper.allowance(owner, beneficiary), sharesAllowed - assetsWithdrawn);

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
        trancheWrapper.deposit(assetsDeposited, owner);

        vm.prank(owner);
        trancheWrapper.approve(beneficiary, type(uint256).max);

        vm.startPrank(beneficiary);
        trancheWrapper.withdraw(assetsWithdrawn, receiver, owner);

        assertEq(trancheWrapper.maxWithdraw(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.maxRedeem(owner), assetsDeposited - assetsWithdrawn);
        assertEq(trancheWrapper.totalAssets(), assetsDeposited - assetsWithdrawn);

        assertEq(trancheWrapper.allowance(owner, beneficiary), type(uint256).max);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);
    }
}
