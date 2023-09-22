/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "setLiquidationWeight" of contract "LendingPool".
 */
contract SetLiquidationWeight_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pool =
            new LendingPoolExtension(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setLiquidationWeight_InvalidOwner(address unprivilegedAddress) public {
        // Given: all neccesary contracts are deployed on the setup
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        // When: unprivilegedAddress setInterestWeight
        // Then: setInterestWeight should revert with UNAUTHORIZED
        vm.expectRevert("UNAUTHORIZED");
        pool.setLiquidationWeight(0, 50);
        vm.stopPrank();
    }

    function testFuzz_Revert_setLiquidationWeight_InexistingTranche() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress setInterestWeight on index 0
        // Then: setInterestWeight should revert with TR_SIW: Non Existing Tranche
        vm.expectRevert("TR_SLW: Non Existing Tranche");
        pool.setLiquidationWeight(0, 50);
        vm.stopPrank();
    }

    function testFuzz_Success_setLiquidationWeight() public {
        // Given: all neccesary contracts are deployed on the setup
        vm.startPrank(users.creatorAddress);
        // When: users.creatorAddress calls addTranche with srTranche and 50, calss setInterestWeight with 0 and 40
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit LiquidationWeightSet(0, 40);
        pool.setLiquidationWeight(0, 40);
        vm.stopPrank();

        // Then: totalInterestWeight should be equal to 40, interestWeightTranches index 0 should return 40, interestWeight of srTranche should return 40
        assertEq(pool.totalLiquidationWeight(), 40);
        assertEq(pool.liquidationWeightTranches(0), 40);
    }
}
