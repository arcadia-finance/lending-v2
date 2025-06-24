/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import {
    ArcadiaLending,
    AssetModuleRiskParams,
    AssetRiskParams,
    InterestRateParams,
    LendingPoolParams,
    LiquidationParams,
    LiquidatorParameters,
    PoolRisk,
    TrancheParams,
    Treasury
} from "./Shared.sol";
import { Assets, Safes } from "../../../lib/accounts-v2/script/utils/constants/Base.sol";
import { AssetModules } from "../../../lib/accounts-v2/script/utils/constants/Shared.sol";

library AssetModuleRiskParameters {
    // Aerodrome Pool Asset Module
    function AERO_POOL_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.AERO_POOL,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function AERO_POOL_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.AERO_POOL,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    // Alien Base Asset Module
    function ALIEN_BASE_CBBTC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.ALIEN_BASE,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function ALIEN_BASE_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.ALIEN_BASE,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function ALIEN_BASE_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.ALIEN_BASE,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    // Default UniswapV4 Asset Module
    function DEFAULT_UNISWAPV4_CBBTC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.DEFAULT_UNISWAPV4,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            riskFactor: 9800,
            maxExposure: uint112(5_000_000 * 1e18)
        });
    }

    function DEFAULT_UNISWAPV4_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.DEFAULT_UNISWAPV4,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(5_000_000 * 1e18)
        });
    }

    function DEFAULT_UNISWAPV4_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.DEFAULT_UNISWAPV4,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(5_000_000 * 1e18)
        });
    }

    // Slipstream Asset Module
    function SLIPSTREAM_CBBTC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            riskFactor: 9800,
            maxExposure: uint112(10_000_000 * 1e18)
        });
    }

    function SLIPSTREAM_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(10_000_000 * 1e18)
        });
    }

    function SLIPSTREAM_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(10_000_000 * 1e18)
        });
    }

    // Staked Aerodrome Pool Asset Module
    function STAKED_AERO_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function STAKED_AERO_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    // Staked Slipstream Asset Module
    function STAKED_SLIPSTREAM_CBBTC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            riskFactor: 9800,
            maxExposure: uint112(10_000_000 * 1e18)
        });
    }

    function STAKED_SLIPSTREAM_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(15_000_000 * 1e18)
        });
    }

    function STAKED_SLIPSTREAM_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(10_000_000 * 1e18)
        });
    }

    // Staked Stargate Asset Module
    function STAKED_STARGATE_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_STARGATE,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: 0
        });
    }

    function STAKED_STARGATE_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_STARGATE,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: 0
        });
    }

    // Stargate Asset Module
    function STARGATE_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STARGATE,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9700,
            maxExposure: 0
        });
    }

    function STARGATE_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STARGATE,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9700,
            maxExposure: 0
        });
    }

    // Uniswap V3 Asset Module
    function UNISWAPV3_CBBTC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.UNISWAPV3,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function UNISWAPV3_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.UNISWAPV3,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function UNISWAPV3_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.UNISWAPV3,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    // Wrapped Aerodrome Pool Asset Module
    function WRAPPED_AERO_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.WRAPPED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }

    function WRAPPED_AERO_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.WRAPPED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(2_000_000 * 1e18)
        });
    }
}

