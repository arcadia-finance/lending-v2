/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import "../lib/forge-std/src/Test.sol";

import { ArcadiaAddresses, ArcadiaContractAddresses } from "./Constants/TransferOwnershipConstants.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { Tranche } from "../src/Tranche.sol";
import { Liquidator } from "../src/Liquidator.sol";

contract ArcadiaLendingTransferOwnership is Test {
    LendingPool internal lendingPool_usdc;
    LendingPool internal lendingPool_weth;
    Tranche internal srTranche_usdc;
    Tranche internal srTranche_weth;
    Liquidator internal liquidator;

    constructor() {
        lendingPool_usdc = LendingPool(ArcadiaContractAddresses.lendingPool_usdc);
        lendingPool_weth = LendingPool(ArcadiaContractAddresses.lendingPool_weth);
        srTranche_usdc = Tranche(ArcadiaContractAddresses.tranche_usdc);
        srTranche_weth = Tranche(ArcadiaContractAddresses.tranche_weth);
        liquidator = Liquidator(ArcadiaContractAddresses.liquidator);
    }

    function run() public {
        uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");
        vm.startBroadcast(ownerPrivateKey);

        // Set guardian
        lendingPool_usdc.changeGuardian(ArcadiaAddresses.guardian);
        lendingPool_weth.changeGuardian(ArcadiaAddresses.guardian);

        // Set account recipient
        liquidator.setAccountRecipient(address(lendingPool_usdc), ArcadiaAddresses.accountRecipient);
        liquidator.setAccountRecipient(address(lendingPool_weth), ArcadiaAddresses.accountRecipient);

        // Set risk manager
        lendingPool_usdc.setRiskManager(ArcadiaAddresses.riskManager);
        lendingPool_weth.setRiskManager(ArcadiaAddresses.riskManager);

        // Set treasury
        lendingPool_usdc.setTreasury(ArcadiaAddresses.treasury);
        lendingPool_weth.setTreasury(ArcadiaAddresses.treasury);

        // Transfer ownership to respected addresses
        lendingPool_usdc.transferOwnership(ArcadiaAddresses.owner);
        lendingPool_weth.transferOwnership(ArcadiaAddresses.owner);
        srTranche_usdc.transferOwnership(ArcadiaAddresses.owner);
        srTranche_weth.transferOwnership(ArcadiaAddresses.owner);
        liquidator.transferOwnership(ArcadiaAddresses.owner);
        vm.stopBroadcast();
    }

    function test_transferOwnership() public {
        vm.skip(true);

        assertEq(lendingPool_usdc.guardian(), ArcadiaAddresses.guardian);
        assertEq(lendingPool_weth.guardian(), ArcadiaAddresses.guardian);

        assertEq(lendingPool_usdc.riskManager(), ArcadiaAddresses.riskManager);
        assertEq(lendingPool_usdc.riskManager(), ArcadiaAddresses.riskManager);

        assertEq(lendingPool_usdc.owner(), ArcadiaAddresses.owner);
        assertEq(lendingPool_weth.owner(), ArcadiaAddresses.owner);
        assertEq(srTranche_usdc.owner(), ArcadiaAddresses.owner);
        assertEq(srTranche_weth.owner(), ArcadiaAddresses.owner);
        assertEq(liquidator.owner(), ArcadiaAddresses.owner);
    }
}
