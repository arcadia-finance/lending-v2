/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract Unpause is Base_Lending_Script {
    address SAFE = Safes.OWNER;

    constructor() Base_Lending_Script() { }

    function run() public {
        // Pause Lending Pools.
        bytes memory calldata_ =
            abi.encodeWithSignature("unpause(bool,bool,bool,bool,bool)", false, false, true, false, false);
        addToBatch(SAFE, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeWithSignature("unpause(bool,bool,bool,bool,bool)", false, false, true, false, false);
        addToBatch(SAFE, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeWithSignature("unpause(bool,bool,bool,bool,bool)", false, false, true, false, false);
        addToBatch(SAFE, address(lendingPoolWeth), calldata_);

        // Pause Registry.
        calldata_ = abi.encodeWithSignature("unpause(bool,bool)", false, false);
        addToBatch(SAFE, address(registry), calldata_);

        // Pause Factory.
        calldata_ = abi.encodeWithSignature("unpause(bool)", false);
        addToBatch(SAFE, address(factory), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
