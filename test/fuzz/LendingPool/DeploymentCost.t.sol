/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPool } from "../../../src/LendingPool.sol";

/**
 * @notice Fuzz tests for the function "addTranche" of contract "LendingPool".
 */
contract DeploymentCost_LendingPool is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        lendingPool =
            new LendingPool(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_DeploymentCostLendingPool(uint16 interestWeight, uint16 liquidationWeight) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(srTranche), 0, interestWeight, liquidationWeight);
        lendingPool.addTranche(address(srTranche), interestWeight, liquidationWeight);
        vm.stopPrank();
    }
}