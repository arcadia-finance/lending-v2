/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Tranche_Fuzz_Test } from "../Tranche/_Tranche.fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheExtension } from "../../utils/extensions/TrancheExtension.sol";

/**
 * @notice Common logic needed by all "Tranche" fuzz tests.
 */
abstract contract TrancheWrapper_Fuzz_Test is Tranche_Fuzz_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Tranche_Fuzz_Test) {
        Tranche_Fuzz_Test.setUp();
        vm.prank(users.liquidityProvider);
        asset.approve(address(trancheWrapper), type(uint256).max);
    }
}
