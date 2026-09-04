/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";
import { ActionTargetMock } from "../../../lib/accounts-v2/test/utils/mocks/action-targets/ActionTargetMock.sol";
import { FixedPointMathLib } from "../../../lib/accounts-v2/lib/solmate/src/utils/FixedPointMathLib.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "flashActionCallback" of contract "LendingPool".
 */
// forge-lint: disable-next-item(unsafe-typecast)
contract FlashActionCallback_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    using FixedPointMathLib for uint256;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionTargetMock internal actionHandler;
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
        address account_,
        address sender,
        bytes calldata callbackData
    ) public {
        vm.assume(account_ != sender);

        pool.setCallbackAccount(account_);

        vm.prank(sender);
        vm.expectRevert(LendingPoolErrors.Unauthorized.selector);
        pool.flashActionCallback(callbackData);
    }

    function testFuzz_Revert_flashActionCallback_InsufficientLiquidity(
        uint128 amountLoaned,
        uint128 liquidity,
        address account_,
        address actionTarget,
        address sender,
        bytes3 referrer
    ) public {
        // Given: There is insufficient liquidity for the loan.
        amountLoaned = uint128(bound(amountLoaned, 2, type(uint128).max));
        liquidity = uint128(bound(liquidity, 1, uint256(amountLoaned) - 1));

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setCallbackAccount(account_);
        bytes memory callbackData = abi.encode(amountLoaned, actionTarget, sender, referrer);

        vm.prank(account_);
        vm.expectRevert("TRANSFER_FAILED");
        pool.flashActionCallback(callbackData);
    }

    function testFuzz_Success_flashActionCallback(
        uint128 amountLoaned,
        uint128 liquidity,
        address account_,
        address actionTarget,
        address sender,
        bytes3 referrer,
        uint8 originationFee
    ) public {
        vm.assume(account_ != users.liquidityProvider);
        vm.assume(account_ != address(pool));
        vm.assume(account_ != actionTarget);
        vm.assume(account_ != users.treasury);
        vm.assume(actionTarget != users.liquidityProvider);
        vm.assume(actionTarget != address(pool));
        vm.assume(actionTarget != users.treasury);

        // Given: The loan and its origination fee do not overflow.
        amountLoaned = uint128(
            bound(amountLoaned, 1, uint256(type(uint128).max) * 10_000 / (10_000 + uint256(originationFee)) - 1)
        );
        uint256 fee = uint256(amountLoaned).mulDivUp(originationFee, 10_000);

        // And: There is sufficient liquidity.
        liquidity = uint128(bound(liquidity, amountLoaned, type(uint128).max - fee));

        vm.prank(users.owner);
        pool.setOriginationFee(originationFee);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(address(srTranche));
        pool.depositInLendingPool(liquidity, users.liquidityProvider);

        pool.setCallbackAccount(account_);
        bytes memory callbackData = abi.encode(amountLoaned, actionTarget, sender, referrer);

        vm.startPrank(account_);
        vm.expectEmit(true, true, true, true);
        emit LendingPool.Borrow(account_, sender, actionTarget, amountLoaned, fee, referrer);
        pool.flashActionCallback(callbackData);
        vm.stopPrank();

        assertEq(pool.getCallbackAccount(), address(0));
        assertEq(mockERC20.stable1.balanceOf(address(pool)), liquidity - amountLoaned);
        assertEq(mockERC20.stable1.balanceOf(actionTarget), amountLoaned);
        assertEq(debt.balanceOf(account_), uint256(amountLoaned) + fee);
        assertEq(pool.liquidityOf(users.treasury), fee);
        assertEq(pool.totalLiquidity(), liquidity + fee);
    }
}
