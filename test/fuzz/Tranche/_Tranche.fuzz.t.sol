/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

import { stdStorage, StdStorage } from "../../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";
import { TrancheExtension } from "../../utils/Extensions.sol";

/**
 * @notice Common logic needed by all "Tranche" fuzz tests.
 */
abstract contract Tranche_Fuzz_Test is Fuzz_Lending_Test {
    using stdStorage for StdStorage;
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
        pool.addTranche(address(tranche), 50);

        vm.prank(users.tokenCreatorAddress);
        asset.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        asset.approve(address(pool), type(uint256).max);
    }

    function setTrancheState(uint256 vas, uint256 totalSupply, uint128 totalAssets) public returns (address tranche_) {
        vm.startPrank(users.creatorAddress);
        tranche = new TrancheExtension(address(pool), vas, "Tranche", "T");
        pool.addTranche(address(tranche), 0);
        vm.stopPrank();

        stdstore.target(address(tranche)).sig(pool.totalSupply.selector).checked_write(totalSupply);
        pool.setTotalRealisedLiquidity(totalAssets);
        pool.setRealisedLiquidityOf(address(tranche), totalAssets);

        tranche_ = address(tranche);
    }
}
