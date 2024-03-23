/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library DeployAddresses {
    address public constant eth_base = 0x4200000000000000000000000000000000000006;
    address public constant usdc_base = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    address public constant protocolOwner_base = 0x0f518becFC14125F23b8422849f6393D59627ddB;
    address public constant treasury_base = 0xBED53dA1718aDD7E31f42a138231c7783829A3f4; //todo: change for gnosis

    address public constant sequencerUptimeOracle_base = 0xBCF85224fc0756B9Fa45aA7892530B47e10b6433;
}

library DeployPoolSettings {
    uint96 public constant minimumMargin_eth = 0.002 * 10 ** 18;
    uint96 public constant minimumMargin_usdc = 2 * 10 ** 6;

    uint16 public constant initiationWeight_eth = 100;
    uint16 public constant penaltyWeight_eth = 500;
    uint16 public constant terminationWeight_eth = 50;
    uint16 public constant minRewardWeight_eth = 2500;
    uint80 public constant maxReward_eth = 1 * 10 ** 18;

    uint16 public constant initiationWeight_usdc = 100;
    uint16 public constant penaltyWeight_usdc = 500;
    uint16 public constant terminationWeight_usdc = 50;
    uint16 public constant minRewardWeight_usdc = 2500;
    uint80 public constant maxReward_usdc = 4000 * 10 ** 6;

    uint72 public constant baseRatePerYear_eth = 15_000_000_000_000_000;
    uint72 public constant lowSlopePerYear_eth = 70_000_000_000_000_000;
    uint72 public constant highSlopePerYear_eth = 1_250_000_000_000_000_000;
    uint16 public constant utilisationThreshold_eth = 7000;

    uint72 public constant baseRatePerYear_usdc = 10_000_000_000_000_000;
    uint72 public constant lowSlopePerYear_usdc = 55_000_000_000_000_000;
    uint72 public constant highSlopePerYear_usdc = 1_000_000_000_000_000_000;
    uint16 public constant utilisationThreshold_usdc = 8000;
}
