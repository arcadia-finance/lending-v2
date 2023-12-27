/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "setTrancheWeights" of contract "LendingPool".
 */
contract SetTrancheWeights_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testFuzz_Revert_setTrancheWeights_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTrancheWeights(0, 10, 50);
        vm.stopPrank();
    }

    function testFuzz_Revert_setTrancheWeights_InexistingTranche(uint256 index) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert(NonExistingTranche.selector);
        pool.setTrancheWeights(index, 10, 50);
        vm.stopPrank();
    }

    function testFuzz_Success_setTrancheWeights() public {
        vm.startPrank(users.creatorAddress);
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit TrancheWeightsUpdated(0, 10, 40);
        pool.setTrancheWeights(0, 10, 40);
        vm.stopPrank();

        assertEq(pool.getTotalInterestWeight(), 10);
        assertEq(pool.getInterestWeightTranches(0), 10);
        assertEq(pool.getInterestWeight(address(srTranche)), 10);
        assertEq(pool.getTotalLiquidationWeight(), 40);
        assertEq(pool.getLiquidationWeightTranches(0), 40);
    }
}