library AssetRiskParameters {
    // AAVE
    function AAVE_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AAVE().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6800,
            liquidationFactor: 7800,
            maxExposure: uint112(3600 * 10 ** Assets.AAVE().decimals)
        });
    }

    function AAVE_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AAVE().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 6400,
            liquidationFactor: 7800,
            maxExposure: uint112(4200 * 10 ** Assets.AAVE().decimals)
        });
    }

    function AAVE_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AAVE().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 7000,
            liquidationFactor: 7800,
            maxExposure: uint112(5500 * 10 ** Assets.AAVE().decimals)
        });
    }

    // AERO
    function AERO_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AERO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 7200,
            liquidationFactor: 8625,
            maxExposure: uint112(3e6 * 10 ** Assets.AERO().decimals)
        });
    }

    function AERO_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AERO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7100,
            liquidationFactor: 8500,
            maxExposure: uint112(3e6 * 10 ** Assets.AERO().decimals)
        });
    }

    function AERO_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.AERO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 7700,
            liquidationFactor: 8950,
            maxExposure: uint112(3e6 * 10 ** Assets.AERO().decimals)
        });
    }

    // cbBTC
    function CBBTC_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.CBBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 9225,
            liquidationFactor: 9750,
            maxExposure: uint112(50 * 10 ** Assets.CBBTC().decimals)
        });
    }

    function CBBTC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.CBBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7200,
            liquidationFactor: 8750,
            maxExposure: uint112(20 * 10 ** Assets.CBBTC().decimals)
        });
    }

    function CBBTC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.CBBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8500,
            liquidationFactor: 9600,
            maxExposure: uint112(20 * 10 ** Assets.CBBTC().decimals)
        });
    }

    // cbETH
    function CBETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.CBETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8500,
            liquidationFactor: 9300,
            maxExposure: uint112(300 * 10 ** Assets.CBETH().decimals)
        });
    }

    function CBETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.CBETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(400 * 10 ** Assets.CBETH().decimals)
        });
    }

    // COMP
    function COMP_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.COMP().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 6500,
            liquidationFactor: 7200,
            maxExposure: 0
        });
    }

    function COMP_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.COMP().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 7000,
            liquidationFactor: 7700,
            maxExposure: 0
        });
    }

    // DAI
    function DAI_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.DAI().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8300,
            liquidationFactor: 8700,
            maxExposure: uint112(200 * 10 ** Assets.DAI().decimals)
        });
    }

    function DAI_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.DAI().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 0,
            liquidationFactor: 0,
            maxExposure: 0
        });
    }

    // DEGEN
    function DEGEN_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.DEGEN().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 6000,
            liquidationFactor: 7800,
            maxExposure: uint112(75_000_000 * 10 ** Assets.DEGEN().decimals)
        });
    }

    function DEGEN_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.DEGEN().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 6400,
            liquidationFactor: 8000,
            maxExposure: uint112(75_000_000 * 10 ** Assets.DEGEN().decimals)
        });
    }

    // EURC
    function EURC_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.EURC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 8200,
            liquidationFactor: 9250,
            maxExposure: uint112(1_000_000 * 10 ** Assets.EURC().decimals)
        });
    }

    function EURC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.EURC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8950,
            liquidationFactor: 9675,
            maxExposure: uint112(3_000_000 * 10 ** Assets.EURC().decimals)
        });
    }

    function EURC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.EURC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8750,
            liquidationFactor: 9475,
            maxExposure: uint112(2_000_000 * 10 ** Assets.EURC().decimals)
        });
    }

    // EZETH
    function EZETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.EZETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7800,
            liquidationFactor: 8700,
            maxExposure: uint112(175 * 10 ** Assets.EZETH().decimals)
        });
    }

    function EZETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.EZETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8800,
            liquidationFactor: 9600,
            maxExposure: uint112(250 * 10 ** Assets.EZETH().decimals)
        });
    }

    // GHO
    function GHO_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.GHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6800,
            liquidationFactor: 8525,
            maxExposure: uint112(0 * 10 ** Assets.GHO().decimals)
        });
    }

    function GHO_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.GHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9000,
            liquidationFactor: 9500,
            maxExposure: uint112(0 * 10 ** Assets.GHO().decimals)
        });
    }

    function GHO_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.GHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8550,
            liquidationFactor: 9225,
            maxExposure: uint112(0 * 10 ** Assets.GHO().decimals)
        });
    }

    // LBTC
    function LBTC_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.LBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 8625,
            liquidationFactor: 9675,
            maxExposure: uint112(5 * 10 ** Assets.LBTC().decimals)
        });
    }

    function LBTC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.LBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7200,
            liquidationFactor: 8750,
            maxExposure: uint112(2 * 10 ** Assets.LBTC().decimals)
        });
    }

    function LBTC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.LBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8500,
            liquidationFactor: 9600,
            maxExposure: uint112(2 * 10 ** Assets.LBTC().decimals)
        });
    }

    // MORPHO
    function MORPHO_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.MORPHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6400,
            liquidationFactor: 7800,
            maxExposure: uint112(70_000 * 10 ** Assets.MORPHO().decimals)
        });
    }

    function MORPHO_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.MORPHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 6500,
            liquidationFactor: 7800,
            maxExposure: uint112(75_000 * 10 ** Assets.MORPHO().decimals)
        });
    }

    function MORPHO_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.MORPHO().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 6500,
            liquidationFactor: 7800,
            maxExposure: uint112(140_000 * 10 ** Assets.MORPHO().decimals)
        });
    }

    // RDNT
    function RDNT_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.RDNT().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 0,
            liquidationFactor: 7500,
            maxExposure: 0
        });
    }

    function RDNT_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.RDNT().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 0,
            liquidationFactor: 7500,
            maxExposure: 0
        });
    }

    // RETH
    function RETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.RETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8350,
            liquidationFactor: 9200,
            maxExposure: uint112(200 * 10 ** Assets.RETH().decimals)
        });
    }

    function RETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.RETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8900,
            liquidationFactor: 9650,
            maxExposure: uint112(210 * 10 ** Assets.RETH().decimals)
        });
    }

    // STG
    function STG_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.STG().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 5500,
            liquidationFactor: 7000,
            maxExposure: 1
        });
    }

    function STG_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.STG().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 6000,
            liquidationFactor: 7200,
            maxExposure: 1
        });
    }

    // TBTC
    function TBTC_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.TBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 8625,
            liquidationFactor: 9675,
            maxExposure: uint112(15 * 10 ** Assets.TBTC().decimals)
        });
    }

    function TBTC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.TBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7200,
            liquidationFactor: 8750,
            maxExposure: uint112(8 * 10 ** Assets.TBTC().decimals)
        });
    }

    function TBTC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.TBTC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8500,
            liquidationFactor: 9600,
            maxExposure: uint112(10 * 10 ** Assets.TBTC().decimals)
        });
    }

    // TRUMP
    function TRUMP_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.TRUMP().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 5650,
            liquidationFactor: 7200,
            maxExposure: uint112(4000 * 10 ** Assets.TRUMP().decimals)
        });
    }

    function TRUMP_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.TRUMP().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 5650,
            liquidationFactor: 7200,
            maxExposure: uint112(3500 * 10 ** Assets.TRUMP().decimals)
        });
    }

    // USDBC
    function USDBC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDBC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9250,
            liquidationFactor: 9675,
            maxExposure: uint112(1_000_000 * 10 ** Assets.USDBC().decimals)
        });
    }

    function USDBC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDBC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8850,
            liquidationFactor: 9475,
            maxExposure: uint112(750_000 * 10 ** Assets.USDBC().decimals)
        });
    }

    // USDC
    function USDC_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 7200,
            liquidationFactor: 8750,
            maxExposure: uint112(10_000_000 * 10 ** Assets.USDC().decimals)
        });
    }

    function USDC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(10_000_000 * 10 ** Assets.USDC().decimals)
        });
    }

    function USDC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8850,
            liquidationFactor: 9475,
            maxExposure: uint112(10_000_000 * 10 ** Assets.USDC().decimals)
        });
    }

    // USDS
    function USDS_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDS().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 7200,
            liquidationFactor: 8750,
            maxExposure: uint112(0 * 10 ** Assets.USDS().decimals)
        });
    }

    function USDS_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDS().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9200,
            liquidationFactor: 9659,
            maxExposure: uint112(3_000_000 * 10 ** Assets.USDS().decimals)
        });
    }

    function USDS_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDS().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8800,
            liquidationFactor: 9450,
            maxExposure: uint112(3_000_000 * 10 ** Assets.USDS().decimals)
        });
    }

    // USDT
    function USDT_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDT().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(1_000_000 * 10 ** Assets.USDT().decimals)
        });
    }

    function USDT_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDT().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8850,
            liquidationFactor: 9475,
            maxExposure: uint112(800_000 * 10 ** Assets.USDT().decimals)
        });
    }

    // USDZ
    function USDZ_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDZ().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6800,
            liquidationFactor: 8525,
            maxExposure: uint112(0 * 10 ** Assets.USDZ().decimals)
        });
    }

    function USDZ_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDZ().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9000,
            liquidationFactor: 9500,
            maxExposure: uint112(0 * 10 ** Assets.USDZ().decimals)
        });
    }

    function USDZ_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDZ().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8550,
            liquidationFactor: 9225,
            maxExposure: uint112(0 * 10 ** Assets.USDZ().decimals)
        });
    }

    // VIRTUAL
    function VIRTUAL_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VIRTUAL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6900,
            liquidationFactor: 8000,
            maxExposure: uint112(250_000 * 10 ** Assets.VIRTUAL().decimals)
        });
    }

    function VIRTUAL_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VIRTUAL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 6600,
            liquidationFactor: 7800,
            maxExposure: uint112(350_000 * 10 ** Assets.VIRTUAL().decimals)
        });
    }

    function VIRTUAL_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VIRTUAL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 7200,
            liquidationFactor: 8000,
            maxExposure: uint112(350_000 * 10 ** Assets.VIRTUAL().decimals)
        });
    }

    // VVV
    function VVV_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VVV().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 5700,
            liquidationFactor: 7500,
            maxExposure: uint112(140_000 * 10 ** Assets.VVV().decimals)
        });
    }

    function VVV_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VVV().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 5200,
            liquidationFactor: 7000,
            maxExposure: uint112(180_000 * 10 ** Assets.VVV().decimals)
        });
    }

    function VVV_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.VVV().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 6200,
            liquidationFactor: 8000,
            maxExposure: uint112(200_000 * 10 ** Assets.VVV().decimals)
        });
    }

    // WEETH
    function WEETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WEETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8000,
            liquidationFactor: 8800,
            maxExposure: uint112(400 * 10 ** Assets.WEETH().decimals)
        });
    }

    function WEETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WEETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 9125,
            liquidationFactor: 9750,
            maxExposure: uint112(500 * 10 ** Assets.WEETH().decimals)
        });
    }

    // WELL
    function WELL_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WELL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 6800,
            liquidationFactor: 7800,
            maxExposure: uint112(13_000_000 * 10 ** Assets.WELL().decimals)
        });
    }

    function WELL_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WELL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 7000,
            liquidationFactor: 8000,
            maxExposure: uint112(15_000_000 * 10 ** Assets.WELL().decimals)
        });
    }

    function WELL_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WELL().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 6900,
            liquidationFactor: 8000,
            maxExposure: uint112(14_000_000 * 10 ** Assets.WELL().decimals)
        });
    }

    // WETH
    function WETH_CBBTC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_CBBTC,
            collateralFactor: 8500,
            liquidationFactor: 9600,
            maxExposure: uint112(650 * 10 ** Assets.WETH().decimals)
        });
    }

    function WETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8850,
            liquidationFactor: 9475,
            maxExposure: uint112(2850 * 10 ** Assets.WETH().decimals)
        });
    }

    function WETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(2850 * 10 ** Assets.WETH().decimals)
        });
    }

    // wrsETH
    function WRSETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WRSETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8275,
            liquidationFactor: 9100,
            maxExposure: uint112(280 * 10 ** Assets.WRSETH().decimals)
        });
    }

    function WRSETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WRSETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8875,
            liquidationFactor: 9550,
            maxExposure: uint112(200 * 10 ** Assets.WRSETH().decimals)
        });
    }

    // wstETH
    function WSTETH_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WSTETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 8500,
            liquidationFactor: 9300,
            maxExposure: uint112(300 * 10 ** Assets.WSTETH().decimals)
        });
    }

    function WSTETH_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.WSTETH().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(400 * 10 ** Assets.WSTETH().decimals)
        });
    }
}

