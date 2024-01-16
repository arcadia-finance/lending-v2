/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Scenario_Lending_Test } from "./_Scenario.t.sol";

import { LogExpMath } from "../../src/libraries/LogExpMath.sol";

import { AccountErrors } from "../../lib/accounts-v2/src/libraries/Errors.sol";
import { AssetValuationLib } from "../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { Constants } from "../../lib/accounts-v2/test/utils/Constants.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../src/libraries/Errors.sol";

/**
 * @notice Scenario tests for Borrow and Repay flows.
 */
contract BorrowAndRepay_Scenario_Test is Scenario_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Scenario_Lending_Test.setUp();

        vm.prank(users.accountOwner);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

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
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/
    function testScenario_Revert_borrow_NotAllowTooMuchCreditAfterDeposit(uint112 amountToken, uint112 amountCredit)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        vm.assume(uint256(amountCredit) * collFactor_ < type(uint128).max); //prevent overflow in takecredit with absurd values
        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit > maxCredit);

        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(users.accountOwner), 0);
    }

    function testScenario_Revert_borrow_NotAllowCreditAfterLargeUnrealizedDebt(uint112 amountToken) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        uint128 valueOfOneToken = uint128((Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals);
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        uint128 amountCredit = uint128(
            ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_ / AssetValuationLib.ONE_4
                / 10 ** (18 - Constants.stableDecimals)
        );
        vm.assume(amountCredit > 0);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();

        vm.roll(block.number + 10);
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        pool.borrow(1, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();
    }

    function testScenario_Revert_withdraw_OpenDebtIsTooLarge(
        uint112 amountToken,
        uint112 amountTokenWithdrawal,
        uint128 amountCredit
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0 && amountTokenWithdrawal > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        vm.assume(amountToken >= amountTokenWithdrawal);

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        uint256 freeMargin = proxyAccount.getFreeMargin();
        vm.assume(freeMargin > 0);
        amountCredit = uint128(bound(amountCredit, 1, freeMargin));

        vm.assume(
            freeMargin - amountCredit
                < ((amountTokenWithdrawal * valueOfOneToken) / 10 ** Constants.tokenDecimals) * collFactor_
                    / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals)
        );

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        address[] memory assets = new address[](1);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        assets[0] = address(mockERC20.token1);
        amounts[0] = amountTokenWithdrawal;
        vm.startPrank(users.accountOwner);
        vm.expectRevert(AccountErrors.AccountUnhealthy.selector);
        proxyAccount.withdraw(assets, ids, amounts);
        vm.stopPrank();
    }

    function testScenario_Success_getFreeMargin_AmountOfAllowedCredit(uint112 amountToken) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 expectedValue = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        uint256 actualValue = proxyAccount.getFreeMargin();

        assertEq(actualValue, expectedValue);
    }

    function testScenario_Success_borrow_AllowCreditAfterDeposit(uint112 amountToken, uint128 amountCredit) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        vm.assume(amountToken > 0);
        vm.assume(uint256(amountCredit) * collFactor_ < type(uint128).max); //prevent overflow in takecredit with absurd values
        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        uint256 maxCredit = (
            (valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals * collFactor_ / AssetValuationLib.ONE_4
                / 10 ** (18 - Constants.stableDecimals)
        );

        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();

        assertEq(mockERC20.stable1.balanceOf(users.accountOwner), amountCredit);
    }

    function testScenario_Success_borrow_IncreaseOfDebtPerBlock(
        uint112 amountToken,
        uint128 amountCredit,
        uint24 deltaTimestamp
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        uint256 _yearlyInterestRate = pool.interestRate();
        uint128 base = 1e18 + 5e16; //1 + r expressed as 18 decimals fixed point number
        uint128 exponent = (uint128(deltaTimestamp) * 1e18) / uint128(pool.getYearlySeconds());
        vm.assume(amountCredit < type(uint128).max / LogExpMath.pow(base, exponent));

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 maxCredit = (
            (valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals * collFactor_ / AssetValuationLib.ONE_4
                / 10 ** (18 - Constants.stableDecimals)
        );

        vm.assume(amountCredit <= maxCredit);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();

        _yearlyInterestRate = pool.interestRate();
        base = 1e18 + uint128(_yearlyInterestRate);

        uint256 debtAtStart = proxyAccount.getUsedMargin();

        vm.warp(block.timestamp + deltaTimestamp);

        uint256 actualDebt = proxyAccount.getUsedMargin();

        uint128 expectedDebt = uint128(
            (
                debtAtStart
                    * (
                        LogExpMath.pow(
                            _yearlyInterestRate + 10 ** 18, (uint256(deltaTimestamp) * 10 ** 18) / pool.getYearlySeconds()
                        )
                    )
            ) / 10 ** 18
        );

        assertEq(actualDebt, expectedDebt);
    }

    function testScenario_Success_borrow_AllowAdditionalCreditAfterPriceIncrease(
        uint112 amountToken,
        uint128 amountCredit,
        uint16 newPrice
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        vm.assume(newPrice * 10 ** Constants.tokenOracleDecimals > rates.token1ToUsd);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        uint256 valueOfOneToken = uint128((Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.startPrank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.stopPrank();

        vm.prank(users.defaultTransmitter);
        uint256 newRateTokenToUsd = newPrice * 10 ** Constants.tokenOracleDecimals;
        mockOracles.token1ToUsd.transmit(int256(newRateTokenToUsd));

        uint256 newValueOfOneEth = (Constants.WAD * newRateTokenToUsd) / 10 ** Constants.tokenOracleDecimals;
        uint256 expectedAvailableCredit = ((newValueOfOneEth * amountToken) / 10 ** Constants.tokenDecimals)
            * collFactor_ / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals) - amountCredit;

        uint256 actualAvailableCredit = proxyAccount.getFreeMargin();

        assertEq(actualAvailableCredit, expectedAvailableCredit); //no blocks pass in foundry
    }

    function testScenario_Success_withdraw_OpenDebtIsNotTooLarge(
        uint112 amountToken,
        uint112 amountTokenWithdrawal,
        uint128 amountCredit
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0 && amountTokenWithdrawal > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;
        vm.assume(amountToken >= amountTokenWithdrawal);

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        uint256 maxCredit = ((valueOfOneToken * (amountToken - amountTokenWithdrawal)) / 10 ** Constants.tokenDecimals)
            * collFactor_ / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        address[] memory assets = new address[](1);
        uint256[] memory ids = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        assets[0] = address(mockERC20.token1);
        amounts[0] = amountTokenWithdrawal;
        vm.startPrank(users.accountOwner);
        proxyAccount.withdraw(assets, ids, amounts);
        vm.stopPrank();
    }

    function testScenario_Success_syncInterests_IncreaseBalanceDebtContract(
        uint112 amountToken,
        uint128 amountCredit,
        uint24 deltaTimestamp
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        uint256 _yearlyInterestRate = pool.interestRate();

        uint256 balanceBefore = debt.totalAssets();

        vm.warp(block.timestamp + deltaTimestamp);
        uint256 balanceAfter = debt.totalAssets();

        uint128 base = uint128(_yearlyInterestRate) + 10 ** 18;
        uint128 exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.getYearlySeconds());
        uint128 expectedDebt = uint128((amountCredit * (LogExpMath.pow(base, exponent))) / 10 ** 18);
        uint128 unrealisedDebt = expectedDebt - amountCredit;

        assertEq(unrealisedDebt, balanceAfter - balanceBefore);
    }

    function testScenario_Success_repay_ExactDebt(uint112 amountToken, uint128 amountCredit, uint16 blocksToRoll)
        public
    {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        vm.assume(amountCredit > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        vm.roll(block.number + blocksToRoll);

        uint256 openDebt = proxyAccount.getUsedMargin();

        deal(address(mockERC20.stable1), users.accountOwner, openDebt, true);

        vm.prank(users.accountOwner);
        pool.repay(openDebt, address(proxyAccount));

        assertEq(proxyAccount.getUsedMargin(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxyAccount.getUsedMargin(), 0);
    }

    function testScenario_Success_repay_ExessiveDebt(
        uint112 amountToken,
        uint128 amountCredit,
        uint16 blocksToRoll,
        uint8 factor
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        vm.assume(factor > 0);
        vm.assume(amountCredit > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        deal(address(mockERC20.stable1), users.accountOwner, factor * amountCredit, true);

        vm.roll(block.number + blocksToRoll);

        uint256 openDebt = proxyAccount.getUsedMargin();
        uint256 balanceBefore = mockERC20.stable1.balanceOf(users.accountOwner);

        vm.startPrank(users.accountOwner);
        pool.repay(openDebt * factor, address(proxyAccount));
        vm.stopPrank();

        uint256 balanceAfter = mockERC20.stable1.balanceOf(users.accountOwner);

        assertEq(balanceBefore - openDebt, balanceAfter);
        assertEq(proxyAccount.getUsedMargin(), 0);

        vm.roll(block.number + uint256(blocksToRoll) * 2);
        assertEq(proxyAccount.getUsedMargin(), 0);
    }

    function testScenario_Success_repay_PartialDebt(
        uint112 amountToken,
        uint128 amountCredit,
        uint24 deltaTimestamp,
        uint128 toRepay
    ) public {
        // Given: collateralValue is smaller than maxExposure.
        amountToken = uint112(bound(amountToken, 0, type(uint112).max - 1));

        vm.assume(amountToken > 0);
        vm.assume(toRepay > 0);
        uint16 collFactor_ = Constants.tokenToStableCollFactor;

        uint256 valueOfOneToken = (Constants.WAD * rates.token1ToUsd) / 10 ** Constants.tokenOracleDecimals;
        vm.assume(amountToken < type(uint128).max / valueOfOneToken);

        uint256 maxCredit = ((valueOfOneToken * amountToken) / 10 ** Constants.tokenDecimals) * collFactor_
            / AssetValuationLib.ONE_4 / 10 ** (18 - Constants.stableDecimals);

        vm.assume(amountCredit <= maxCredit);

        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken);

        vm.prank(users.accountOwner);
        pool.borrow(amountCredit, address(proxyAccount), users.accountOwner, emptyBytes3);

        uint256 _yearlyInterestRate = pool.interestRate();

        uint256 totalLiquidity = pool.totalLiquidity();
        vm.warp(block.timestamp + deltaTimestamp);
        // total liquidity does not overflow.
        vm.assume(pool.calcUnrealisedDebt() + totalLiquidity <= type(uint128).max);

        vm.assume(toRepay < amountCredit);
        vm.assume(debt.previewWithdraw(toRepay) > 0);

        vm.prank(users.accountOwner);
        pool.repay(toRepay, address(proxyAccount));
        uint128 base = uint128(_yearlyInterestRate) + 10 ** 18;
        uint128 exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.getYearlySeconds());
        uint128 expectedDebt = uint128((amountCredit * (LogExpMath.pow(base, exponent))) / 10 ** 18) - toRepay;

        assertEq(proxyAccount.getUsedMargin(), expectedDebt);

        vm.warp(block.timestamp + deltaTimestamp);
        _yearlyInterestRate = pool.interestRate();
        base = uint128(_yearlyInterestRate) + 10 ** 18;
        exponent = uint128((uint128(deltaTimestamp) * 10 ** 18) / pool.getYearlySeconds());
        expectedDebt = uint128((expectedDebt * (LogExpMath.pow(base, exponent))) / 10 ** 18);

        assertEq(proxyAccount.getUsedMargin(), expectedDebt);
    }
}
