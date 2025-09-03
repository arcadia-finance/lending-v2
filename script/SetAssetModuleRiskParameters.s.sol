/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ArcadiaAccounts } from "../lib/accounts-v2/script/utils/constants/Shared.sol";
import { Base_Lending_Script } from "./Base.s.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { AssetModuleRiskParameters } from "./utils/constants/Base.sol";
import { AssetModuleRiskParams } from "./utils/constants/Shared.sol";
import { Safes } from "../lib/accounts-v2/script/utils/constants/Base.sol";

contract SetRiskParametersAM is Base_Lending_Script {
    address SAFE = Safes.RISK_MANAGER;

    constructor() { }

    function run() public {
        // Set risk parameters.
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.AERO_POOL_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.AERO_POOL_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.ALIEN_BASE_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.ALIEN_BASE_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.ALIEN_BASE_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.SLIPSTREAM_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.SLIPSTREAM_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.SLIPSTREAM_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.STAKED_AERO_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.STAKED_AERO_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.STAKED_SLIPSTREAM_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.STAKED_SLIPSTREAM_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.STAKED_SLIPSTREAM_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.UNISWAPV3_CBBTC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.UNISWAPV3_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.UNISWAPV3_WETH()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.WRAPPED_AERO_USDC()));
        addToBatch(SAFE, address(registry), setRiskParameters(AssetModuleRiskParameters.WRAPPED_AERO_WETH()));

        addToBatch(
            SAFE,
            ArcadiaAccounts.UNISWAPV4_HOOKS_REGISTRY,
            setRiskParameters(AssetModuleRiskParameters.DEFAULT_UNISWAPV4_CBBTC())
        );
        addToBatch(
            SAFE,
            ArcadiaAccounts.UNISWAPV4_HOOKS_REGISTRY,
            setRiskParameters(AssetModuleRiskParameters.DEFAULT_UNISWAPV4_USDC())
        );
        addToBatch(
            SAFE,
            ArcadiaAccounts.UNISWAPV4_HOOKS_REGISTRY,
            setRiskParameters(AssetModuleRiskParameters.DEFAULT_UNISWAPV4_WETH())
        );

        // Create and write away batched transaction data to be signed with Safe.
        bytes memory data = createBatchedData(SAFE);
        vm.writeLine(PATH, vm.toString(data));
    }

    function setRiskParameters(AssetModuleRiskParams memory params) internal view returns (bytes memory calldata_) {
        calldata_ = abi.encodeCall(
            registry.setRiskParametersOfDerivedAM,
            (params.creditor, params.assetModule, params.maxExposure, params.riskFactor)
        );
    }
}
