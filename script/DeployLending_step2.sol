/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses, DeployPoolSettings } from "./Constants/DeployConstants.sol";

import { LendingPool } from "../src/LendingPool.sol";
import { Tranche } from "../src/Tranche.sol";
import { Liquidator } from "../src/Liquidator.sol";

contract ArcadiaLendingDeployment is Test {
    LendingPool internal pool_usdc;
    LendingPool internal pool_weth;
    Tranche internal srTranche_usdc;
    Tranche internal srTranche_weth;
    Liquidator internal liquidator;

    constructor() {
        pool_usdc = LendingPool(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
        pool_weth = LendingPool(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
        srTranche_usdc = Tranche(0xEFE32813dBA3A783059d50e5358b9e3661218daD);
        srTranche_weth = Tranche(0x393893caeB06B5C16728bb1E354b6c36942b1382);
        liquidator = Liquidator(0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;
        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);
        pool_weth.setMinimumMargin(DeployPoolSettings.minimumMargin_eth);
        pool_weth.setLiquidationParameters(
            DeployPoolSettings.initiationWeight_eth,
            DeployPoolSettings.penaltyWeight_eth,
            DeployPoolSettings.terminationWeight_eth,
            DeployPoolSettings.minRewardWeight_eth,
            DeployPoolSettings.maxReward_eth
        );
        pool_weth.setInterestParameters(
            DeployPoolSettings.baseRatePerYear_eth,
            DeployPoolSettings.lowSlopePerYear_eth,
            DeployPoolSettings.highSlopePerYear_eth,
            DeployPoolSettings.utilisationThreshold_eth
        );

        pool_usdc.setMinimumMargin(DeployPoolSettings.minimumMargin_usdc);
        pool_usdc.setLiquidationParameters(
            DeployPoolSettings.initiationWeight_usdc,
            DeployPoolSettings.penaltyWeight_usdc,
            DeployPoolSettings.terminationWeight_usdc,
            DeployPoolSettings.minRewardWeight_usdc,
            DeployPoolSettings.maxReward_usdc
        );
        pool_usdc.setInterestParameters(
            DeployPoolSettings.baseRatePerYear_usdc,
            DeployPoolSettings.lowSlopePerYear_usdc,
            DeployPoolSettings.highSlopePerYear_usdc,
            DeployPoolSettings.utilisationThreshold_usdc
        );
        vm.stopBroadcast();
    }

    function test_deploy() public {
        vm.skip(true);
        (,,, uint256 minimumMargin) = pool_weth.openMarginAccount(1);
        assertEq(minimumMargin, DeployPoolSettings.minimumMargin_eth);
        (,,, minimumMargin) = pool_usdc.openMarginAccount(1);
        assertEq(minimumMargin, DeployPoolSettings.minimumMargin_usdc);

        (
            uint16 initiationWeight,
            uint16 penaltyWeight,
            uint16 terminationWeight,
            uint16 minRewardWeight,
            uint80 maxReward
        ) = pool_weth.getLiquidationParameters();
        assertEq(initiationWeight, DeployPoolSettings.initiationWeight_eth);
        assertEq(penaltyWeight, DeployPoolSettings.penaltyWeight_eth);
        assertEq(terminationWeight, DeployPoolSettings.terminationWeight_eth);
        assertEq(minRewardWeight, DeployPoolSettings.minRewardWeight_eth);
        assertEq(maxReward, DeployPoolSettings.maxReward_eth);

        (initiationWeight, penaltyWeight, terminationWeight, minRewardWeight, maxReward) =
            pool_usdc.getLiquidationParameters();
        assertEq(initiationWeight, DeployPoolSettings.initiationWeight_usdc);
        assertEq(penaltyWeight, DeployPoolSettings.penaltyWeight_usdc);
        assertEq(terminationWeight, DeployPoolSettings.terminationWeight_usdc);
        assertEq(minRewardWeight, DeployPoolSettings.minRewardWeight_usdc);
        assertEq(maxReward, DeployPoolSettings.maxReward_usdc);

        (uint72 baseRatePerYear, uint72 lowSlopePerYear, uint72 highSlopePerYear, uint16 utilisationThreshold) =
            pool_weth.getInterestRateConfig();
        assertEq(baseRatePerYear, DeployPoolSettings.baseRatePerYear_eth);
        assertEq(lowSlopePerYear, DeployPoolSettings.lowSlopePerYear_eth);
        assertEq(highSlopePerYear, DeployPoolSettings.highSlopePerYear_eth);
        assertEq(utilisationThreshold, DeployPoolSettings.utilisationThreshold_eth);

        (baseRatePerYear, lowSlopePerYear, highSlopePerYear, utilisationThreshold) = pool_usdc.getInterestRateConfig();
        assertEq(baseRatePerYear, DeployPoolSettings.baseRatePerYear_usdc);
        assertEq(lowSlopePerYear, DeployPoolSettings.lowSlopePerYear_usdc);
        assertEq(highSlopePerYear, DeployPoolSettings.highSlopePerYear_usdc);
        assertEq(utilisationThreshold, DeployPoolSettings.utilisationThreshold_usdc);
    }
}
