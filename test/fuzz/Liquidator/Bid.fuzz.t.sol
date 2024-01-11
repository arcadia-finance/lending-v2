/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";

/**
 * @notice Fuzz tests for the function "bid" of contract "Liquidator".
 */
contract Bid_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    function initiateLiquidation(uint112 amountLoaned) public {
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

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_bid_NotForSale(address bidder, address account_) public {
        // Given: Account is not in the auction
        uint256[] memory assetAmounts = new uint256[](1);
        bool endAuction = false;

        // When Then: Bid is called, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(NotForSale.selector);
        liquidator.bid(address(account_), assetAmounts, endAuction);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_InvalidBid(address bidder, uint112 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        // When Then: Bid is called with the assetAmounts that is not the same as auction, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(InvalidBid.selector);
        liquidator.bid(address(proxyAccount), new uint256[](2), endAuction);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_NoFundsBidder(address bidder, uint112 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(bidder != address(0) && bidder != users.liquidityProvider && bidder != address(srTranche));
        vm.assume(amountLoaned > 3);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        // When Then: Bid is called with the assetAmounts that is not the same as auction, It should revert
        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = amountLoaned / 4;

        vm.startPrank(bidder);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        liquidator.bid(address(proxyAccount), bidAssetAmounts, endAuction);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_NotApprovedLending(address bidder, uint112 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(bidder != address(0));
        vm.assume(bidder != address(0) && bidder != users.liquidityProvider && bidder != address(srTranche));
        vm.assume(amountLoaned > 3);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        // When: Bidder has enough funds and bids for the asset
        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = amountLoaned / 4;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);

        // Then: Bid fails because the bidder has not approved the lending pool
        vm.startPrank(bidder);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        liquidator.bid(address(proxyAccount), bidAssetAmounts, endAuction);
        vm.stopPrank();
    }

    function testFuzz_Success_bid_partially(address bidder, uint112 amountLoaned) public {
        // Given: The account auction is initiated
        vm.assume(bidder != address(0));
        vm.assume(amountLoaned > 12);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory originalAssetAmounts = liquidator.getAuctionAssetAmounts(address(proxyAccount));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount / 3;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: Bidder bids for the asset
        liquidator.bid(address(proxyAccount), bidAssetAmounts, endAuction);
        vm.stopPrank();

        // Then: The bidder should have the asset, and left assets should be diminished
        //        uint256 totalBids = liquidator.getAuctionTotalBids(address(proxyAccount));
        //        uint256 askPrice = liquidator.calculateAskPrice(address(proxyAccount), bidAssetAmounts, new uint256[](1));
        //        assertEq(totalBids, askPrice);

        // And: Auction is still going on since the bidder did not choose the end the endAuction
        bool inAuction = liquidator.getInAuction(address(proxyAccount));
        assertEq(inAuction, true);
    }

    function testFuzz_Success_bid_full_earlyTerminate(address bidder, uint112 amountLoaned) public {
        vm.startPrank(users.creatorAddress);
        pool.setLiquidationParameters(2, 2, 5, 0, type(uint80).max);

        // Given: The account auction is initiated
        vm.assume(bidder != address(0));
        vm.assume(amountLoaned > 2);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory originalAssetAmounts = liquidator.getAuctionAssetAmounts(address(proxyAccount));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        uint256 askedShare = liquidator.calculateTotalShare(address(proxyAccount), bidAssetAmounts);
        uint256 askPrice_ = liquidator.calculateBidPrice(address(proxyAccount), askedShare);
        assertGt(askPrice_, uint256(amountLoaned));

        // When: Bidder bids for the asset
        liquidator.bid(address(proxyAccount), bidAssetAmounts, endAuction);
        vm.stopPrank();

        // Then: The bidder should have the asset, and left assets should be diminished
        //        uint256 totalBids = liquidator.getAuctionTotalBids(address(proxyAccount));
        //        uint256 askPrice = liquidator.calculateAskPrice(address(proxyAccount), bidAssetAmounts, new uint256[](1));
        //        assertEq(totalBids, askPrice);

        // And: Auction should be ended since the bidder paid all the debt
        bool inAuction = liquidator.getInAuction(address(proxyAccount));
        assertEq(inAuction, false);
    }
}
