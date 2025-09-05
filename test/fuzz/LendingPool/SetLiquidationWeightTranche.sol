/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { LendingPool } from "../../../src/LendingPool.sol";
import { LendingPoolExtension } from "../../utils/extensions/LendingPoolExtension.sol";

/**
 * @notice Fuzz tests for the function "setLiquidationWeightTranche" of contract "LendingPool".
 */
contract SetLiquidationWeightTranche_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setLiquidationWeightTranche_InvalidOwner(
        address unprivilegedAddress,
        uint16 liquidationWeight
    ) public {
        vm.assume(unprivilegedAddress != users.owner);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationWeightTranche(liquidationWeight);
        vm.stopPrank();
    }

    function testFuzz_Success_setLiquidationWeightTranche(uint16 liquidationWeight) public {
        vm.prank(users.owner);
        vm.expectEmit();
        emit LendingPool.LiquidationWeightTrancheUpdated(liquidationWeight);
        pool.setLiquidationWeightTranche(liquidationWeight);
        vm.stopPrank();

        assertEq(pool.getLiquidationWeightTranche(), liquidationWeight);
    }
}
