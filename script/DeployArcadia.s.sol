/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import {
    AccountLogic,
    ArcadiaAccounts,
    AssetModules,
    OracleModules
} from "../lib/accounts-v2/script/utils/constants/Shared.sol";
import { AccountSpot } from "../lib/accounts-v2/src/accounts/AccountSpot.sol";
import { AccountV1 } from "../lib/accounts-v2/src/accounts/AccountV1.sol";
import { AerodromePoolAM } from "../lib/accounts-v2/src/asset-modules/Aerodrome-Finance/AerodromePoolAM.sol";
import { ArcadiaLending, Deployers } from "./utils/constants/Shared.sol";
import {
    Assets,
    ExternalContracts,
    MerkleRoots,
    Oracles,
    Safes
} from "../lib/accounts-v2/script/utils/constants/Optimism.sol";
import { Base_Lending_Script } from "./Base.s.sol";
import { BitPackingLib } from "../lib/accounts-v2/src/libraries/BitPackingLib.sol";
import { ChainlinkOM } from "../lib/accounts-v2/src/oracle-modules/ChainlinkOM.sol";
import { DefaultUniswapV4AM } from "../lib/accounts-v2/src/asset-modules/UniswapV4/DefaultUniswapV4AM.sol";
import { ERC20 } from "../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { ERC20PrimaryAM } from "../lib/accounts-v2/src/asset-modules/ERC20-Primaries/ERC20PrimaryAM.sol";
import { Factory } from "../lib/accounts-v2/src/Factory.sol";
import { LendingPool } from "../src/LendingPool.sol";
import { LendingPools, Tranches } from "./utils/constants/Optimism.sol";
import { Liquidator } from "../src/Liquidator.sol";
import { Registry } from "../lib/accounts-v2/src/Registry.sol";
import { SlipstreamAM } from "../lib/accounts-v2/src/asset-modules/Slipstream/SlipstreamAM.sol";
import { StakedAerodromeAM } from "../lib/accounts-v2/src/asset-modules/Aerodrome-Finance/StakedAerodromeAM.sol";
import { StakedSlipstreamAM } from "../lib/accounts-v2/src/asset-modules/Slipstream/StakedSlipstreamAM.sol";
import { StakedStargateAM } from "../lib/accounts-v2/src/asset-modules/Stargate-Finance/StakedStargateAM.sol";
import { StargateAM } from "../lib/accounts-v2/src/asset-modules/Stargate-Finance/StargateAM.sol";
import { Tranche } from "../src/Tranche.sol";
import { TrancheWrapper } from "../src/periphery/tranche-wrapper/TrancheWrapper.sol";
import { UniswapV3AM } from "../lib/accounts-v2/src/asset-modules/UniswapV3/UniswapV3AM.sol";
import { UniswapV4HooksRegistry } from "../lib/accounts-v2/src/asset-modules/UniswapV4/UniswapV4HooksRegistry.sol";
import { WrappedAerodromeAM } from "../lib/accounts-v2/src/asset-modules/Aerodrome-Finance/WrappedAerodromeAM.sol";

