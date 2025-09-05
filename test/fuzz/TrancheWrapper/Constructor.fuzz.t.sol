/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { TrancheExtension } from "../../utils/extensions/TrancheExtension.sol";
import { TrancheWrapper } from "../../../src/periphery/tranche-wrapper/TrancheWrapper.sol";

/**
 * @notice Fuzz tests for the function "constructor" of contract "TrancheWrapper".
 */
contract Constructor_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_deployment() public {
        trancheWrapper = new TrancheWrapper(address(srTranche));

        assertEq(trancheWrapper.name(), string("Wrapped Senior ArcadiaV2 Asset"));
        assertEq(trancheWrapper.symbol(), string("wSRarcV2ASSET"));
        assertEq(trancheWrapper.decimals(), tranche.decimals());
        assertEq(trancheWrapper.LENDING_POOL(), address(pool));
        assertEq(trancheWrapper.TRANCHE(), address(srTranche));
    }
}
