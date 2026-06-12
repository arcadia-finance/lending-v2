/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { LiquidatorL1_Fuzz_Test } from "./_LiquidatorL1.fuzz.t.sol";
import { Bidder } from "../../../utils/mocks/Bidder.sol";
import { LiquidatorErrors } from "../../../../src/libraries/Errors.sol";
import { RegistryErrors } from "../../../../lib/accounts-v2/src/libraries/Errors.sol";
import { stdError } from "../../../../lib/accounts-v2/lib/forge-std/src/StdError.sol";

/**
 * @notice Fuzz tests for the function "bid" of contract "LiquidatorL1".
 */
// forge-lint: disable-next-item(divide-before-multiply)
contract Bid_LiquidatorL1_Fuzz_Test is LiquidatorL1_Fuzz_Test {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        LiquidatorL1_Fuzz_Test.setUp();

        // Set grace period to 0.
        vm.prank(users.riskManager);
        registry_.setRiskParameters(address(pool), 0, type(uint64).max);
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_bid_NotForSale2(address bidder, address account_, bytes memory data) public {
        // Given: Account is not in the auction
        uint256[] memory assetAmounts = new uint256[](1);
        bool endAuction = false;

        // When Then: Bid is called, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(LiquidatorErrors.NotForSale.selector);
        liquidator_.bid(address(account_), assetAmounts, endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_FromContract_AssetAmountsShorter(uint112 amountLoaned, bytes memory data) public {
        // Given: bidder is a contract without correct interface.
        address bidder = address(srTranche);

        // And: The account auction is initiated
        vm.assume(amountLoaned > 3);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        vm.startPrank(bidder);
        vm.expectRevert(stdError.indexOOBError);
        liquidator_.bid(address(account), new uint256[](0), endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_AssetAmountsLonger(address bidder, uint112 amountLoaned, bytes memory data) public {
        // Given: The account auction is initiated
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        // When Then: Bid is called with the assetAmounts that is not the same as auction, It should revert
        vm.startPrank(bidder);
        vm.expectRevert(RegistryErrors.LengthMismatch.selector);
        liquidator_.bid(address(account), new uint256[](2), endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_FromContract_InterfaceNotImplemented(uint112 amountLoaned, bytes memory data) public {
        // Given: bidder is a contract without correct interface.
        address bidder = address(srTranche);

        // And: The account auction is initiated
        vm.assume(amountLoaned > 3);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = amountLoaned / 4;

        vm.startPrank(bidder);
        vm.expectRevert(bytes(""));
        liquidator_.bid(address(account), bidAssetAmounts, endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_FromEOA_NoFundsBidder(address bidder, uint112 amountLoaned, bytes memory data) public {
        // Given: Bidder is not a contract.
        vm.assume(bidder.code.length == 0);

        // And: The account auction is initiated
        vm.assume(bidder != address(0) && bidder != users.liquidityProvider && bidder != address(srTranche));
        vm.assume(amountLoaned > 3);
        vm.assume(amountLoaned <= (type(uint112).max / 150) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = amountLoaned / 4;

        vm.startPrank(bidder);
        vm.expectRevert("TRANSFER_FROM_FAILED");
        liquidator_.bid(address(account), bidAssetAmounts, endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Revert_bid_FromEOA_NotApprovedLending(address bidder, uint112 amountLoaned, bytes memory data)
        public
    {
        // Given: Bidder is not a contract.
        vm.assume(bidder.code.length == 0);

        // And: The account auction is initiated
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
        liquidator_.bid(address(account), bidAssetAmounts, endAuction, data);
        vm.stopPrank();
    }

    function testFuzz_Success_bid_FromEOA(
        address bidder,
        uint112 amountLoaned,
        uint32 liquidationStartTime,
        bytes memory data
    ) public {
        // Given: Bidder is not a contract.
        vm.assume(bidder.code.length == 0);

        vm.assume(bidder != address(0));
        vm.assume(amountLoaned > 12);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);

        // Given: Sequencer did not go down during the auction.
        liquidationStartTime =
            uint32(bound(liquidationStartTime, 2 days, type(uint32).max - liquidator_.getCutoffTime()));

        // And: The account auction is initiated
        // We transmit price to token 1 oracle in order to have the oracle active.
        vm.warp(liquidationStartTime);
        vm.prank(users.transmitter);
        mockOracles.stable1ToUsd.transmit(int256(rates.stable1ToUsd));
        initiateLiquidation(amountLoaned);

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory originalAssetAmounts = liquidator_.getAuctionAssetAmounts(address(account));
        uint256 originalAmount = originalAssetAmounts[0];
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount / 3;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: Bidder bids for the asset
        liquidator_.bid(address(account), bidAssetAmounts, false, data);
        vm.stopPrank();

        // Then: The auction did not restart.
        (,, uint32 startTime,) = liquidator_.getAuctionInformationPartOne(address(account));
        assertEq(startTime, liquidationStartTime);
    }

    function testFuzz_Success_bid_FromEOA_partially(address bidder, uint112 amountLoaned, bytes memory data) public {
        // Given: Bidder is not a contract.
        vm.assume(bidder.code.length == 0);

        // And: The account auction is initiated
        vm.assume(bidder != address(0));
        vm.assume(amountLoaned > 12);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory originalAssetAmounts = liquidator_.getAuctionAssetAmounts(address(account));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount / 3;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // When: Bidder bids for the asset
        liquidator_.bid(address(account), bidAssetAmounts, endAuction, data);
        vm.stopPrank();

        // And: Auction is still going on since the bidder did not choose the end the endAuction
        bool inAuction = liquidator_.getInAuction(address(account));
        assertEq(inAuction, true);
    }

    function testFuzz_Success_bid_FromEOA_full_earlyTerminate(address bidder, uint112 amountLoaned, bytes memory data)
        public
    {
        vm.startPrank(users.owner);
        pool.setLiquidationParameters(2, 2, 5, 0, type(uint80).max);

        // Given: Bidder is not a contract.
        vm.assume(bidder.code.length == 0);

        // And: The account auction is initiated
        vm.assume(bidder != address(0));
        vm.assume(amountLoaned > 2);
        vm.assume(amountLoaned <= (type(uint112).max / 300) * 100);
        initiateLiquidation(amountLoaned);
        bool endAuction = false;

        uint256[] memory originalAssetAmounts = liquidator_.getAuctionAssetAmounts(address(account));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder has enough funds and approved the lending pool for repay
        uint256[] memory bidAssetAmounts = new uint256[](1);
        uint256 bidAssetAmount = originalAmount;
        bidAssetAmounts[0] = bidAssetAmount;
        deal(address(mockERC20.stable1), bidder, type(uint128).max);
        vm.startPrank(bidder);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        uint256 askedShare = liquidator_.calculateTotalShare(address(account), bidAssetAmounts);
        uint256 askPrice_ = liquidator_.calculateBidPrice(address(account), askedShare);
        assertGt(askPrice_, uint256(amountLoaned));

        // When: Bidder bids for the asset
        liquidator_.bid(address(account), bidAssetAmounts, endAuction, data);
        vm.stopPrank();

        // And: Auction should be ended since the bidder paid all the debt
        bool inAuction = liquidator_.getInAuction(address(account));
        assertEq(inAuction, false);
    }

    function testFuzz_Success_bid_FromContract_Partial(uint112 amountLoaned, uint112 bidAssetAmount, bytes memory data)
        public
    {
        // Given: Bidder is a contract.
        Bidder bidder = new Bidder();

        // And: The account auction is initiated
        amountLoaned = uint112(bound(amountLoaned, 1, type(uint112).max - 1));
        initiateLiquidation(amountLoaned);

        uint256[] memory originalAssetAmounts = liquidator_.getAuctionAssetAmounts(address(account));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder does a partial liquidation.
        bidAssetAmount = uint112(bound(bidAssetAmount, 0, originalAmount - 1));
        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = bidAssetAmount;

        // And: Bidder has enough funds and approved the lending pool for repay
        deal(address(mockERC20.stable1), address(bidder), type(uint128).max);
        vm.startPrank(address(bidder));
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // Create expected call.
        uint256 totalShare = liquidator_.calculateTotalShare(address(account), bidAssetAmounts);
        uint256 price = liquidator_.calculateBidPrice(address(account), totalShare);
        // Debt must decrease.
        vm.assume(pool.previewWithdraw(price) > 0);
        bytes memory data_ = abi.encodeCall(bidder.bidCallback, (bidAssetAmounts, price, data));

        // Get Initial balances.
        uint256 initialBalancePool = mockERC20.stable1.balanceOf(address(pool));
        uint256 initialBalanceBidder = mockERC20.stable1.balanceOf(address(bidder));

        // When: Bidder bids for the asset
        // Then: Bidder contract gets called with the actual amounts transferred and actual bid price.
        vm.expectCall(address(bidder), data_);
        liquidator_.bid(address(account), bidAssetAmounts, false, data);
        vm.stopPrank();

        // And: Tokens are transferred.
        assertEq(mockERC20.stable1.balanceOf(address(pool)), initialBalancePool + price);
        // ToDo: collateral and numeraire are both stable1 -> balance of bidder increases and decreases -> use two different tokens.
        assertEq(mockERC20.stable1.balanceOf(address(bidder)), initialBalanceBidder - price + bidAssetAmount);
    }

    function testFuzz_Success_bid_FromContract_BidExceeding(
        uint112 amountLoaned,
        uint112 bidAssetAmount,
        bytes memory data
    ) public {
        // Given: Bidder is a contract.
        Bidder bidder = new Bidder();

        // And: The account auction is initiated
        amountLoaned = uint112(bound(amountLoaned, 1, type(uint112).max - 1));
        initiateLiquidation(amountLoaned);

        uint256[] memory originalAssetAmounts = liquidator_.getAuctionAssetAmounts(address(account));
        uint256 originalAmount = originalAssetAmounts[0];

        // And: Bidder does a partial liquidation.
        bidAssetAmount = uint112(bound(bidAssetAmount, originalAmount, type(uint112).max));
        uint256[] memory bidAssetAmounts = new uint256[](1);
        bidAssetAmounts[0] = bidAssetAmount;

        // And: Bidder has enough funds and approved the lending pool for repay
        deal(address(mockERC20.stable1), address(bidder), type(uint128).max);
        vm.startPrank(address(bidder));
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        // Create expected call.
        uint256 totalShare = liquidator_.calculateTotalShare(address(account), originalAssetAmounts);
        uint256 price = liquidator_.calculateBidPrice(address(account), totalShare);
        // Debt must decrease.
        vm.assume(pool.previewWithdraw(price) > 0);
        bytes memory data_ = abi.encodeCall(bidder.bidCallback, (originalAssetAmounts, price, data));

        // Get Initial balances.
        uint256 initialBalancePool = mockERC20.stable1.balanceOf(address(pool));
        uint256 initialBalanceBidder = mockERC20.stable1.balanceOf(address(bidder));

        // When: Bidder bids for the asset
        // Then: Bidder contract gets called with the actual amounts transferred and actual bid price.
        vm.expectCall(address(bidder), data_);
        liquidator_.bid(address(account), bidAssetAmounts, false, data);
        vm.stopPrank();

        // And: Tokens are transferred.
        assertEq(mockERC20.stable1.balanceOf(address(pool)), initialBalancePool + price);
        // ToDo: collateral and numeraire are both stable1 -> balance of bidder increases and decreases -> use two different tokens.
        assertEq(mockERC20.stable1.balanceOf(address(bidder)), initialBalanceBidder - price + originalAmount);
    }
}
