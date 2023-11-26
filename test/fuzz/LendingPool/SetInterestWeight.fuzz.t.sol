/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "setInterestWeight" of contract "LendingPool".
 */

contract SetInterestWeight_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pool = new LendingPoolExtension(
            users.riskManager, ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator)
        );
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setInterestWeight_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestWeight(0, 50);
        vm.stopPrank();
    }

    function testFuzz_Revert_setInterestWeight_InexistingTranche(uint256 index) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(NonExistingTranche.selector);
        pool.setInterestWeight(index, 50);
        vm.stopPrank();
    }

    function testFuzz_Success_setInterestWeight() public {
        vm.startPrank(users.creatorAddress);
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit TrancheInterestWeightSet(0, 40);
        pool.setInterestWeight(0, 40);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 40);
        assertEq(pool.getInterestWeightTranches(0), 40);
        assertEq(pool.getInterestWeight(address(srTranche)), 40);
    }
}
