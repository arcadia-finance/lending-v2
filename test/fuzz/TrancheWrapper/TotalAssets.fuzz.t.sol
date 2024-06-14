/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { TrancheWrapper_Fuzz_Test } from "./_TrancheWrapper.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the function "totalAssets" of contract "Tranche".
 */
contract TotalAssets_TrancheWrapper_Fuzz_Test is TrancheWrapper_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        TrancheWrapper_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testFuzz_Success_totalAssets(uint128 assets) public {
        pool.setRealisedLiquidityOf(address(tranche), assets);

        assertEq(trancheWrapper.totalAssets(), assets);

        //this is redundant, right? totalAssetsAndSync is not a function of the tranche wrapper
        assertEq(tranche.totalAssetsAndSync(), assets);
    }
}
