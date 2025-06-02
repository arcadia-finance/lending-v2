/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL2_Fuzz_Test } from "./_LiquidatorL2.fuzz.t.sol";

import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";
import { SequencerUptimeOracle } from "../../../../lib/accounts-v2/test/utils/mocks/oracles/SequencerUptimeOracle.sol";

/**
 * @notice Fuzz tests for the function "setSequencerUptimeOracle" of contract "LiquidatorL2".
 */
contract SetSequencerUptimeOracle_LiquidatorL2_Fuzz_Test is LiquidatorL2_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL2_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Revert_setSequencerUptimeOracle_NonOwner(
        address unprivilegedAddress,
        address sequencerUptimeOracle_
    ) public {
        // Given: unprivilegedAddress_ is not users.owner
        vm.assume(unprivilegedAddress != users.owner);

        // When: unprivilegedAddress_ calls setSequencerUptimeOracle
        // Then: Function reverts with "UNAUTHORIZED"
        vm.prank(unprivilegedAddress);
        vm.expectRevert("UNAUTHORIZED");
        liquidator.setSequencerUptimeOracle(sequencerUptimeOracle_);
    }

    function testFuzz_Revert_setSequencerUptimeOracle_OracleNotReverting(address sequencerUptimeOracle_) public {
        // Given: Current sequencer oracle is active.
        // When: owner calls setSequencerUptimeOracle with new oracle.
        // Then: Function reverts with OracleNotReverting.
        vm.prank(users.owner);
        vm.expectRevert(LiquidatorErrors.OracleNotReverting.selector);
        liquidator.setSequencerUptimeOracle(sequencerUptimeOracle_);
    }

    function testFuzz_Revert_setSequencerUptimeOracle_OracleReverting() public {
        // Given: Current sequencer oracle reverts.
        sequencerUptimeOracle.setRevertsFlag(true);

        // And: New sequencer oracle reverts.
        SequencerUptimeOracle sequencerUptimeOracle_ = new SequencerUptimeOracle();
        sequencerUptimeOracle_.setRevertsFlag(true);

        // When: owner calls setSequencerUptimeOracle with new oracle.
        // Then: Function reverts with OracleReverting.
        vm.prank(users.owner);
        vm.expectRevert(LiquidatorErrors.OracleReverting.selector);
        liquidator.setSequencerUptimeOracle(address(sequencerUptimeOracle_));
    }

    function testFuzz_Success_setSequencerUptimeOracle() public {
        // Given: Current sequencer oracle reverts.
        sequencerUptimeOracle.setRevertsFlag(true);

        // And: New sequencer oracle is active.
        SequencerUptimeOracle sequencerUptimeOracle_ = new SequencerUptimeOracle();

        // When: owner calls setSequencerUptimeOracle with new oracle.
        vm.prank(users.owner);
        liquidator.setSequencerUptimeOracle(address(sequencerUptimeOracle_));

        // Then: New sequencer oracle is set.
        assertEq(liquidator.getSequencerUptimeOracle(), address(sequencerUptimeOracle_));
    }
}
