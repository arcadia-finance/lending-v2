/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Scenario_Lending_Test } from "./_Scenario.t.sol";

import { StdStorage, stdStorage } from "../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

import { AccountErrors } from "../../lib/accounts-v2/src/libraries/Errors.sol";
import { ActionData } from "../../lib/accounts-v2/src/interfaces/IActionBase.sol";
import { ActionMultiCall } from "../../lib/accounts-v2/src/actions/MultiCall.sol";
import { AssetValuationLib } from "../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { BitPackingLib } from "../../lib/accounts-v2/src/libraries/BitPackingLib.sol";
import { Constants } from "../../lib/accounts-v2/test/utils/Constants.sol";
import { IPermit2 } from "../../lib/accounts-v2/src/interfaces/IPermit2.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { LogExpMath } from "../../src/libraries/LogExpMath.sol";
import { MultiActionMock } from "../../lib/accounts-v2/test/utils/mocks/actions/MultiActionMock.sol";
import { LendingPoolErrors } from "../../src/libraries/Errors.sol";

/**
 * @notice Scenario tests for With Leveraged Actions flows.
 */
contract LeveragedActions_Scenario_Test is Scenario_Lending_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes32 internal oracleToken1ToUsd;
    bytes32 internal oracleStable1ToUsd;

    /* ///////////////////////////////////////////////////////////////
                           TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCall public action;
    MultiActionMock public multiActionMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Scenario_Lending_Test.setUp();

        vm.startPrank(users.creatorAddress);
        multiActionMock = new MultiActionMock();
        action = new ActionMultiCall();
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(pool), true);

        // Set the risk parameters.
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(pool),
            address(mockERC20.token1),
            0,
            type(uint112).max,
            Constants.tokenToStableCollFactor,
            Constants.tokenToStableLiqFactor
        );

        oracleToken1ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleToken1ToUsdArr);
        oracleStable1ToUsd = BitPackingLib.pack(BA_TO_QA_SINGLE, oracleStable1ToUsdArr);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testScenario_Revert_doActionWithLeverage_DifferentCreditor() public {
        vm.startPrank(users.accountOwner);
        proxyAccount.closeMarginAccount();
        proxyAccount.setAssetManager(address(pool), true);
        vm.stopPrank();

        //Prepare input parameters
        ActionData memory withdrawData = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0)
        });
        ActionData memory depositData = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0)
        });
        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory transferFromOwner;

        IPermit2.TokenPermissions[] memory tokenPermissions;

        bytes memory signature;

        bytes memory actionTargetData = abi.encode(depositData, to, data);
        bytes memory callData =
            abi.encode(withdrawData, transferFromOwner, tokenPermissions, signature, actionTargetData);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.OnlyCreditor.selector);
        pool.flashAction(0, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Revert_doActionWithLeverage_BadAccountVersion() public {
        vm.prank(users.creatorAddress);
        pool.setAccountVersion(1, false);

        //Prepare input parameters
        ActionData memory withdrawData = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0)
        });
        ActionData memory depositData = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0)
        });
        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory transferFromOwner;

        IPermit2.TokenPermissions[] memory tokenPermissions;

        bytes memory signature;

        bytes memory actionTargetData = abi.encode(depositData, to, data);
        bytes memory callData =
            abi.encode(withdrawData, transferFromOwner, tokenPermissions, signature, actionTargetData);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert(LendingPoolErrors.InvalidVersion.selector);
        pool.flashAction(0, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Revert_doActionWithLeverage_InsufficientCollateral(
        uint64 stableDebt,
        uint64 stableCollateral,
        uint64 tokenOut
    ) public {
        uint256 tokenRate = registryExtension.getRateInUsd(oracleToken1ToUsd); //18 decimals
        uint256 stableRate = registryExtension.getRateInUsd(oracleStable1ToUsd); //18 decimals

        uint256 stableIn =
            uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals / stableRate;

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is not successfull -> total debt after transaction should be bigger than the Collateral Value
        uint256 collValue = uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals
            * Constants.tokenToStableCollFactor / 100 * 10 ** Constants.stableDecimals / stableRate;
        vm.assume(stableMargin + stableDebt > collValue);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        debt.setRealisedDebt(stableDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxyAccount)).checked_write(
            stableDebt
        );

        //Deposit stableCollateral in Account
        depositTokenInAccount(proxyAccount, mockERC20.stable1, stableCollateral);

        //Prepare input parameters
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), stableIn);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(mockERC20.stable1),
            address(mockERC20.token1),
            stableIn,
            uint256(tokenOut)
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxyAccount), uint256(tokenOut));

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token1.mint(address(multiActionMock), tokenOut);

        to[0] = address(mockERC20.stable1);
        to[1] = address(multiActionMock);
        to[2] = address(mockERC20.token1);

        ActionData memory withdrawData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        withdrawData.assets[0] = address(mockERC20.stable1);
        withdrawData.assetTypes[0] = 0;
        withdrawData.assetIds[0] = 0;
        withdrawData.assetAmounts[0] = stableCollateral;

        ActionData memory depositData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        depositData.assets[0] = address(mockERC20.token1);
        depositData.assetTypes[0] = 0;
        withdrawData.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        IPermit2.TokenPermissions[] memory tokenPermissions;

        bytes memory signature;

        bytes memory actionTargetData = abi.encode(depositData, to, data);
        bytes memory callData =
            abi.encode(withdrawData, transferFromOwner, tokenPermissions, signature, actionTargetData);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        pool.flashAction(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Success_doActionWithLeverage_repayExact(
        uint72 stableCollateral,
        uint32 tokenOut,
        uint32 stableDebt
    ) public {
        uint256 stableIn;
        uint256 collValue;
        {
            uint256 tokenRate = registryExtension.getRateInUsd(oracleToken1ToUsd); //18 decimals
            uint256 stableRate = registryExtension.getRateInUsd(oracleStable1ToUsd); //18 decimals

            stableIn = uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals
                / stableRate;
            collValue = uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals
                * Constants.tokenToStableCollFactor / AssetValuationLib.ONE_4 * 10 ** Constants.stableDecimals / stableRate;
        }

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(stableMargin + stableDebt <= collValue);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        debt.setRealisedDebt(stableDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxyAccount)).checked_write(
            stableDebt
        );

        //Deposit stableCollateral in Account
        depositTokenInAccount(proxyAccount, mockERC20.stable1, stableCollateral);

        //Prepare input parameters
        bytes[] memory data = new bytes[](3);
        address[] memory to = new address[](3);

        data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), stableIn);
        data[1] = abi.encodeWithSignature(
            "swapAssets(address,address,uint256,uint256)",
            address(mockERC20.stable1),
            address(mockERC20.token1),
            stableIn,
            uint256(tokenOut)
        );
        data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxyAccount), uint256(tokenOut));

        vm.prank(users.tokenCreatorAddress);
        mockERC20.token1.mint(address(multiActionMock), tokenOut);

        to[0] = address(mockERC20.stable1);
        to[1] = address(multiActionMock);
        to[2] = address(mockERC20.token1);

        ActionData memory withdrawData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        withdrawData.assets[0] = address(mockERC20.stable1);
        withdrawData.assetTypes[0] = 0;
        withdrawData.assetIds[0] = 0;
        withdrawData.assetAmounts[0] = stableCollateral;

        ActionData memory depositData = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1)
        });

        depositData.assets[0] = address(mockERC20.token1);
        depositData.assetTypes[0] = 0;
        withdrawData.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        IPermit2.TokenPermissions[] memory tokenPermissions;

        bytes memory signature;

        bytes memory actionTargetData = abi.encode(depositData, to, data);
        bytes memory callData =
            abi.encode(withdrawData, transferFromOwner, tokenPermissions, signature, actionTargetData);

        //Do swap on leverage
        vm.prank(users.accountOwner);
        pool.flashAction(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), type(uint128).max - stableMargin);
        assertEq(mockERC20.stable1.balanceOf(address(multiActionMock)), stableIn);
        assertEq(mockERC20.token1.balanceOf(address(proxyAccount)), tokenOut);
        assertEq(debt.balanceOf(address(proxyAccount)), uint256(stableDebt) + stableMargin);

        uint256 debtAmount = proxyAccount.getUsedMargin();

        bytes[] memory dataArr = new bytes[](2);
        dataArr[0] = abi.encodeWithSignature("approve(address,uint256)", address(pool), type(uint256).max);
        dataArr[1] = abi.encodeWithSignature(
            "executeRepay(address,address,address,uint256)",
            address(pool),
            address(mockERC20.stable1),
            address(proxyAccount),
            0
        );

        address[] memory tos = new address[](2);
        tos[0] = address(mockERC20.stable1);
        tos[1] = address(action);

        ActionData memory ad;

        vm.startPrank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(address(action), debtAmount);
        action.executeAction(abi.encode(ad, tos, dataArr));
        vm.stopPrank();

        assertEq(debt.balanceOf(address(proxyAccount)), 0);
        assertEq(proxyAccount.getUsedMargin(), 0);
    }

    function testScenario_Success_doActionWithLeverage(uint32 stableDebt, uint72 stableCollateral, uint32 tokenOut)
        public
    {
        uint256 stableIn;
        uint256 collValue;
        {
            uint256 tokenRate = registryExtension.getRateInUsd(oracleToken1ToUsd); //18 decimals
            uint256 stableRate = registryExtension.getRateInUsd(oracleStable1ToUsd); //18 decimals

            stableIn = uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals
                / stableRate;
            collValue = uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals
                * Constants.tokenToStableCollFactor / AssetValuationLib.ONE_4 * 10 ** Constants.stableDecimals / stableRate;
        }

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(stableMargin + stableDebt <= collValue);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        debt.setRealisedDebt(stableDebt);
        stdstore.target(address(debt)).sig(debt.balanceOf.selector).with_key(address(proxyAccount)).checked_write(
            stableDebt
        );

        //Deposit stableCollateral in Account
        depositTokenInAccount(proxyAccount, mockERC20.stable1, stableCollateral);

        //Prepare input parameters
        bytes memory callData;
        {
            bytes[] memory data = new bytes[](3);
            address[] memory to = new address[](3);

            data[0] = abi.encodeWithSignature("approve(address,uint256)", address(multiActionMock), stableIn);
            data[1] = abi.encodeWithSignature(
                "swapAssets(address,address,uint256,uint256)",
                address(mockERC20.stable1),
                address(mockERC20.token1),
                stableIn,
                uint256(tokenOut)
            );
            data[2] = abi.encodeWithSignature("approve(address,uint256)", address(proxyAccount), uint256(tokenOut));

            vm.prank(users.tokenCreatorAddress);
            mockERC20.token1.mint(address(multiActionMock), tokenOut);

            to[0] = address(mockERC20.stable1);
            to[1] = address(multiActionMock);
            to[2] = address(mockERC20.token1);

            ActionData memory withdrawData = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            withdrawData.assets[0] = address(mockERC20.stable1);
            withdrawData.assetTypes[0] = 0;
            withdrawData.assetIds[0] = 0;
            withdrawData.assetAmounts[0] = stableCollateral;

            ActionData memory depositData = ActionData({
                assets: new address[](1),
                assetIds: new uint256[](1),
                assetAmounts: new uint256[](1),
                assetTypes: new uint256[](1)
            });

            depositData.assets[0] = address(mockERC20.token1);
            depositData.assetTypes[0] = 0;
            withdrawData.assetIds[0] = 0;

            ActionData memory transferFromOwner;

            IPermit2.TokenPermissions[] memory tokenPermissions;

            bytes memory signature;

            bytes memory actionTargetData = abi.encode(depositData, to, data);
            callData = abi.encode(withdrawData, transferFromOwner, tokenPermissions, signature, actionTargetData);
        }

        //Do swap on leverage
        vm.prank(users.accountOwner);
        pool.flashAction(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), type(uint128).max - stableMargin);
        assertEq(mockERC20.stable1.balanceOf(address(multiActionMock)), stableIn);
        assertEq(mockERC20.token1.balanceOf(address(proxyAccount)), tokenOut);
        assertEq(debt.balanceOf(address(proxyAccount)), uint256(stableDebt) + stableMargin);
    }
}
