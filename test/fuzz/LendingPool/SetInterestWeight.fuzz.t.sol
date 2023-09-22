/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LendingPool_Fuzz_Test } from "./_LendingPool.fuzz.t.sol";

import { ERC20 } from "../../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPoolExtension } from "../../utils/Extensions.sol";

/**
 * @notice Fuzz tests for the "setInterestWeight" of contract "LendingPool".
 */
contract SetInterestWeight_LendingPool_Fuzz_Test is LendingPool_Fuzz_Test {
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
    function testRevert_setInterestWeight_InvalidOwner(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != users.creatorAddress);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        pool.setInterestWeight(0, 50);
        vm.stopPrank();
    }

    function testRevert_setInterestWeight_InexistingTranche(uint256 index) public {
        vm.startPrank(users.creatorAddress);
        vm.expectRevert("TR_SIW: Non Existing Tranche");
        pool.setInterestWeight(index, 50);
        vm.stopPrank();
    }

    function testSuccess_setInterestWeight() public {
        vm.startPrank(users.creatorAddress);
        pool.addTranche(address(srTranche), 50, 0);

        vm.expectEmit(true, true, true, true);
        emit InterestWeightSet(0, 40);
        pool.setInterestWeight(0, 40);
        vm.stopPrank();

        assertEq(pool.totalInterestWeight(), 40);
        assertEq(pool.interestWeightTranches(0), 40);
        assertEq(pool.interestWeight(address(srTranche)), 40);
    }
}