library InterestRateParameters {
    function CBBTC() internal pure returns (InterestRateParams memory) {
        return InterestRateParams({
            utilisationThreshold: 8000, // 80%
            baseRatePerYear: 3 * 1e16, // 3%
            lowSlopePerYear: 0 * 1e16, // -> Interest rate goes from 3% to 3% for utilisation of 0 to 80%
            highSlopePerYear: 200 * 1e16 // -> Interest rate goes from 3% to 43% for utilisation of 80 to 100%
         });
    }

    function USDC() internal pure returns (InterestRateParams memory) {
        return InterestRateParams({
            utilisationThreshold: 8000, // 80%
            baseRatePerYear: 8 * 1e16, // 8%
            lowSlopePerYear: 0 * 1e16, // -> Interest rate goes from 8% to 8% for utilisation of 0 to 80%
            highSlopePerYear: 200 * 1e16 // -> Interest rate goes from 8% to 48% for utilisation of 80 to 100%
         });
    }

    function WETH() internal pure returns (InterestRateParams memory) {
        return InterestRateParams({
            utilisationThreshold: 8000, // 80%
            baseRatePerYear: 6 * 1e16, // 6%
            lowSlopePerYear: 0 * 1e16, // -> Interest rate goes from 6% to 6% for utilisation of 0 to 80%
            highSlopePerYear: 200 * 1e16 // -> Interest rate goes from 6% to 46% for utilisation of 80 to 100%
         });
    }
}

