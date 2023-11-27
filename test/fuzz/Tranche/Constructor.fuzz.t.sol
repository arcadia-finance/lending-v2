/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { Tranche } from "../../../src/Tranche.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "Tranche".
 */
contract Constructor_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        tranche = new Tranche(address(pool), "Senior", "SR");

        assertEq(tranche.name(), string("Senior ArcadiaV2 Asset"));
        assertEq(tranche.symbol(), string("SRarcV2ASSET"));
        assertEq(tranche.decimals(), 18);
        assertEq(address(tranche.LENDING_POOL()), address(pool));
    }
}
