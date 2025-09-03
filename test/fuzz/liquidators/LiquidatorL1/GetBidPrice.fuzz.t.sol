/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";
import { AccountV1Extension } from "../../../../lib/accounts-v2/test/utils/extensions/AccountV1Extension.sol";
import { AssetValueAndRiskFactors } from "../../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { AssetValuationLib } from "../../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { stdError } from "../../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "getBidPrice" of contract "LiquidatorL1".
 */
contract GetBidPrice_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_bid_AssetAmountsShorter(address bidder, uint112 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);

        // When Then: Bid is called with the assetAmounts that is not the same as auction, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(stdError.indexOOBError);
        liquidator_.getBidPrice(address(account), new uint256[](0));
        vm.stopPrank();
    }

    function testFuzz_Success_getBidPrice_notInAuction() public {
        uint256[] memory assetAmounts_ = new uint256[](2);

        // When : Calling getBidPrice on an Account that is not in liquidation
        (uint256 price, bool inAuction) = liquidator_.getBidPrice(address(account), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, false);
        assertEq(price, 0);
    }

    function testFuzz_Success_getBidPrice_fullLiquidation_checkValues() public {
        uint256 amountToken1 = 1000 * 1e18;
        uint256 amountStable1 = 1000 * 6000 * 1e6;

        // Given : No exposure limits
        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(pool), address(mockERC20.token1), 0, type(uint112).max, 1e4, 1e4
        );

        // And : Account has debt
        depositERC20InAccount(account, mockERC20.stable1, amountStable1);
        depositERC20InAccount(account, mockERC20.token1, amountToken1);

        uint256 valueInNumeraire;
        uint256[] memory assetAmounts_ = new uint256[](2);
        {
            address[] memory assetAddresses_ = new address[](2);
            assetAddresses_[0] = address(mockERC20.token1);
            assetAddresses_[1] = address(mockERC20.stable1);

            uint256[] memory assetIds_ = new uint256[](2);

            assetAmounts_[0] = amountToken1;
            assetAmounts_[1] = amountStable1;

            valueInNumeraire = registry_.getTotalValue(
                address(mockERC20.stable1), address(pool), assetAddresses_, assetIds_, assetAmounts_
            );

            vm.prank(users.liquidityProvider);
            mockERC20.stable1.approve(address(pool), type(uint256).max);
            vm.prank(address(srTranche));
            pool.depositInLendingPool(valueInNumeraire, users.liquidityProvider);

            // Borrow half of account value
            bytes3 emptyBytes3;
            vm.prank(users.accountOwner);
            pool.borrow(valueInNumeraire, address(account), users.accountOwner, emptyBytes3);
        }

        // And : Account is liquidatable (price of collateral asset token1 drops)
        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd / 10));

        // And : Account gets liquidated and auction is initiated
        vm.startPrank(address(123));
        liquidator_.liquidateAccount(address(account));

        (uint128 startDebt,,,) = liquidator_.getAuctionInformationPartOne(address(account));

        // assetAmounts have to be in the right order (inverse order as when deposited)
        assetAmounts_[0] = amountStable1;
        assetAmounts_[1] = amountToken1;

        // When : Calling getBidPrice of full amount
        (uint256 price, bool inAuction) = liquidator_.getBidPrice(address(account), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, true);
        assertGt(price, startDebt);

        vm.warp(block.timestamp + 2 hours);
        (price,) = liquidator_.getBidPrice(address(account), assetAmounts_);
        assertLt(price, startDebt);

        vm.stopPrank();
    }

    function testFuzz_Success_getBidPrice_partialLiquidation_checkValues() public {
        uint256 amountToken1 = 1000 * 1e18;
        uint256 amountStable1 = 1000 * 6000 * 1e6;

        // Given : No exposure limits
        vm.prank(users.riskManager);
        registry_.setRiskParametersOfPrimaryAsset(
            address(pool), address(mockERC20.token1), 0, type(uint112).max, 1e4, 1e4
        );

        // And : Account has debt
        depositERC20InAccount(account, mockERC20.stable1, amountStable1);
        depositERC20InAccount(account, mockERC20.token1, amountToken1);

        uint256 valueInNumeraire;
        uint256[] memory assetAmounts_ = new uint256[](2);
        {
            address[] memory assetAddresses_ = new address[](2);
            assetAddresses_[0] = address(mockERC20.token1);
            assetAddresses_[1] = address(mockERC20.stable1);

            uint256[] memory assetIds_ = new uint256[](2);

            assetAmounts_[0] = amountToken1;
            assetAmounts_[1] = amountStable1;

            valueInNumeraire = registry_.getTotalValue(
                address(mockERC20.stable1), address(pool), assetAddresses_, assetIds_, assetAmounts_
            );

            vm.prank(users.liquidityProvider);
            mockERC20.stable1.approve(address(pool), type(uint256).max);
            vm.prank(address(srTranche));
            pool.depositInLendingPool(valueInNumeraire, users.liquidityProvider);

            // Borrow half of account value
            bytes3 emptyBytes3;
            vm.prank(users.accountOwner);
            pool.borrow(valueInNumeraire, address(account), users.accountOwner, emptyBytes3);
        }

        // And : Account is liquidatable (price of collateral asset token1 drops)
        vm.startPrank(users.transmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd / 10));

        // And : Account gets liquidated and auction is initiated
        vm.startPrank(address(123));
        liquidator_.liquidateAccount(address(account));

        (uint128 startDebt,,,) = liquidator_.getAuctionInformationPartOne(address(account));

        // assetAmounts have to be in the right order (inverse order as when deposited)
        // We want to liquidate half of the assets in the Account
        assetAmounts_[0] = amountStable1 / 2;
        assetAmounts_[1] = amountToken1 / 2;

        // When : Calling getBidPrice of half the initial amounts deposited in the Accounts
        (uint256 price, bool inAuction) = liquidator_.getBidPrice(address(account), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, true);
        assertGt(price, startDebt / 2);

        vm.warp(block.timestamp + 2 hours);
        (price,) = liquidator_.getBidPrice(address(account), assetAmounts_);
        assertLt(price, startDebt / 2);

        vm.stopPrank();
    }
}
