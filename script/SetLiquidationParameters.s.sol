/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";

import { ArcadiaSafes } from "../lib/accounts-v2/script/utils/Constants.sol";
import { LiquidationParameters } from "./utils/Constants.sol";

contract SetLiquidationParameters is Base_Lending_Script {
    constructor() Base_Lending_Script() { }

    function run() public {
        // Set liquidation parameters.
        bytes memory calldata_ = abi.encodeCall(
            lendingPoolCbbtc.setLiquidationParameters,
            (
                LiquidationParameters.INITIATION_WEIGHT_CBBTC,
                LiquidationParameters.PENALTY_WEIGHT_CBBTC,
                LiquidationParameters.TERMINATION_WEIGHT_CBBTC,
                LiquidationParameters.MIN_REWARD_WEIGHT_CBBTC,
                LiquidationParameters.MAX_REWARD_CBBTC
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolCbbtc), calldata_);

        calldata_ = abi.encodeCall(
            lendingPoolUsdc.setLiquidationParameters,
            (
                LiquidationParameters.INITIATION_WEIGHT_USDC,
                LiquidationParameters.PENALTY_WEIGHT_USDC,
                LiquidationParameters.TERMINATION_WEIGHT_USDC,
                LiquidationParameters.MIN_REWARD_WEIGHT_USDC,
                LiquidationParameters.MAX_REWARD_USDC
            )
        );
        addToBatch(ArcadiaSafes.OWNER, address(lendingPoolUsdc), calldata_);

        calldata_ = abi.encodeCall(
            lendingPoolWeth.setLiquidationParameters,
            (
                LiquidationParameters.INITIATION_WEIGHT_WETH,
                LiquidationParameters.PENALTY_WEIGHT_WETH,
                LiquidationParameters.TERMINATION_WEIGHT_WETH,
                LiquidationParameters.MIN_REWARD_WEIGHT_WETH,
                LiquidationParameters.MAX_REWARD_WETH
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
