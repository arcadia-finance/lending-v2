/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Script } from "../Base.s.sol";
import { Safes } from "../../lib/accounts-v2/script/utils/constants/Base.sol";

contract AddAccountImplementationsStep4 is Base_Lending_Script {
    /// forge-lint: disable-next-line(mixed-case-variable)
    address internal SAFE = Safes.OWNER;

    function run() public {
        // Change the active Account versions.
        addToBatch(SAFE, address(lendingPoolCbbtc), abi.encodeCall(lendingPoolCbbtc.setAccountVersion, (1, false)));
        addToBatch(SAFE, address(lendingPoolCbbtc), abi.encodeCall(lendingPoolCbbtc.setAccountVersion, (3, true)));

        addToBatch(SAFE, address(lendingPoolUsdc), abi.encodeCall(lendingPoolUsdc.setAccountVersion, (1, false)));
        addToBatch(SAFE, address(lendingPoolUsdc), abi.encodeCall(lendingPoolUsdc.setAccountVersion, (3, true)));

        addToBatch(SAFE, address(lendingPoolWeth), abi.encodeCall(lendingPoolWeth.setAccountVersion, (1, false)));
        addToBatch(SAFE, address(lendingPoolWeth), abi.encodeCall(lendingPoolWeth.setAccountVersion, (3, true)));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }
}
