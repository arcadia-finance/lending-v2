/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DebtToken_Fuzz_Test } from "./_DebtToken.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "withdraw" of contract "DebtToken".
 */
contract Withdraw_DebtToken_Fuzz_Test is DebtToken_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        DebtToken_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_withdraw_External(uint256 assets, address receiver, address owner, address sender)
        public
    {
        vm.startPrank(sender);
        vm.expectRevert(FunctionNotImplemented.selector);
        debt_.withdraw(assets, receiver, owner);
        vm.stopPrank();
    }

    function testFuzz_Revert_withdraw_Internal_ZeroShares(
        uint256 assets,
        address owner,
        uint256 totalSupply,
        uint256 totalDebt
    ) public {
        vm.assume(assets <= totalDebt);
        vm.assume(totalSupply > 0); //First mint new shares are issued equal to amount of assets -> error will not throw
        vm.assume(assets <= type(uint256).max / totalSupply); //Avoid overflow in next assumption

        //Will result in zero shares being created
        vm.assume(totalDebt > assets * totalSupply);

        stdstore.target(address(debt_)).sig(debt_.totalSupply.selector).checked_write(totalSupply);
        debt_.setRealisedDebt(totalDebt);

        vm.expectRevert(ZeroShares.selector);
        debt_.withdraw_(assets, owner, owner);
    }

    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function testFuzz_Success_withdraw_Internal(
        uint256 assetsWithdrawn,
        address owner,
        uint256 initialShares,
        uint256 totalSupply,
        uint256 totalDebt
    ) public {
        vm.assume(assetsWithdrawn <= totalDebt);
        vm.assume(totalDebt > 0);
        vm.assume(initialShares <= totalSupply);
        vm.assume(totalSupply > 0);
        vm.assume(assetsWithdrawn <= type(uint256).max / totalSupply); //Avoid overflow in next assumption
        vm.assume(totalDebt <= assetsWithdrawn * totalSupply);

        uint256 sharesRedeemed = assetsWithdrawn * totalSupply / totalDebt;
        vm.assume(sharesRedeemed <= initialShares);

        stdstore.target(address(debt_)).sig(debt_.balanceOf.selector).with_key(owner).checked_write(initialShares);
        stdstore.target(address(debt_)).sig(debt_.totalSupply.selector).checked_write(totalSupply);
        debt_.setRealisedDebt(totalDebt);

        vm.expectEmit(true, true, true, false);
        emit Withdraw(address(this), owner, owner, assetsWithdrawn, 0);
        debt_.withdraw_(assetsWithdrawn, owner, owner);

        assertEq(debt_.balanceOf(owner), initialShares - sharesRedeemed);
        assertEq(debt_.totalSupply(), totalSupply - sharesRedeemed);
        assertEq(debt_.getRealisedDebt(), totalDebt - assetsWithdrawn);
    }
}
