/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AccountsGuardExtension } from "../../../../lib/accounts-v2/test/utils/extensions/AccountsGuardExtension.sol";
import { AccountV3 } from "../../../../lib/accounts-v2/src/accounts/AccountV3.sol";
import { ArcadiaOracle } from "../../../../lib/accounts-v2/test/utils/mocks/oracles/ArcadiaOracle.sol";
import { BitPackingLib } from "../../../../lib/accounts-v2/src/libraries/BitPackingLib.sol";
import { ChainlinkOMExtension } from "../../../../lib/accounts-v2/test/utils/extensions/ChainlinkOMExtension.sol";
import { Constants } from "../../../../lib/accounts-v2/test/utils/Constants.sol";
import { DebtTokenExtension } from "../../../utils/extensions/DebtTokenExtension.sol";
import { ERC20, ERC20Mock } from "../../../../lib/accounts-v2/test/utils/mocks/tokens/ERC20Mock.sol";
import { ERC20PrimaryAMExtension } from "../../../../lib/accounts-v2/test/utils/extensions/ERC20PrimaryAMExtension.sol";
import { FactoryExtension } from "../../../../lib/accounts-v2/test/utils/extensions/FactoryExtension.sol";
import { FloorERC721AMExtension } from "../../../../lib/accounts-v2/test/utils/extensions/FloorERC721AMExtension.sol";
import { FloorERC1155AMExtension } from "../../../../lib/accounts-v2/test/utils/extensions/FloorERC1155AMExtension.sol";
import { Fuzz_Lending_Test } from "../../Fuzz.t.sol";
import { LendingPoolExtension } from "../../../utils/extensions/LendingPoolExtension.sol";
import { LiquidatorL1Extension } from "../../../utils/extensions/LiquidatorL1Extension.sol";
import { RegistryL1Extension } from "../../../../lib/accounts-v2/test/utils/extensions/RegistryL1Extension.sol";

/**
 * @notice Common logic needed by all "LiquidatorL1" fuzz tests.
 */
abstract contract LiquidatorL1_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    RegistryL1Extension internal registry_;

    /* ///////////////////////////////////////////////////////////////
                            TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    LiquidatorL1Extension internal liquidator_;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithAccounts();

        vm.startPrank(users.owner);
        factory = new FactoryExtension();
        registry_ = new RegistryL1Extension(address(factory));
        chainlinkOM = new ChainlinkOMExtension(address(registry_));
        erc20AM = new ERC20PrimaryAMExtension(address(registry_));
        floorERC721AM = new FloorERC721AMExtension(address(registry_));
        floorERC1155AM = new FloorERC1155AMExtension(address(registry_));

        accountsGuard = new AccountsGuardExtension(users.owner, address(factory));
        accountLogic = new AccountV3(address(factory), address(accountsGuard), address(0));
        factory.setLatestAccountVersion(2);
        factory.setNewAccountInfo(address(registry_), address(accountLogic), Constants.upgradeRoot3To4And4To3, "");

        // Set the Guardians.
        factory.changeGuardian(users.guardian);
        registry_.changeGuardian(users.guardian);

        // Add Asset Modules to the Registry.
        registry_.addAssetModule(address(erc20AM));
        registry_.addAssetModule(address(floorERC721AM));
        registry_.addAssetModule(address(floorERC1155AM));

        // Add Oracle Modules to the Registry.
        registry_.addOracleModule(address(chainlinkOM));

        // Add oracles and assets.
        chainlinkOM.addOracle(address(mockOracles.stable1ToUsd), "STABLE1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.stable2ToUsd), "STABLE2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token1ToUsd), "TOKEN1", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.token2ToUsd), "TOKEN2", "USD", 2 days);
        chainlinkOM.addOracle(address(mockOracles.nft1ToToken1), "NFT1", "TOKEN1", 2 days);
        chainlinkOM.addOracle(address(mockOracles.sft1ToToken1), "SFT1", "TOKEN1", 2 days);
        erc20AM.addAsset(address(mockERC20.stable1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.stable2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable2ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token1), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr));
        erc20AM.addAsset(address(mockERC20.token2), BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken2ToUsdArr));
        floorERC721AM.addAsset(
            address(mockERC721.nft1), 0, 999, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleNft1ToToken1ToUsd)
        );
        floorERC1155AM.addAsset(
            address(mockERC1155.sft1), 1, BitPackingLib.pack(BA_TO_QA_DOUBLE, oracleSft1ToToken1ToUsd)
        );
        vm.stopPrank();

        // Deploy an initial Account with all inputs to zero
        vm.prank(users.accountOwner);
        address proxyAddress = factory.createAccount(0, 0, address(0));
        account = AccountV3(proxyAddress);

        // Set Risk Variables.
        vm.startPrank(users.riskManager);
        registry_.setRiskParameters(address(creditorUsd), 0, type(uint64).max);
        registry_.setRiskParameters(address(creditorStable1), 0, type(uint64).max);
        registry_.setRiskParameters(address(creditorToken1), 0, type(uint64).max);

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.stableToStableCollFactor,
            Constants.stableToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.stable2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1),
            address(mockERC20.token2),
            0,
            type(uint112).max,
            Constants.tokenToTokenCollFactor,
            Constants.tokenToTokenLiqFactor
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC721.nft1), 0, type(uint112).max, 0, 0
        );

        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorUsd), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorStable1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );
        registry_.setRiskParametersOfPrimaryAsset(
            address(creditorToken1), address(mockERC1155.sft1), 1, type(uint112).max, 0, 0
        );

        vm.stopPrank();

        vm.prank(users.tokenCreator);
        mockERC20.stable1.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.startPrank(users.owner);
        liquidator_ = new LiquidatorL1Extension(address(factory));
        pool = new LendingPoolExtension(
            users.riskManager, ERC20(mockERC20.stable1), users.treasury, address(factory), address(liquidator_)
        );
        pool.changeGuardian(users.guardian);
        vm.stopPrank();

        debt = DebtTokenExtension(address(pool));

        srTranche = createTranche("Senior", "SR", 50);
        jrTranche = createTranche("Junior", "JR", 40);
        tranche = srTranche;

        vm.startPrank(users.owner);
        pool.setTreasuryWeights(10, 80);
        pool.setLiquidationParameters(100, 500, 50, 0, 0);
        pool.setLiquidationWeightTranche(20);
        pool.setAccountVersion(3, true);
        vm.stopPrank();

        vm.startPrank(users.riskManager);
        registry_.setRiskParameters(address(pool), 0, type(uint64).max);
        registry_.setRiskParametersOfPrimaryAsset(address(pool), address(pool.asset()), 0, type(uint112).max, 1e4, 1e4);
        liquidator_.setAccountRecipient(address(pool), users.riskManager);
        vm.stopPrank();

        // Open Margin Account.
        vm.prank(users.accountOwner);
        account.openMarginAccount(address(pool));
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    function initiateLiquidation(uint112 amountLoaned) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        depositERC20InAccount(account, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(account), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(address(45));
        liquidator_.liquidateAccount(address(account));
    }
}