library LendingPoolParameters {
    function CBBTC() internal pure returns (LendingPoolParams memory) {
        return LendingPoolParams({
            lendingPool: ArcadiaLending.LENDINGPOOL_CBBTC,
            asset: Assets.CBBTC().asset,
            liquidationWeightTranche: 50,
            minimumMargin: 0.00004 * 10 ** 8,
            originationFee: 0,
            interestRateParameters: InterestRateParameters.CBBTC(),
            liquidationParameters: LiquidationParameters.CBBTC(),
            poolRiskParameters: PoolRisk.PARAMETERS(),
            treasury: Treasuries.TREASURY(),
            liquidator: LiquidatorParameters.LIQUIDATOR(),
            tranche: TrancheParameters.CBBTC_SR()
        });
    }

    function USDC() internal pure returns (LendingPoolParams memory) {
        return LendingPoolParams({
            lendingPool: ArcadiaLending.LENDINGPOOL_USDC,
            asset: Assets.USDC().asset,
            liquidationWeightTranche: 50,
            minimumMargin: 2 * 10 ** 6,
            originationFee: 0,
            interestRateParameters: InterestRateParameters.USDC(),
            liquidationParameters: LiquidationParameters.USDC(),
            poolRiskParameters: PoolRisk.PARAMETERS(),
            treasury: Treasuries.TREASURY(),
            liquidator: LiquidatorParameters.LIQUIDATOR(),
            tranche: TrancheParameters.USDC_SR()
        });
    }

    function WETH() internal pure returns (LendingPoolParams memory) {
        return LendingPoolParams({
            lendingPool: ArcadiaLending.LENDINGPOOL_WETH,
            asset: Assets.WETH().asset,
            liquidationWeightTranche: 50,
            minimumMargin: 0.002 * 10 ** 18,
            originationFee: 0,
            interestRateParameters: InterestRateParameters.WETH(),
            liquidationParameters: LiquidationParameters.WETH(),
            poolRiskParameters: PoolRisk.PARAMETERS(),
            treasury: Treasuries.TREASURY(),
            liquidator: LiquidatorParameters.LIQUIDATOR(),
            tranche: TrancheParameters.WETH_SR()
        });
    }
}

