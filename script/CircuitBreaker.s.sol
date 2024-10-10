/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { ArcadiaSafes } from "../lib/accounts-v2/script/utils/Constants.sol";

contract CircuitBreaker is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        // Pause Lending Pools.
        bytes memory calldata_ = abi.encodeCall(lendingPoolCbbtc.pause, ());
        addToBatch(ArcadiaSafes.GUARDIAN, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolUsdc.pause, ());
        addToBatch(ArcadiaSafes.GUARDIAN, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolWeth.pause, ());
        addToBatch(ArcadiaSafes.GUARDIAN, address(lendingPoolWeth), calldata_);

        // Pause Registry.
        calldata_ = abi.encodeCall(registry.pause, ());
        addToBatch(ArcadiaSafes.GUARDIAN, address(registry), calldata_);

        // Pause Factory.
        calldata_ = abi.encodeCall(factory.pause, ());
        addToBatch(ArcadiaSafes.GUARDIAN, address(factory), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.GUARDIAN);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
