/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

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

    function redeployAndSetTrancheState(uint256 vas, uint256 totalSupply, uint128 totalAssets) internal {
        vm.startPrank(users.owner);
        tranche = new TrancheExtension(users.owner, address(pool), vas, "Tranche", "T");
        pool.addTranche(address(tranche), 0);
        vm.stopPrank();

        trancheWrapper = new TrancheWrapper(address(tranche));

        stdstore.target(address(tranche)).sig(tranche.totalSupply.selector).checked_write(totalSupply);
        pool.setTotalRealisedLiquidity(totalAssets);
        pool.setRealisedLiquidityOf(address(tranche), totalAssets);
    }

    function setTrancheState(uint128 initialShares, uint128 wrapperShares, uint128 initialAssets) internal {
        pool.setTotalRealisedLiquidity(initialAssets);
        pool.setRealisedLiquidityOf(address(tranche), initialAssets);
        stdstore.target(address(tranche)).sig(tranche.totalSupply.selector).checked_write(initialShares);
        stdstore.target(address(tranche)).sig(tranche.balanceOf.selector).with_key(address(trancheWrapper))
            .checked_write(wrapperShares);
        stdstore.target(address(trancheWrapper)).sig(trancheWrapper.totalSupply.selector).checked_write(wrapperShares);

        vm.prank(users.liquidityProvider);
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        asset.transfer(address(pool), initialAssets);
    }
}
