/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses } from "./Constants/DeployConstants.sol";

import { Factory } from "../lib/accounts-v2/src/Factory.sol";
import { Liquidator } from "../src/Liquidator.sol";

import { ERC20, DebtToken } from "../src/DebtToken.sol";
import { LendingPool, InterestRateModule } from "../src/LendingPool.sol";
import { Tranche } from "../src/Tranche.sol";
import { Creditor } from "../src/Creditor.sol";

contract ArcadiaLendingDeployment is Test {
    Factory public factory;
    ERC20 public weth;
    ERC20 public usdc;
    Liquidator public liquidator;

    LendingPool public pool_weth;
    Tranche public srTranche_weth;

    LendingPool public pool_usdc;
    Tranche public srTranche_usdc;

    constructor() {
        weth = ERC20(DeployAddresses.eth_base);
        usdc = ERC20(DeployAddresses.usdc_base);
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY_DEPLOYER_BASE");

        vm.startBroadcast(deployerPrivateKey);

        factory = new Factory();
        liquidator = new Liquidator();

        pool_weth =
        new LendingPool(vm.addr(deployerPrivateKey), ERC20(address(weth)), DeployAddresses.treasury_base, address(factory), address(liquidator));
        srTranche_weth = new Tranche(address(pool_weth), "Senior", "sr");

        pool_weth.setOriginationFee(10);
        pool_weth.setMaxLiquidationFees(3 * 10 ** 18, 3 * 10 ** 18);
        pool_weth.setFixedLiquidationCost(0.002 * 10 ** 18);
        pool_weth.addTranche(address(srTranche_weth), 85, 10);
        pool_weth.setTreasuryInterestWeight(15);
        pool_weth.setTreasuryLiquidationWeight(90);
        pool_weth.setSupplyCap(10_000 * 10 ** 18);
        pool_weth.setBorrowCap(1000 * 10 ** 18);
        pool_weth.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 15_000_000_000_000_000,
                lowSlopePerYear: 70_000_000_000_000_000,
                highSlopePerYear: 1_250_000_000_000_000_000,
                utilisationThreshold: 70_000
            })
        );
        pool_weth.changeGuardian(vm.addr(deployerPrivateKey));

        pool_usdc =
        new LendingPool(vm.addr(deployerPrivateKey), ERC20(address(usdc)), DeployAddresses.treasury_base, address(factory), address(liquidator));
        srTranche_usdc = new Tranche(address(pool_usdc), "Senior", "sr");

        pool_usdc.setOriginationFee(10);
        pool_usdc.setMaxLiquidationFees(5000 * 10 ** 6, 5000 * 10 ** 6);
        pool_usdc.setFixedLiquidationCost(2 * 10 ** 6);
        pool_usdc.addTranche(address(srTranche_usdc), 85, 10);
        pool_usdc.setTreasuryInterestWeight(15);
        pool_usdc.setTreasuryLiquidationWeight(90);
        pool_usdc.setSupplyCap(15_000_000 * 10 ** 6);
        pool_usdc.setBorrowCap(1_000_000 * 10 ** 6);
        pool_usdc.setInterestConfig(
            InterestRateModule.InterestRateConfiguration({
                baseRatePerYear: 10_000_000_000_000_000,
                lowSlopePerYear: 55_000_000_000_000_000,
                highSlopePerYear: 1_000_000_000_000_000_000,
                utilisationThreshold: 80_000
            })
        );
        pool_usdc.changeGuardian(vm.addr(deployerPrivateKey));

        vm.stopBroadcast();
    }
}
