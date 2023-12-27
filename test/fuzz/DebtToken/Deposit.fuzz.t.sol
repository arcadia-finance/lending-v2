/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { DebtToken_Fuzz_Test } from "./_DebtToken.fuzz.t.sol";

import { StdStorage, stdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "deposit" of contract "DebtToken".
 */
contract Deposit_DebtToken_Fuzz_Test is DebtToken_Fuzz_Test {
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
    function testFuzz_Revert_deposit_External(uint256 assets, address receiver, address sender) public {
        vm.startPrank(sender);
        vm.expectRevert(FunctionNotImplemented.selector);
        debt_.deposit(assets, receiver);
        vm.stopPrank();
    }

    function testFuzz_Success_deposit_Internal_FirstDeposit(uint256 assets, address receiver) public {
        vm.assume(assets > 0);

        debt_.deposit_(assets, receiver);

        assertEq(debt_.balanceOf(receiver), assets);
        assertEq(debt_.totalSupply(), assets);
        assertEq(debt_.getRealisedDebt(), assets);
    }

    function testFuzz_Success_deposit_Internal_NotFirstDeposit(
        uint256 assets,
        address receiver,
        uint256 totalSupply,
        uint256 totalDebt
    ) public {
        vm.assume(assets <= totalDebt);
        vm.assume(assets <= type(uint256).max - totalDebt);
        vm.assume(assets > 0);
        vm.assume(totalSupply > 0); //Not first deposit
        vm.assume(assets <= type(uint256).max / totalSupply); //Avoid overflow in next assumption

        stdstore.target(address(debt_)).sig(debt_.totalSupply.selector).checked_write(totalSupply);

        debt_.setRealisedDebt(totalDebt);

        uint256 shares = assets * totalSupply / totalDebt;
        if (shares * totalDebt < assets * totalSupply) {
            //Must round up
            shares += 1;
        }
        vm.assume(shares <= type(uint256).max - totalSupply);

        debt_.deposit_(assets, receiver);

        assertEq(debt_.balanceOf(receiver), shares);
        assertEq(debt_.totalSupply(), totalSupply + shares);
        assertEq(debt_.getRealisedDebt(), totalDebt + assets);
    }
}
