/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

library ArcadiaLending {
    address internal constant LIQUIDATOR = 0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af;
    address internal constant LENDINGPOOL_CBBTC = 0xa37E9b4369dc20940009030BfbC2088F09645e3B;
    address internal constant LENDINGPOOL_USDC = 0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1;
    address internal constant LENDINGPOOL_WETH = 0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2;
    address internal constant SWEEPER = 0xD6aA7216dADd79120460ADc1C46959592063f07A;
    address internal constant TRANCHE_CBBTC = 0x9c63A4c499B323a25D389Da759c2ac1e385eEc92;
    address internal constant TRANCHE_USDC = 0xEFE32813dBA3A783059d50e5358b9e3661218daD;
    address internal constant TRANCHE_WETH = 0x393893caeB06B5C16728bb1E354b6c36942b1382;
    address internal constant WRAPPED_TRANCHE_CBBTC = 0x7Cc8013e784418dc9771403DD057f55cEb34Ba3A;
    address internal constant WRAPPED_TRANCHE_USDC = 0xbc10718571fcB3c3F67800e7C0887E450D2Ff398;
    address internal constant WRAPPED_TRANCHE_WETH = 0xD82BFa27D49e5a394ba371B293DaE65E9B7a8C60;
}

library LiquidatorParameters {
    function LIQUIDATOR() internal pure returns (LiquidatorParams memory) {
        return LiquidatorParams({
            liquidator: ArcadiaLending.LIQUIDATOR,
            halfLifeTime: 2400, // 40 minutes.
            cutoffTime: 14_400, // 4 hours.
            startPriceMultiplier: 16_000, // 160%. 1.6x
            minPriceMultiplier: 8000 // 80%. 0.8x
         });
    }
}

library PoolRisk {
    function PARAMETERS() internal pure returns (PoolRiskParams memory) {
        return PoolRiskParams({ minUsdValue: 1 * 1e18, gracePeriod: 15 minutes, maxRecursiveCalls: 6 });
    }
}

struct AssetRiskParams {
    address asset;
    address creditor;
    uint16 collateralFactor;
    uint16 liquidationFactor;
    uint112 maxExposure;
}

struct AssetModuleRiskParams {
    address assetModule;
    address creditor;
    uint16 riskFactor;
    uint112 maxExposure;
}

struct InterestRateParams {
    uint16 utilisationThreshold;
    uint72 baseRatePerYear;
    uint72 lowSlopePerYear;
    uint72 highSlopePerYear;
}

struct LendingPoolParams {
    address lendingPool;
    address asset;
    uint16 liquidationWeightTranche;
    uint96 minimumMargin;
    uint256 originationFee;
    InterestRateParams interestRateParameters;
    LiquidationParams liquidationParameters;
    PoolRiskParams poolRiskParameters;
    Treasury treasury;
    LiquidatorParams liquidator;
    TrancheParams tranche;
}

struct LiquidationParams {
    uint16 initiationWeight;
    uint16 penaltyWeight;
    uint16 terminationWeight;
    uint16 minRewardWeight;
    uint80 maxReward;
}

struct LiquidatorParams {
    address liquidator;
    uint32 halfLifeTime;
    uint32 cutoffTime;
    uint16 startPriceMultiplier;
    uint16 minPriceMultiplier;
}

struct PoolRiskParams {
    uint128 minUsdValue;
    uint64 gracePeriod;
    uint64 maxRecursiveCalls;
}

struct TrancheParams {
    address tranche;
    string prefix;
    string prefixSymbol;
    address wrapper;
    uint16 interestWeight;
    uint256 vas;
}

struct Treasury {
    address treasury;
    uint16 interestWeight;
    uint16 liquidationWeight;
}
