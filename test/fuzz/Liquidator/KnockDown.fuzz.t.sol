/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract EndAuction_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    function initiateLiquidation(uint128 amountLoaned) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(address(45));
        liquidator.liquidateAccount(address(proxyAccount));
    }

    function bid_fully(address bidder) public {
        uint256[] memory originalAssetAmounts = liquidator.getAuctionAssetAmounts(address(proxyAccount));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: Bidder bids for the asset
        liquidator.bid(address(proxyAccount), bidAssetAmounts, new uint256[](1), false);
        vm.stopPrank();
    }

    function bid_partially(address bidder) public {
        uint256[] memory originalAssetAmounts = liquidator.getAuctionAssetAmounts(address(proxyAccount));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount / 4;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: Bidder bids for the asset
        liquidator.bid(address(proxyAccount), bidAssetAmounts, new uint256[](1), false);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_knockDown_NotForSale(address hammer, address account_) public {
        // Given: Account is not in the auction

        // When Then: knock down is called, It should revert
        vm.startPrank(hammer);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.knockDown(address(account_));
        vm.stopPrank();
    }
    //

    function testFuzz_Revert_knockDown_InvalidBid(address hammer, uint128 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100);
        initiateLiquidation(amountLoaned);

        // And: There is no bid for the account

        // When Then: knockDown is called which account is still unhealthy, It should revert
        vm.startPrank(hammer);
        vm.expectRevert(Liquidator_AccountNotHealthy.selector);
        liquidator.knockDown(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_knockDown_Partially(address hammer, address bidder, uint128 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1000);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100);
        // And: Set the weights for the rewards
        vm.startPrank(users.creatorAddress);
        pool.setWeights(2, 5, 2);
        // And: Initiate liquidation
        initiateLiquidation(amountLoaned);

        // And: There is a bid happened and bought it partially for the account
        bid_partially(bidder);

        // When: knockDown is called which account is healthy
        vm.startPrank(hammer);
        vm.expectEmit();
        emit AuctionFinished(address(proxyAccount), address(pool), uint128(amountLoaned + 1), 0, 0);
        liquidator.knockDown(address(proxyAccount));
        vm.stopPrank();
        // Then: The account should be healthy
        assertEq(liquidator.getAuctionIsActive(address(proxyAccount)), false);
    }

    function testFuzz_Revert_knockDown_NotForSaleAfterFullyBoughtDebt(
        address hammer,
        address bidder,
        uint128 amountLoaned
    ) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 500) * 100);
        initiateLiquidation(amountLoaned);

        // And: There is a bid happened and bought it partially for the account
        bid_fully(bidder);

        // When: knockDown is called which account is healthy
        vm.startPrank(hammer);
        vm.expectRevert(Liquidator_NotForSale.selector);
        liquidator.knockDown(address(proxyAccount));
        vm.stopPrank();
        // Then: The account should be healthy
        assertEq(liquidator.getAuctionIsActive(address(proxyAccount)), false);
    }
}
