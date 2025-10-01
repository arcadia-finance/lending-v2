/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { Base_Lending_Script } from "./Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { LendingPoolParams } from "./utils/constants/Shared.sol";
import { LendingPoolParameters } from "./utils/constants/Base.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetInterestRates is Base_Lending_Script {
    constructor() { }

    function run() public {
        // Set interest rates.
        addToBatch(Safes.OWNER, address(lendingPoolCbbtc), setInterestParameters(LendingPoolParameters.CBBTC()));
        addToBatch(Safes.OWNER, address(lendingPoolUsdc), setInterestParameters(LendingPoolParameters.USDC()));
        addToBatch(Safes.OWNER, address(lendingPoolWeth), setInterestParameters(LendingPoolParameters.WETH()));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(Safes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setInterestParameters(LendingPoolParams memory pool_) internal pure returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            LendingPool.setInterestParameters,
            (
                pool_.interestRateParameters.baseRatePerYear,
                pool_.interestRateParameters.lowSlopePerYear,
                pool_.interestRateParameters.highSlopePerYear,
                pool_.interestRateParameters.utilisationThreshold
            )
        );
    }
}
