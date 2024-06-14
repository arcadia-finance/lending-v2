pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdError } from "../../../lib/forge-std/src/StdError.sol";


/**
 * @notice Fuzz tests for the function "withdraw" of contract "Tranche Wrapper".
 */
contract Withdraw_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

     function testFuzz_Revert_withdraw_Locked(uint128 assets, address receiver, address owner) public {
        vm.prank(address(pool));
        tranche.lock();
     

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(Locked.selector);
        trancheWrapper.withdraw(assets, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_AuctionInProgress(uint128 assets, address receiver, address owner) public {
        vm.prank(address(pool));
        tranche.setAuctionInProgress(true);

        vm.startPrank(users.liquidityProvider);
        vm.expectRevert(AuctionOngoing.selector);
        trancheWrapper.withdraw(assets, receiver, owner);
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

        //This should be the tranche, right? Not the the tranchewrapper
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

        // is this tranche, tranchewrapper or can this be deleted
        assertEq(trancheWrapper.allowance(owner, beneficiary), type(uint256).max);
        assertEq(asset.balanceOf(address(pool)), assetsDeposited - assetsWithdrawn);
        assertEq(asset.balanceOf(receiver), assetsWithdrawn);

        //Can we check whether the same number of shares are burned in the wrapper as in the tranche
    }


    
    }