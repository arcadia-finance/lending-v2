/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Script } from "./Base.s.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract CircuitBreaker is Base_Lending_Script {
    constructor() { }

    function run() public {
        // Pause Lending Pools.
        bytes memory calldata_ = abi.encodeCall(lendingPoolCbbtc.pause, ());
        addToBatch(Safes.GUARDIAN, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolUsdc.pause, ());
        addToBatch(Safes.GUARDIAN, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(lendingPoolWeth.pause, ());
        addToBatch(Safes.GUARDIAN, address(lendingPoolWeth), calldata_);

        // Pause Registry.
        calldata_ = abi.encodeCall(registry.pause, ());
        addToBatch(Safes.GUARDIAN, address(registry), calldata_);

        // Pause Factory.
        calldata_ = abi.encodeCall(factory.pause, ());
        addToBatch(Safes.GUARDIAN, address(factory), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(Safes.GUARDIAN);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
