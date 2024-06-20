/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheExtension } from "../../utils/extensions/TrancheExtension.sol";
import { TrancheWrapper } from "../../../src/periphery/tranche-wrapper/TrancheWrapper.sol";

/**
 * @notice Common logic needed by all "TrancheWrapper" fuzz tests.
 */
abstract contract TrancheWrapper_Fuzz_Test is Fuzz_Lending_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                         TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    TrancheWrapper internal trancheWrapper;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithoutAccounts();

        trancheWrapper = new TrancheWrapper(address(srTranche));

        vm.prank(users.tokenCreator);
        asset.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        asset.approve(address(trancheWrapper), type(uint256).max);
    }

    function setTrancheState(uint256 vas, uint256 totalSupply, uint128 totalAssets) internal {
        vm.startPrank(users.owner);
        tranche = new TrancheExtension(address(pool), vas, "Tranche", "T");
        pool.addTranche(address(tranche), 0);
        vm.stopPrank();

        trancheWrapper = new TrancheWrapper(address(tranche));

        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalSupply);
        pool.setTotalRealisedLiquidity(totalAssets);
        pool.setRealisedLiquidityOf(address(tranche), totalAssets);
    }
}
