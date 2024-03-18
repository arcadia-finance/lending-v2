/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";
import { DeployAddresses } from "./Constants/DeployConstants.sol";

import { Factory } from "../lib/accounts-v2/src/Factory.sol";
import { Liquidator } from "../src/Liquidator.sol";

import { ERC20 } from "../src/DebtToken.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Tranche } from "../src/Tranche.sol";

contract ArcadiaLendingDeploymentStep1 is Test {
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
        address deployerAddress = vm.addr(deployerPrivateKey);
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        assertEq(deployerAddress, protocolOwnerAddress);

        vm.startBroadcast(deployerPrivateKey);

        factory = new Factory();
        liquidator = new Liquidator(address(factory), DeployAddresses.sequencerUptimeOracle_base);

        pool_weth = new LendingPool(
            protocolOwnerAddress, ERC20(address(weth)), protocolOwnerAddress, address(factory), address(liquidator)
        );
        srTranche_weth = new Tranche(address(pool_weth), 10 ** 8, "Senior", "sr");

        pool_weth.addTranche(address(srTranche_weth), 100);
        pool_weth.setLiquidationWeightTranche(100);
        pool_weth.changeGuardian(protocolOwnerAddress);

        pool_usdc = new LendingPool(
            protocolOwnerAddress, ERC20(address(usdc)), protocolOwnerAddress, address(factory), address(liquidator)
        );
        srTranche_usdc = new Tranche(address(pool_usdc), 10 ** 6, "Senior", "sr");

        pool_usdc.addTranche(address(srTranche_usdc), 100);
        pool_usdc.setLiquidationWeightTranche(100);
        pool_usdc.changeGuardian(protocolOwnerAddress);

        vm.stopBroadcast();
    }

    function test_deploy() public {
        address protocolOwnerAddress = DeployAddresses.protocolOwner_base;

        assertEq(pool_weth.name(), string("ArcadiaV2 WETH Debt"));
        assertEq(pool_weth.symbol(), string("darcV2WETH"));
        assertEq(pool_weth.decimals(), 18);
        assertEq(pool_weth.riskManager(), protocolOwnerAddress);

        assertEq(pool_usdc.name(), string("ArcadiaV2 USDC Debt"));
        assertEq(pool_usdc.symbol(), string("darcV2USDC"));
        assertEq(pool_usdc.decimals(), 6);
        assertEq(pool_usdc.riskManager(), protocolOwnerAddress);
    }
}