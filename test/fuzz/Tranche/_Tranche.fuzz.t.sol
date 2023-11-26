/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

/**
 * @notice Common logic needed by all "Tranche" fuzz tests.
 */
abstract contract Tranche_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithoutAccounts();

        vm.prank(users.creatorAddress);
        pool.addTranche(address(tranche), 50, 0);

        vm.prank(users.tokenCreatorAddress);
        asset.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }
}
