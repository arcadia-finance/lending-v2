/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Tranche_Fuzz_Test } from "./_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

/**
 * @notice Fuzz tests for the "totalAssets" of contract "Tranche".
 */
contract TotalAssets_Tranche_Fuzz_Test is Tranche_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Tranche_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testSuccess_totalAssets(uint128 assets) public {
        stdstore.target(address(pool)).sig(pool.realisedLiquidityOf.selector).with_key(address(tranche)).checked_write(
            assets
        );

        assertEq(tranche.totalAssets(), assets);
    }
}