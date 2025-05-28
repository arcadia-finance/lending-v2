/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Base_Lending_Script } from "./Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { AssetRiskParameters } from "./utils/constants/Base.sol";
import { AssetRiskParams } from "./utils/constants/Shared.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetRiskParameters is Base_Lending_Script {
    address SAFE = Safes.RISK_MANAGER;

    constructor() Base_Lending_Script() { }

    function run() public {
        // Set risk parameters.
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.AAVE_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.AAVE_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.AAVE_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.GHO_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.GHO_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.GHO_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.LBTC_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.MORPHO_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.MORPHO_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.MORPHO_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.WELL_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.WELL_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetRiskParameters.WELL_WETH()));

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setRiskParameters(AssetRiskParams memory params) internal view returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfPrimaryAsset,
            (params.creditor, params.asset, 0, params.maxExposure, params.collateralFactor, params.liquidationFactor)
        );
    }
}
