/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "Liquidator" fuzz tests.
 */
abstract contract Liquidator_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();

        vm.prank(users.creatorAddress);
        pool.setAccountVersion(1, true);

        vm.prank(users.accountOwner);
        proxyAccount.openTrustedMarginAccount(address(pool));
    }
}
