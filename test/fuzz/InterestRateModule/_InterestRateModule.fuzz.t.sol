/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

import { InterestRateModuleExtension } from "../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "InterestRateModule" fuzz tests.
 */
abstract contract InterestRateModule_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    InterestRateModuleExtension internal interestRateModule;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithoutAccounts();

        interestRateModule = new InterestRateModuleExtension();
    }
}