library LiquidationParameters {
    function CBBTC() internal pure returns (LiquidationParams memory) {
        return LiquidationParams({
            initiationWeight: 12,
            penaltyWeight: 200,
            terminationWeight: 12,
            minRewardWeight: 2500,
            maxReward: 0.001 * 10 ** 8
        });
    }

    function USDC() internal pure returns (LiquidationParams memory) {
        return LiquidationParams({
            initiationWeight: 12,
            penaltyWeight: 200,
            terminationWeight: 12,
            minRewardWeight: 3500,
            maxReward: 4000 * 10 ** 6
        });
    }

    function WETH() internal pure returns (LiquidationParams memory) {
        return LiquidationParams({
            initiationWeight: 12,
            penaltyWeight: 200,
            terminationWeight: 12,
            minRewardWeight: 1500,
            maxReward: 1 * 10 ** 18
        });
    }
}

library TrancheParameters {
    function CBBTC() internal pure returns (TrancheParams[] memory tranches) {
        tranches = new TrancheParams[](1);
        tranches[0] = CBBTC_SR();
    }

    function USDC() internal pure returns (TrancheParams[] memory tranches) {
        tranches = new TrancheParams[](1);
        tranches[0] = USDC_SR();
    }

    function WETH() internal pure returns (TrancheParams[] memory tranches) {
        tranches = new TrancheParams[](1);
        tranches[0] = WETH_SR();
    }

    function CBBTC_SR() internal pure returns (TrancheParams memory) {
        return TrancheParams({
            tranche: ArcadiaLending.TRANCHE_CBBTC,
            prefix: "Senior",
            prefixSymbol: "sr",
            wrapper: ArcadiaLending.WRAPPED_TRANCHE_CBBTC,
            interestWeight: 85,
            vas: 100
        });
    }

    function USDC_SR() internal pure returns (TrancheParams memory) {
        return TrancheParams({
            tranche: ArcadiaLending.TRANCHE_USDC,
            prefix: "Senior",
            prefixSymbol: "sr",
            wrapper: ArcadiaLending.WRAPPED_TRANCHE_USDC,
            interestWeight: 85,
            vas: 10 ** 6
        });
    }

    function WETH_SR() internal pure returns (TrancheParams memory) {
        return TrancheParams({
            tranche: ArcadiaLending.TRANCHE_WETH,
            prefix: "Senior",
            prefixSymbol: "sr",
            wrapper: ArcadiaLending.WRAPPED_TRANCHE_WETH,
            interestWeight: 85,
            vas: 10 ** 8
        });
    }
}

library Treasuries {
    address constant SWEEPER = 0xD6aA7216dADd79120460ADc1C46959592063f07A;

    function TREASURY() internal pure returns (Treasury memory) {
        return Treasury({ treasury: SWEEPER, interestWeight: 15, liquidationWeight: 50 });
    }
}
