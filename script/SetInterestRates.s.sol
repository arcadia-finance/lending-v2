/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { ArcadiaSafes } from "../lib/accounts-v2/script/utils/ConstantsBase.sol";
import { InterestRateParameters } from "./utils/ConstantsBase.sol";

contract SetInterestRates is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        // Set interest rates.
        bytes memory calldata_ = abi.encodeCall(
            lendingPoolCbbtc.setInterestParameters,
            (
                InterestRateParameters.BASE_RATE_CBBTC,
                InterestRateParameters.LOW_SLOPE_CBBTC,
                InterestRateParameters.HIGH_SLOPE_CBBTC,
                InterestRateParameters.UTILISATION_THRESHOLD_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(
            lendingPoolUsdc.setInterestParameters,
            (
                InterestRateParameters.BASE_RATE_USDC,
                InterestRateParameters.LOW_SLOPE_USDC,
                InterestRateParameters.HIGH_SLOPE_USDC,
                InterestRateParameters.UTILISATION_THRESHOLD_USDC
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(
            lendingPoolWeth.setInterestParameters,
            (
                InterestRateParameters.BASE_RATE_WETH,
                InterestRateParameters.LOW_SLOPE_WETH,
                InterestRateParameters.HIGH_SLOPE_WETH,
                InterestRateParameters.UTILISATION_THRESHOLD_WETH
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolWeth), calldata_);

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(ArcadiaSafes.OWNER);
        vm.writeLine(PATH, vm.toString(data));
    }

    function test_deploy() public {
        vm.skip(true);
    }
}
