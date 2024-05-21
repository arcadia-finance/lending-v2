/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";

import {
    ArcadiaContracts,
    ArcadiaSafes,
    ExternalContracts,
    PrimaryAssets
} from "../lib/accounts-v2/script/utils/Constants.sol";
import { ArcadiaLending, InterestRateParameters, LiquidationParameters, MinimumMargins } from "./utils/Constants.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { Tranche } from "../src/Tranche.sol";

contract ArcadiaLendingDeploymentStep2 is Test {
    LendingPool internal pool_usdc;
    LendingPool internal pool_weth;
    Tranche internal srTranche_usdc;
    Tranche internal srTranche_weth;
    Liquidator internal liquidator;

    constructor() {
        pool_usdc = LendingPool(ArcadiaContracts.LENDINGPOOL_USDC);
        pool_weth = LendingPool(ArcadiaContracts.LENDINGPOOL_WETH);
        srTranche_usdc = Tranche(ArcadiaLending.TRANCHE_USDC);
        srTranche_weth = Tranche(ArcadiaLending.TRANCHE_WETH);
        liquidator = Liquidator(ArcadiaLending.LIQUIDATOR);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = ArcadiaSafes.OWNER;
        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);
        pool_weth.setMinimumMargin(MinimumMargins.WETH);
        pool_weth.setLiquidationParameters(
            LiquidationParameters.INITIATION_WEIGHT_WETH,
            LiquidationParameters.PENALTY_WEIGHT_WETH,
            LiquidationParameters.TERMINATION_WEIGHT_WETH,
            LiquidationParameters.MIN_REWARD_WEIGHT_WETH,
            LiquidationParameters.MAX_REWARD_WETH
        );
        pool_weth.setInterestParameters(
            InterestRateParameters.BASE_RATE_WETH,
            InterestRateParameters.LOW_SLOPE_WETH,
            InterestRateParameters.HIGH_SLOPE_WETH,
            InterestRateParameters.UTILISATION_THRESHOLD_WETH
        );

        pool_usdc.setMinimumMargin(MinimumMargins.USDC);
        pool_usdc.setLiquidationParameters(
            LiquidationParameters.INITIATION_WEIGHT_USDC,
            LiquidationParameters.PENALTY_WEIGHT_USDC,
            LiquidationParameters.TERMINATION_WEIGHT_USDC,
            LiquidationParameters.MIN_REWARD_WEIGHT_USDC,
            LiquidationParameters.MAX_REWARD_USDC
        );
        pool_usdc.setInterestParameters(
            InterestRateParameters.BASE_RATE_USDC,
            InterestRateParameters.LOW_SLOPE_USDC,
            InterestRateParameters.HIGH_SLOPE_USDC,
            InterestRateParameters.UTILISATION_THRESHOLD_USDC
        );
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
        (,,, uint256 minimumMargin) = pool_weth.openMarginAccount(1);
        assertEq(minimumMargin, MinimumMargins.WETH);
        (,,, minimumMargin) = pool_usdc.openMarginAccount(1);
        assertEq(minimumMargin, MinimumMargins.USDC);

        (
            uint16 initiationWeight,
            uint16 penaltyWeight,
            uint16 terminationWeight,
            uint16 minRewardWeight,
            uint80 maxReward
        ) = pool_weth.getLiquidationParameters();
        assertEq(initiationWeight, LiquidationParameters.INITIATION_WEIGHT_WETH);
        assertEq(penaltyWeight, LiquidationParameters.PENALTY_WEIGHT_WETH);
        assertEq(terminationWeight, LiquidationParameters.TERMINATION_WEIGHT_WETH);
        assertEq(minRewardWeight, LiquidationParameters.MIN_REWARD_WEIGHT_WETH);
        assertEq(maxReward, LiquidationParameters.MAX_REWARD_WETH);

        (initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward) =
            pool_usdc.getLiquidationParameters();
        assertEq(initiationWeight, LiquidationParameters.INITIATION_WEIGHT_USDC);
        assertEq(penaltyWeight, LiquidationParameters.PENALTY_WEIGHT_USDC);
        assertEq(terminationWeight, LiquidationParameters.TERMINATION_WEIGHT_USDC);
        assertEq(minRewardWeight, LiquidationParameters.MIN_REWARD_WEIGHT_USDC);
        assertEq(maxReward, LiquidationParameters.MAX_REWARD_USDC);

        (uint72 baseRatePerYear, uint72 lowSlopePerYear, uint72 highSlopePerYear, uint16 utilisationThreshold) =
            pool_weth.getInterestRateConfig();
        assertEq(baseRatePerYear, InterestRateParameters.BASE_RATE_WETH);
        assertEq(lowSlopePerYear, InterestRateParameters.LOW_SLOPE_WETH);
        assertEq(highSlopePerYear, InterestRateParameters.HIGH_SLOPE_WETH);
        assertEq(utilisationThreshold, InterestRateParameters.UTILISATION_THRESHOLD_WETH);

        (baseRatePerYear, lowSlopePerYear, highSlopePerYear, utilisationThreshold) = pool_usdc.getInterestRateConfig();
        assertEq(baseRatePerYear, InterestRateParameters.BASE_RATE_USDC);
        assertEq(lowSlopePerYear, InterestRateParameters.LOW_SLOPE_USDC);
        assertEq(highSlopePerYear, InterestRateParameters.HIGH_SLOPE_USDC);
        assertEq(utilisationThreshold, InterestRateParameters.UTILISATION_THRESHOLD_USDC);
    }
}
