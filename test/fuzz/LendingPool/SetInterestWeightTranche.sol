/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolExtension } from "../../utils/extensions/LendingPoolExtension.sol";
import { LendingPoolErrors } from "../../../src/libraries/Errors.sol";

/**
 * @notice Fuzz tests for the function "setInterestWeightTranche" of contract "LendingPool".
 */
contract SetInterestWeightTranche_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.owner);
        pool = new LendingPoolExtension(
            users.riskManager, ERC20(address(mockERC20.stable1)), users.treasury, address(factory), address(liquidator)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setInterestWeightTranche_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestWeightTranche(0, 10);
        vm.stopPrank();
    }

    function testFuzz_Revert_setInterestWeightTranche_InexistingTranche(uint256 index) public {
        vm.startPrank(users.owner);
        vm.expectRevert(LendingPoolErrors.NonExistingTranche.selector);
        pool.setInterestWeightTranche(index, 10);
        vm.stopPrank();
    }

    function testFuzz_Success_setInterestWeightTranche() public {
        vm.startPrank(users.owner);
        pool.addTranche(address(srTranche), 50);

        vm.expectEmit(true, true, true, true);
        emit LendingPool.InterestWeightTrancheUpdated(address(srTranche), 0, 10);
        pool.setInterestWeightTranche(0, 10);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 10);
        assertEq(pool.getInterestWeightTranches(0), 10);
        assertEq(pool.getInterestWeight(address(srTranche)), 10);
    }
}
