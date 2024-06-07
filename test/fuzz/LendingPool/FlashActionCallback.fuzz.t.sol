/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ActionData } from "../../../lib/accounts-v2/src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../../lib/accounts-v2/src/actions/MultiCall.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";
import { IPermit2 } from "../../../lib/accounts-v2/src/interfaces/IPermit2.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "flashActionCallback" of contract "LendingPool".
 */
contract FlashActionCallback_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCall internal actionHandler;
    bytes internal callData;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_flashActionCallback_Unauthorised(
        address account,
        address sender,
        bytes calldata callbackData
    ) public {
        vm.assume(account != sender);

        pool.setCallbackAccount(account);

        vm.prank(sender);
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.flashActionCallback(callbackData);
    }

    function testFuzz_Revert_flashActionCallback_InsufficientLiquidity(
        uint128 amountLoaned,
        uint128 liquidity,
        address account,
        address actionTarget,
        address sender,
        bytes3 referrer
    ) public {
        vm.assume(liquidity < amountLoaned);
        vm.assume(liquidity > 0);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setCallbackAccount(account);
        bytes memory callbackData = abi.encode(amountLoaned, actionTarget, sender, referrer);

        vm.prank(account);
        vm.expectRevert("TRANSFER_FAILED");
        pool.flashActionCallback(callbackData);
    }

    function testFuzz_Success_flashActionCallback(
        uint128 amountLoaned,
        uint128 liquidity,
        address account,
        address actionTarget,
        address sender,
        bytes3 referrer,
        uint8 originationFee
    ) public {
        vm.assume(account != users.liquidityProvider);
        vm.assume(account != address(pool));
        vm.assume(account != actionTarget);
        vm.assume(account != treasury);

        vm.assume(liquidity >= amountLoaned);
        uint256 fee = uint256(amountLoaned).mulDivUp(originationFee, 10_000);
        vm.assume(liquidity <= type(uint128).max - fee);
        vm.assume(amountLoaned > 0);

        vm.prank(users.owner);
        pool.setOriginationFee(originationFee);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setCallbackAccount(account);
        bytes memory callbackData = abi.encode(amountLoaned, actionTarget, sender, referrer);

        vm.startPrank(account);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.Borrow(account, sender, actionTarget, amountLoaned, fee, referrer);
        pool.flashActionCallback(callbackData);
        vm.stopPrank();

        assertEq(pool.getCallbackAccount(), address(0));
        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(actionTarget), amountLoaned);
        assertEq(debt.balanceOf(account), uint256(amountLoaned) + fee);
        assertEq(pool.liquidityOf(treasury), fee);
        assertEq(pool.totalLiquidity(), liquidity + fee);
    }
}