contract DeployArcadia is Base_Lending_Script {
    AccountSpot internal accountLogicSpot;
    AccountV1 internal accountLogicV1;
    DefaultUniswapV4AM internal defaultUniswapV4AM = DefaultUniswapV4AM(AssetModules.DEFAULT_UNISWAPV4);
    StakedStargateAM internal stakedStargateAM;
    StargateAM internal stargateAM;
    TrancheWrapper internal wrappedTrancheUsdc;
    TrancheWrapper internal wrappedTrancheWeth;
    UniswapV3AM internal uniswapV3AM;
    UniswapV4HooksRegistry internal uniswapV4HooksRegistry;

    constructor() { }

    function run() public {
        require(vm.addr(deployer) == Deployers.ARCADIA, "Wrong Deployer.");

        vm.startBroadcast(deployer);
        //// Start DeployLending_step1.s.sol
        // Deploy Arcadia Core contracts.
        factory = new Factory();
        liquidator = new Liquidator(address(factory), ExternalContracts.SEQUENCER_UPTIME_ORACLE);

        // Deploy WETH Lending Pool and Tranche.
        lendingPoolWeth = new LendingPool(
            Deployers.ARCADIA, ERC20(LendingPools.WETH().asset), Safes.TREASURY, address(factory), address(liquidator)
        );
        trancheWeth = new Tranche(
            address(lendingPoolWeth), Tranches.WETH_SR().vas, Tranches.WETH_SR().prefix, Tranches.WETH_SR().prefixSymbol
        );
        lendingPoolWeth.addTranche(address(trancheWeth), Tranches.WETH_SR().interestWeight);
        lendingPoolWeth.setLiquidationWeightTranche(LendingPools.WETH().liquidationWeightTranche);
        lendingPoolWeth.changeGuardian(Safes.GUARDIAN);

        // Deploy USDC Lending Pool and Tranche.
        lendingPoolUsdc = new LendingPool(
            Deployers.ARCADIA, ERC20(LendingPools.USDC().asset), Safes.TREASURY, address(factory), address(liquidator)
        );
        trancheUsdc = new Tranche(
            address(lendingPoolUsdc), Tranches.USDC_SR().vas, Tranches.USDC_SR().prefix, Tranches.USDC_SR().prefixSymbol
        );
        lendingPoolUsdc.addTranche(address(trancheUsdc), Tranches.USDC_SR().interestWeight);
        lendingPoolUsdc.setLiquidationWeightTranche(LendingPools.USDC().liquidationWeightTranche);
        lendingPoolUsdc.changeGuardian(Safes.GUARDIAN);

        //// Start Deploy_accounts_base_step_1.s.sol
        // Skip nonces.
        skipNonces(2);

        // Deploy contracts accounts.
        registry = new Registry(address(factory), ExternalContracts.SEQUENCER_UPTIME_ORACLE);
        chainlinkOM = new ChainlinkOM(address(registry));
        accountLogicV1 = new AccountV1(address(factory));
        skipNonces(1);
        erc20PrimaryAM = new ERC20PrimaryAM(address(registry));
        registry.addAssetModule(address(erc20PrimaryAM));
        registry.addOracleModule(address(chainlinkOM));

        // Add OP and VELO to registry (required for staked AM).
        uint80[] memory oracles = new uint80[](1);
        chainlinkOM.addOracle(
            Oracles.OP_USD().oracle,
            Oracles.OP_USD().baseAsset,
            Oracles.OP_USD().quoteAsset,
            Oracles.OP_USD().cutOffTime
        );
        oracles[0] = Oracles.OP_USD().id;
        erc20PrimaryAM.addAsset(Assets.OP().asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles));
        chainlinkOM.addOracle(
            Oracles.VELO_USD().oracle,
            Oracles.VELO_USD().baseAsset,
            Oracles.VELO_USD().quoteAsset,
            Oracles.VELO_USD().cutOffTime
        );
        oracles[0] = Oracles.VELO_USD().id;
        erc20PrimaryAM.addAsset(Assets.VELO().asset, BitPackingLib.pack(BA_TO_QA_SINGLE, oracles));
        // We don't add the other assets to the registry yet.
        skipNonces(11);

        // Deploy and initialize remaining Asset Modules.
        uniswapV3AM = new UniswapV3AM(address(registry), ExternalContracts.UNISWAPV3_POS_MNGR);
        stargateAM = new StargateAM(address(registry), ExternalContracts.STARGATE_FACTORY);
        stakedStargateAM = new StakedStargateAM(address(registry), ExternalContracts.STARGATE_LP_STAKING);
        registry.addAssetModule(address(uniswapV3AM));
        registry.addAssetModule(address(stargateAM));
        registry.addAssetModule(address(stakedStargateAM));
        uniswapV3AM.setProtocol();
        skipNonces(1);
        stakedStargateAM.initialize();
        skipNonces(1);

        // Set AccountLogicV1.
        factory.setNewAccountInfo(address(registry), address(accountLogicV1), MerkleRoots.V1, "");
        skipNonces(4);

        //// Start DeployLending_step2.sol
        skipNonces(6);

        //// 3 random tx
        skipNonces(3);

        //// Start Deploy_accounts_base_step_2.sol
        skipNonces(24);

        //// eth transfer
        skipNonces(1);

        //// Run Deploy_accounts_base_step_2.sol again
        skipNonces(24);

        //// Run DeployLending_step2.sol again
        skipNonces(6);

        //// Register Odos.
        skipNonces(1);

        //// Transfer Ownership lending.
        skipNonces(2);
        liquidator.setAccountRecipient(address(lendingPoolUsdc), Deployers.ARCADIA);
        liquidator.setAccountRecipient(address(lendingPoolWeth), Deployers.ARCADIA);
        lendingPoolUsdc.setRiskManager(Safes.RISK_MANAGER);
        lendingPoolWeth.setRiskManager(Safes.RISK_MANAGER);
        skipNonces(2);
        lendingPoolUsdc.transferOwnership(Safes.OWNER);
        lendingPoolWeth.transferOwnership(Safes.OWNER);
        trancheUsdc.transferOwnership(Safes.OWNER);
        trancheWeth.transferOwnership(Safes.OWNER);
        liquidator.transferOwnership(Safes.OWNER);

        //// Transfer Ownership accounts.
        factory.changeGuardian(Safes.GUARDIAN);
        registry.changeGuardian(Safes.GUARDIAN);
        // Skip transfer ownership registry and factory untill end.
        skipNonces(2);
        erc20PrimaryAM.transferOwnership(Safes.OWNER);
        chainlinkOM.transferOwnership(Safes.OWNER);
        uniswapV3AM.transferOwnership(Safes.OWNER);
        stargateAM.transferOwnership(Safes.OWNER);
        stakedStargateAM.transferOwnership(Safes.OWNER);

        //// DeployAerodromeStep1.
        // Add velo was already done before.
        skipNonces(1);

        //// DeployAerodromeStep2.
        aerodromePoolAM = new AerodromePoolAM(address(registry), ExternalContracts.VELO_FACTORY);
        slipstreamAM = new SlipstreamAM(address(registry), ExternalContracts.SLIPSTREAM_POS_MNGR);
        stakedAerodromeAM = new StakedAerodromeAM(address(registry), ExternalContracts.VELO_VOTER, Assets.VELO().asset);
        wrappedAerodromeAM = new WrappedAerodromeAM(address(registry));

        //// DeployAerodromeStep3.
        // Add AM to the registry (this was one safe tx on base).
        registry.addAssetModule(address(aerodromePoolAM));
        registry.addAssetModule(address(slipstreamAM));
        registry.addAssetModule(address(stakedAerodromeAM));
        registry.addAssetModule(address(wrappedAerodromeAM));

        //// DeployAerodromeStep4.
        slipstreamAM.setProtocol();
        stakedAerodromeAM.initialize();
        wrappedAerodromeAM.initialize();
        // Skip add pools and gauges (minus the three tx we sent before).
        skipNonces(24);
        aerodromePoolAM.transferOwnership(Safes.OWNER);
        slipstreamAM.transferOwnership(Safes.OWNER);
        stakedAerodromeAM.transferOwnership(Safes.OWNER);
        wrappedAerodromeAM.transferOwnership(Safes.OWNER);

        //// DeployAerodromeStep5.
        // Add velo was already done before.
        skipNonces(1);

        //// failed Superform tx.
        skipNonces(3);

        //// New action handler.
        skipNonces(1);

        //// DeployAerodromeStep6.
        stakedSlipstreamAM = new StakedSlipstreamAM(
            address(registry), ExternalContracts.SLIPSTREAM_POS_MNGR, ExternalContracts.VELO_VOTER, Assets.VELO().asset
        );

        //// DeployAerodromeStep7.
        registry.addAssetModule(address(stakedSlipstreamAM));

        //// DeployAerodromeStep8.
        stakedSlipstreamAM.initialize();
        skipNonces(6);
        stakedSlipstreamAM.transferOwnership(Safes.OWNER);

        //// DeployAerodromeStep9.
        skipNonces(1);

        //// DeployTrancheWrapper.
        wrappedTrancheUsdc = new TrancheWrapper(address(trancheUsdc));
        wrappedTrancheWeth = new TrancheWrapper(address(trancheWeth));

        //// Bunch of random tx.
        skipNonces(17);

        //// AddCbbtc
        skipNonces(12);

        //// Bunch of random tx.
        skipNonces(10);

        //// DeployAlienBaseStep1
        skipNonces(2);

        //// Random tx.
        skipNonces(8);

        //// AddSpotAccountsStep1
        accountLogicSpot = new AccountSpot(address(factory));

        //// AddSpotAccountsStep2
        skipNonces(1);

        //// Random tx.
        skipNonces(14);

        //// DeployUniswapV4Step1 and DeployUniswapV4Step2 (We normally do two safe tx after transferOwnership, but we use two to set regestry).
        uniswapV4HooksRegistry = new UniswapV4HooksRegistry(address(registry), ExternalContracts.UNISWAPV4_POS_MNGR);
        registry.addAssetModule(address(uniswapV4HooksRegistry));
        uniswapV4HooksRegistry.setProtocol();
        uniswapV4HooksRegistry.transferOwnership(Safes.OWNER);
        defaultUniswapV4AM.transferOwnership(Safes.OWNER);

        //// We use two random tx to transfer factory and registry ownership, since that is no longer needed to be deployer
        factory.transferOwnership(Safes.OWNER);
        registry.transferOwnership(Safes.OWNER);

        //// Deploy Asset managers.
        //ToDo: move to new repo so this can be done in same script.
        vm.stopBroadcast();

        test_deploy();
    }

    function test_deploy() public {
        vm.skip(false);

        assertEq(address(factory), ArcadiaAccounts.FACTORY);
        assertEq(address(liquidator), ArcadiaLending.LIQUIDATOR);
        assertEq(address(lendingPoolWeth), ArcadiaLending.LENDINGPOOL_WETH);
        assertEq(address(trancheWeth), ArcadiaLending.TRANCHE_WETH);
        assertEq(address(lendingPoolUsdc), ArcadiaLending.LENDINGPOOL_USDC);
        assertEq(address(trancheUsdc), ArcadiaLending.TRANCHE_USDC);
        assertEq(address(registry), ArcadiaAccounts.REGISTRY);
        assertEq(address(chainlinkOM), OracleModules.CHAINLINK);
        assertEq(address(accountLogicV1), AccountLogic.V1);
        assertEq(address(erc20PrimaryAM), AssetModules.ERC20_PRIMARY);
        assertEq(address(uniswapV3AM), AssetModules.UNISWAPV3);
        assertEq(address(stargateAM), AssetModules.STARGATE);
        assertEq(address(stakedStargateAM), AssetModules.STAKED_STARGATE);
        assertEq(address(aerodromePoolAM), AssetModules.AERO_POOL);
        assertEq(address(slipstreamAM), AssetModules.SLIPSTREAM);
        assertEq(address(stakedAerodromeAM), AssetModules.STAKED_AERO);
        assertEq(address(wrappedAerodromeAM), AssetModules.WRAPPED_AERO);
        assertEq(address(stakedSlipstreamAM), AssetModules.STAKED_SLIPSTREAM);
        assertEq(address(wrappedTrancheUsdc), ArcadiaLending.WRAPPED_TRANCHE_USDC);
        assertEq(address(wrappedTrancheWeth), ArcadiaLending.WRAPPED_TRANCHE_WETH);
        assertEq(address(accountLogicSpot), AccountLogic.V2);
        assertEq(address(uniswapV4HooksRegistry), ArcadiaAccounts.UNISWAPV4_HOOKS_REGISTRY);
        assertEq(address(defaultUniswapV4AM), AssetModules.DEFAULT_UNISWAPV4);
    }

    function skipNonces(uint256 amount) internal {
        for (uint256 i = 0; i < amount; i++) {
            (bool success,) = Deployers.ARCADIA.call{ value: 0 }("");
            require(success, "Failed to send zero-value transaction.");
        }
    }
}
