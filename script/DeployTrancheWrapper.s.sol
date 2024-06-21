/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { TrancheWrapper } from "../src/periphery/tranche-wrapper/TrancheWrapper.sol";

contract DeployTrancheWrapper is Base_Lending_Script {
    TrancheWrapper internal wrappedTrancheUsdc;
    TrancheWrapper internal wrappedTrancheWeth;

    constructor() Base_Lending_Script() { }

    function run() public {
        vm.startBroadcast(deployer);
        wrappedTrancheUsdc = new TrancheWrapper(address(trancheUsdc));
        wrappedTrancheWeth = new TrancheWrapper(address(trancheWeth));
        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(true);

        assertEq(wrappedTrancheUsdc.LENDING_POOL(), address(lendingPoolUsdc));
        assertEq(wrappedTrancheWeth.LENDING_POOL(), address(lendingPoolWeth));
        assertEq(wrappedTrancheUsdc.TRANCHE(), address(trancheUsdc));
        assertEq(wrappedTrancheWeth.TRANCHE(), address(trancheWeth));
    }
}
