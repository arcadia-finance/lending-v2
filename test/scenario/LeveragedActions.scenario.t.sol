/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Scenario_Lending_Test } from "./_Scenario.t.sol";

import { StdStorage, stdStorage } from "../../lib/accounts-v2/lib/forge-std/src/StdStorage.sol";

import { LogExpMath } from "../../src/libraries/LogExpMath.sol";
import { Constants } from "../../lib/accounts-v2/test/utils/Constants.sol";
import { ActionMultiCallV2 } from "../../lib/accounts-v2/src/actions/MultiCallV2.sol";
import { ActionData } from "../../lib/accounts-v2/src/actions/utils/ActionData.sol";
import { MultiActionMock } from "../../lib/accounts-v2/test/utils/mocks/MultiActionMock.sol";
import { Errors } from "../../src/libraries/Errors.sol";

/**
 * @notice Scenario tests for With Leveraged Actions flows.
 */
contract LeveragedActions_Scenario_Test is Scenario_Lending_Test {
    using stdStorage for StdStorage;
    /* ///////////////////////////////////////////////////////////////
                           TEST CONTRACTS
    /////////////////////////////////////////////////////////////// */

    ActionMultiCallV2 public action;
    MultiActionMock public multiActionMock;

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Scenario_Lending_Test.setUp();

        vm.startPrank(users.creatorAddress);
        multiActionMock = new MultiActionMock();
        action = new ActionMultiCallV2();
        mainRegistryExtension.setAllowedAction(address(action), true);
        vm.stopPrank();

        vm.prank(users.accountOwner);
        proxyAccount.setAssetManager(address(pool), true);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testScenario_Revert_doActionWithLeverage_DifferentTrustedCreditor() public {
        vm.startPrank(users.accountOwner);
        proxyAccount.closeTrustedMarginAccount();
        proxyAccount.setAssetManager(address(pool), true);
        vm.stopPrank();

        //Prepare input parameters
        ActionData memory assetDataOut = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        ActionData memory assetDataIn = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert(Errors.LendingPool_Reverted.selector);
        pool.doActionWithLeverage(0, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Revert_doActionWithLeverage_BadAccountVersion() public {
        vm.prank(users.creatorAddress);
        pool.setAccountVersion(1, false);

        //Prepare input parameters
        ActionData memory assetDataOut = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        ActionData memory assetDataIn = ActionData({
            assets: new address[](0),
            assetIds: new uint256[](0),
            assetAmounts: new uint256[](0),
            assetTypes: new uint256[](0),
            actionBalances: new uint256[](0)
        });
        bytes[] memory data = new bytes[](0);
        address[] memory to = new address[](0);

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert(Errors.LendingPool_Reverted.selector);
        pool.doActionWithLeverage(0, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Revert_doActionWithLeverage_InsufficientCollateral(
        uint64 stableDebt,
        uint64 stableCollateral,
        uint64 tokenOut
    ) public {
        (uint256 tokenRate) = oracleHub.getRateInUsd(oracleToken1ToUsdArr); //18 decimals
        (uint256 stableRate) = oracleHub.getRateInUsd(oracleStable1ToUsdArr); //18 decimals

        uint256 stableIn =
            uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals / stableRate;

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is not successfull -> total debt after transaction should be bigger than the Collateral Value
        vm.assume(stableMargin + stableDebt > Constants.tokenToStableCollFactor * stableIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(stableDebt);
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

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.stable1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = stableCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token1);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Do swap on leverage
        vm.startPrank(users.accountOwner);
        vm.expectRevert("A_AMA: Account Unhealthy");
        pool.doActionWithLeverage(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Success_doActionWithLeverage_repayExact(
        uint32 stableDebt,
        uint72 stableCollateral,
        uint32 tokenOut
    ) public {
        (uint256 tokenRate) = oracleHub.getRateInUsd(oracleToken1ToUsdArr); //18 decimals
        (uint256 stableRate) = oracleHub.getRateInUsd(oracleStable1ToUsdArr); //18 decimals

        uint256 stableIn =
            uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals / stableRate;

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(stableMargin + stableDebt <= Constants.tokenToStableCollFactor * stableIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(stableDebt);
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

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.stable1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = stableCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token1);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Do swap on leverage
        vm.prank(users.accountOwner);
        pool.doActionWithLeverage(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);

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
        action.executeAction(abi.encode(ad, ad, ad, tos, dataArr));
        vm.stopPrank();

        assertEq(debt.balanceOf(address(proxyAccount)), 0);
        assertEq(proxyAccount.getUsedMargin(), 0);
    }

    function testScenario_Success_doActionWithLeverage(uint32 stableDebt, uint72 stableCollateral, uint32 tokenOut)
        public
    {
        (uint256 tokenRate) = oracleHub.getRateInUsd(oracleToken1ToUsdArr); //18 decimals
        (uint256 stableRate) = oracleHub.getRateInUsd(oracleStable1ToUsdArr); //18 decimals

        uint256 stableIn =
            uint256(tokenOut) * tokenRate / 10 ** Constants.tokenDecimals * 10 ** Constants.stableDecimals / stableRate;

        //With leverage -> stableIn should be bigger than the available collateral
        vm.assume(stableIn > stableCollateral);

        uint256 stableMargin = stableIn - stableCollateral;

        //Action is successfull -> total debt after transaction should be smaller than the Collateral Value
        vm.assume(stableMargin + stableDebt <= Constants.tokenToStableCollFactor * stableIn / 100);

        //Set initial debt
        stdstore.target(address(debt)).sig(debt.totalSupply.selector).checked_write(stableDebt);
        stdstore.target(address(debt)).sig(debt.realisedDebt.selector).checked_write(stableDebt);
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

        ActionData memory assetDataOut = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataOut.assets[0] = address(mockERC20.stable1);
        assetDataOut.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;
        assetDataOut.assetAmounts[0] = stableCollateral;

        ActionData memory assetDataIn = ActionData({
            assets: new address[](1),
            assetIds: new uint256[](1),
            assetAmounts: new uint256[](1),
            assetTypes: new uint256[](1),
            actionBalances: new uint256[](0)
        });

        assetDataIn.assets[0] = address(mockERC20.token1);
        assetDataIn.assetTypes[0] = 0;
        assetDataOut.assetIds[0] = 0;

        ActionData memory transferFromOwner;

        bytes memory callData = abi.encode(assetDataOut, transferFromOwner, assetDataIn, to, data);

        //Do swap on leverage
        vm.prank(users.accountOwner);
        pool.doActionWithLeverage(stableMargin, address(proxyAccount), address(action), callData, emptyBytes3);

        assertEq(mockERC20.stable1.balanceOf(address(pool)), type(uint128).max - stableMargin);
        assertEq(mockERC20.stable1.balanceOf(address(multiActionMock)), stableIn);
        assertEq(mockERC20.token1.balanceOf(address(proxyAccount)), tokenOut);
        assertEq(debt.balanceOf(address(proxyAccount)), uint256(stableDebt) + stableMargin);
    }
}
