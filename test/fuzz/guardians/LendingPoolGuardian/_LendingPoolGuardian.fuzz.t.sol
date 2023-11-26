/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../../Fuzz.t.sol";

import { LendingPoolGuardianExtension } from "../../../utils/Extensions.sol";
import { BaseGuardian, GuardianErrors } from "../../../../lib/accounts-v2/src/guardians/BaseGuardian.sol";

/**
 * @notice Common logic needed by all "LendingPoolGuardian" fuzz tests.
 */
abstract contract LendingPoolGuardian_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    struct Flags {
        bool repayPaused;
        bool withdrawPaused;
        bool borrowPaused;
        bool depositPaused;
        bool liquidationPaused;
    }

    /*////////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LendingPoolGuardianExtension internal lendingPoolGuardian;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithoutAccounts();

        vm.startPrank(users.creatorAddress);
        lendingPoolGuardian = new LendingPoolGuardianExtension();
        lendingPoolGuardian.changeGuardian(users.guardian);
        vm.stopPrank();

        vm.warp(60 days);
    }

    /*////////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */
    function setFlags(Flags memory flags) internal {
        lendingPoolGuardian.setFlags(
            flags.repayPaused, flags.withdrawPaused, flags.borrowPaused, flags.depositPaused, flags.liquidationPaused
        );
    }
}
