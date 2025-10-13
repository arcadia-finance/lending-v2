/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

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
import { Assets } from "../../../lib/accounts-v2/script/utils/constants/Unichain.sol";
import { AssetModules, EOAs, Safes } from "../../../lib/accounts-v2/script/utils/constants/Shared.sol";

/// forge-lint: disable-next-item(mixed-case-function)
library AssetModuleRiskParameters {
    // Aerodrome Pool Asset Module
    function AERO_POOL_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.AERO_POOL,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function AERO_POOL_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.AERO_POOL,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    // Default UniswapV4 Asset Module
    function DEFAULT_UNISWAPV4_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.DEFAULT_UNISWAPV4,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function DEFAULT_UNISWAPV4_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.DEFAULT_UNISWAPV4,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    // Slipstream Asset Module
    function SLIPSTREAM_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function SLIPSTREAM_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    // Staked Aerodrome Pool Asset Module
    function STAKED_AERO_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function STAKED_AERO_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    // Staked Slipstream Asset Module
    function STAKED_SLIPSTREAM_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function STAKED_SLIPSTREAM_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.STAKED_SLIPSTREAM,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
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
    function UNISWAPV3_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.UNISWAPV3,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function UNISWAPV3_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.UNISWAPV3,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    // Wrapped Aerodrome Pool Asset Module
    function WRAPPED_AERO_USDC() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.WRAPPED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }

    function WRAPPED_AERO_WETH() internal pure returns (AssetModuleRiskParams memory) {
        return AssetModuleRiskParams({
            assetModule: AssetModules.WRAPPED_AERO,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            riskFactor: 9800,
            maxExposure: uint112(1_000_000 * 1e18)
        });
    }
}

/// forge-lint: disable-next-item(mixed-case-function)
library AssetRiskParameters {
    // USDC
    function USDC_USDC() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_USDC,
            collateralFactor: 9325,
            liquidationFactor: 9750,
            maxExposure: uint112(1_000_000 * 10 ** Assets.USDC().decimals)
        });
    }

    function USDC_WETH() internal pure returns (AssetRiskParams memory) {
        return AssetRiskParams({
            asset: Assets.USDC().asset,
            creditor: ArcadiaLending.LENDINGPOOL_WETH,
            collateralFactor: 8850,
            liquidationFactor: 9475,
            maxExposure: uint112(1_000_000 * 10 ** Assets.USDC().decimals)
        });
    }

    // WETH
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
}

/// forge-lint: disable-next-item(mixed-case-function)
library InterestRateParameters {
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

/// forge-lint: disable-next-item(mixed-case-function)
library LendingPoolParameters {
    function CBBTC() internal pure returns (LendingPoolParams memory empty) { }

    function USDC() internal pure returns (LendingPoolParams memory) {
        return LendingPoolParams({
            lendingPool: ArcadiaLending.LENDINGPOOL_USDC,
            asset: Assets.USDC().asset,
            liquidationWeightTranche: 50,
            minimumMargin: 2 * 10 ** 6,
            originationFee: 0,
            guardian: Safes.GUARDIAN,
            riskManager: Safes.RISK_MANAGER,
            interestRateParameters: InterestRateParameters.USDC(),
            liquidationParameters: LiquidationParameters.USDC(),
            poolRiskParameters: PoolRisk.PARAMETERS(),
            treasury: Treasuries.TREASURY(),
            liquidator: LiquidatorParameters.LIQUIDATOR(),
            tranche: Tranches.USDC_SR()
        });
    }

    function WETH() internal pure returns (LendingPoolParams memory) {
        return LendingPoolParams({
            lendingPool: ArcadiaLending.LENDINGPOOL_WETH,
            asset: Assets.WETH().asset,
            liquidationWeightTranche: 50,
            minimumMargin: 0.002 * 10 ** 18,
            originationFee: 0,
            guardian: Safes.GUARDIAN,
            riskManager: Safes.RISK_MANAGER,
            interestRateParameters: InterestRateParameters.WETH(),
            liquidationParameters: LiquidationParameters.WETH(),
            poolRiskParameters: PoolRisk.PARAMETERS(),
            treasury: Treasuries.TREASURY(),
            liquidator: LiquidatorParameters.LIQUIDATOR(),
            tranche: Tranches.WETH_SR()
        });
    }
}

/// forge-lint: disable-next-item(mixed-case-function)
library LiquidationParameters {
    function USDC() internal pure returns (LiquidationParams memory) {
        return LiquidationParams({
            accountRecipient: EOAs.MANAGER,
            initiationWeight: 12,
            penaltyWeight: 200,
            terminationWeight: 12,
            minRewardWeight: 3500,
            maxReward: 4000 * 10 ** 6
        });
    }

    function WETH() internal pure returns (LiquidationParams memory) {
        return LiquidationParams({
            accountRecipient: EOAs.MANAGER,
            initiationWeight: 12,
            penaltyWeight: 200,
            terminationWeight: 12,
            minRewardWeight: 1500,
            maxReward: 1 * 10 ** 18
        });
    }
}

/// forge-lint: disable-next-item(mixed-case-function)
library Tranches {
    function USDC() internal pure returns (TrancheParams[] memory tranches) {
        tranches = new TrancheParams[](1);
        tranches[0] = USDC_SR();
    }

    function WETH() internal pure returns (TrancheParams[] memory tranches) {
        tranches = new TrancheParams[](1);
        tranches[0] = WETH_SR();
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

/// forge-lint: disable-next-item(mixed-case-function)
library Treasuries {
    function TREASURY() internal pure returns (Treasury memory) {
        return Treasury({ treasury: ArcadiaLending.SWEEPER, interestWeight: 15, liquidationWeight: 50 });
    }
}
