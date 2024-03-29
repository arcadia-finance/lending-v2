/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AssetValueAndRiskFactors } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { AssetValuationLib } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { stdError } from "../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "getBidPrice" of contract "Liquidator".
 */
contract GetBidPrice_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
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
        liquidator.getBidPrice(address(proxyAccount), new uint256[](0));
        vm.stopPrank();
    }

    function testFuzz_Success_getBidPrice_notInAuction() public {
        uint256[] memory assetAmounts_ = new uint256[](2);

        // When : Calling getBidPrice on an Account that is not in liquidation
        (uint256 price, bool inAuction) = liquidator.getBidPrice(address(proxyAccount), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, false);
        assertEq(price, 0);
    }

    function testFuzz_Success_getBidPrice_fullLiquidation_checkValues() public {
        uint256 amountToken1 = 1000 * 1e18;
        uint256 amountStable1 = 1000 * 6000 * 1e6;

        // Given : No exposure limits
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(pool), address(mockERC20.token1), 0, type(uint112).max, 1e4, 1e4
        );

        // And : Account has debt
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountStable1);
        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken1);

        uint256 valueInNumeraire;
        uint256[] memory assetAmounts_ = new uint256[](2);
        {
            address[] memory assetAddresses_ = new address[](2);
            assetAddresses_[0] = address(mockERC20.token1);
            assetAddresses_[1] = address(mockERC20.stable1);

            uint256[] memory assetIds_ = new uint256[](2);

            assetAmounts_[0] = amountToken1;
            assetAmounts_[1] = amountStable1;

            valueInNumeraire = registryExtension.getTotalValue(
                address(mockERC20.stable1), address(pool), assetAddresses_, assetIds_, assetAmounts_
            );

            vm.prank(users.liquidityProvider);
            mockERC20.stable1.approve(address(pool), type(uint256).max);
            vm.prank(address(srTranche));
            pool.depositInLendingPool(valueInNumeraire, users.liquidityProvider);

            // Borrow half of account value
            bytes3 emptyBytes3;
            vm.prank(users.accountOwner);
            pool.borrow(valueInNumeraire, address(proxyAccount), users.accountOwner, emptyBytes3);
        }

        // And : Account is liquidatable (price of collateral asset token1 drops)
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd / 10));

        // And : Account gets liquidated and auction is initiated
        vm.startPrank(address(123));
        liquidator.liquidateAccount(address(proxyAccount));

        (,, uint32[] memory assetShares, uint256[] memory assetAmounts,) =
            liquidator.getAuctionInformationPartTwo(address(proxyAccount));

        emit log_named_uint("assetAmounts0FromAuction", assetAmounts[0]);
        emit log_named_uint("assetAmounts1FromAuction", assetAmounts[1]);
        emit log_named_uint("assetShare0FromAuction", assetShares[0]);
        emit log_named_uint("assetShare1FromAuction", assetShares[1]);

        (uint128 startDebt,, uint32 startTime,) = liquidator.getAuctionInformationPartOne(address(proxyAccount));

        emit log_named_uint("startDebt", startDebt);
        emit log_named_uint("startTime", startTime);

        // assetAmounts have to be in the right order (inverse order as when deposited)
        assetAmounts_[0] = amountStable1;
        assetAmounts_[1] = amountToken1;

        // When : Calling getBidPrice of full amount
        (uint256 price, bool inAuction) = liquidator.getBidPrice(address(proxyAccount), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, true);
        assertGt(price, startDebt);
        emit log_named_uint("price", price);

        uint256 totalShare = liquidator.calculateTotalShare(address(proxyAccount), assetAmounts_);
        emit log_named_uint("totalShare", totalShare);

        vm.warp(block.timestamp + 2 hours);
        (price,) = liquidator.getBidPrice(address(proxyAccount), assetAmounts_);
        assertLt(price, startDebt);
        emit log_named_uint("price", price);

        vm.stopPrank();
    }

    function testFuzz_Success_getBidPrice_partialLiquidation_checkValues() public {
        uint256 amountToken1 = 1000 * 1e18;
        uint256 amountStable1 = 1000 * 6000 * 1e6;

        // Given : No exposure limits
        vm.prank(users.riskManager);
        registryExtension.setRiskParametersOfPrimaryAsset(
            address(pool), address(mockERC20.token1), 0, type(uint112).max, 1e4, 1e4
        );

        // And : Account has debt
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountStable1);
        depositTokenInAccount(proxyAccount, mockERC20.token1, amountToken1);

        uint256 valueInNumeraire;
        uint256[] memory assetAmounts_ = new uint256[](2);
        {
            address[] memory assetAddresses_ = new address[](2);
            assetAddresses_[0] = address(mockERC20.token1);
            assetAddresses_[1] = address(mockERC20.stable1);

            uint256[] memory assetIds_ = new uint256[](2);

            assetAmounts_[0] = amountToken1;
            assetAmounts_[1] = amountStable1;

            valueInNumeraire = registryExtension.getTotalValue(
                address(mockERC20.stable1), address(pool), assetAddresses_, assetIds_, assetAmounts_
            );

            vm.prank(users.liquidityProvider);
            mockERC20.stable1.approve(address(pool), type(uint256).max);
            vm.prank(address(srTranche));
            pool.depositInLendingPool(valueInNumeraire, users.liquidityProvider);

            // Borrow half of account value
            bytes3 emptyBytes3;
            vm.prank(users.accountOwner);
            pool.borrow(valueInNumeraire, address(proxyAccount), users.accountOwner, emptyBytes3);
        }

        // And : Account is liquidatable (price of collateral asset token1 drops)
        vm.startPrank(users.defaultTransmitter);
        mockOracles.token1ToUsd.transmit(int256(rates.token1ToUsd / 10));

        // And : Account gets liquidated and auction is initiated
        vm.startPrank(address(123));
        liquidator.liquidateAccount(address(proxyAccount));

        (,, uint32[] memory assetShares, uint256[] memory assetAmounts,) =
            liquidator.getAuctionInformationPartTwo(address(proxyAccount));

        emit log_named_uint("assetAmounts0FromAuction", assetAmounts[0]);
        emit log_named_uint("assetAmounts1FromAuction", assetAmounts[1]);
        emit log_named_uint("assetShare0FromAuction", assetShares[0]);
        emit log_named_uint("assetShare1FromAuction", assetShares[1]);

        (uint128 startDebt,, uint32 startTime,) = liquidator.getAuctionInformationPartOne(address(proxyAccount));

        emit log_named_uint("startDebt", startDebt);
        emit log_named_uint("startTime", startTime);

        // assetAmounts have to be in the right order (inverse order as when deposited)
        // We want to liquidate half of the assets in the Account
        assetAmounts_[0] = amountStable1 / 2;
        assetAmounts_[1] = amountToken1 / 2;

        // When : Calling getBidPrice of half the initial amounts deposited in the Accounts
        (uint256 price, bool inAuction) = liquidator.getBidPrice(address(proxyAccount), assetAmounts_);

        // Then : Values should be correct
        assertEq(inAuction, true);
        assertGt(price, startDebt / 2);
        emit log_named_uint("price", price);

        uint256 totalShare = liquidator.calculateTotalShare(address(proxyAccount), assetAmounts_);
        emit log_named_uint("totalShare", totalShare);

        vm.warp(block.timestamp + 2 hours);
        (price,) = liquidator.getBidPrice(address(proxyAccount), assetAmounts_);
        assertLt(price, startDebt / 2);
        emit log_named_uint("price", price);

        vm.stopPrank();
    }
}
