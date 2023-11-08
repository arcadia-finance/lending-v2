/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "addTranche" of contract "LendingPool".
 */
contract AddTranche_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LendingPoolExtension internal pool_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LendingPool_Fuzz_Test.setUp();

        vm.prank(users.creatorAddress);
        pool_ =
        new LendingPoolExtension(users.riskManager, ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_addTranche_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool_.addTranche(address(srTranche), 50, 0);
        vm.stopPrank();
    }

    function testFuzz_Revert_addTranche_SingleTrancheTwice() public {
        vm.startPrank(users.creatorAddress);
        pool_.addTranche(address(srTranche), 50, 0);
        vm.expectRevert(LendingPool_TrancheAlreadyExists.selector);
        pool_.addTranche(address(srTranche), 40, 0);
        vm.stopPrank();
    }

    function testFuzz_Success_addTranche_SingleTranche(uint16 interestWeight, uint16 liquidationWeight) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(srTranche), 0, interestWeight, liquidationWeight);
        pool_.addTranche(address(srTranche), interestWeight, liquidationWeight);
        vm.stopPrank();

        assertEq(pool_.getTotalInterestWeight(), interestWeight);
        assertEq(pool_.getInterestWeightTranches(0), interestWeight);
        assertEq(pool_.getInterestWeight(address(srTranche)), interestWeight);
        assertEq(pool_.getTotalLiquidationWeight(), liquidationWeight);
        assertEq(pool_.getLiquidationWeightTranches(0), liquidationWeight);
        assertEq(pool_.getTranches(0), address(srTranche));
        assertTrue(pool_.getIsTranche(address(srTranche)));
    }

    function testFuzz_Success_addTranche_MultipleTranches(
        uint16 interestWeightSr,
        uint16 liquidationWeightSr,
        uint16 interestWeightJr,
        uint16 liquidationWeightJr
    ) public {
        vm.startPrank(users.creatorAddress);
        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(srTranche), 0, interestWeightSr, liquidationWeightSr);
        pool_.addTranche(address(srTranche), interestWeightSr, liquidationWeightSr);

        vm.expectEmit(true, true, true, true);
        emit TrancheAdded(address(jrTranche), 1, interestWeightJr, liquidationWeightJr);
        pool_.addTranche(address(jrTranche), interestWeightJr, liquidationWeightJr);
        vm.stopPrank();

        assertEq(pool_.getTotalInterestWeight(), uint256(interestWeightSr) + interestWeightJr);
        assertEq(pool_.getInterestWeightTranches(0), interestWeightSr);
        assertEq(pool_.getInterestWeightTranches(1), interestWeightJr);
        assertEq(pool_.getInterestWeight(address(srTranche)), interestWeightSr);
        assertEq(pool_.getInterestWeight(address(jrTranche)), interestWeightJr);
        assertEq(pool_.getTotalLiquidationWeight(), uint256(liquidationWeightSr) + liquidationWeightJr);
        assertEq(pool_.getLiquidationWeightTranches(0), liquidationWeightSr);
        assertEq(pool_.getLiquidationWeightTranches(1), liquidationWeightJr);
        assertEq(pool_.getTranches(0), address(srTranche));
        assertEq(pool_.getTranches(1), address(jrTranche));
        assertTrue(pool_.getIsTranche(address(srTranche)));
        assertTrue(pool_.getIsTranche(address(jrTranche)));
    }
}
