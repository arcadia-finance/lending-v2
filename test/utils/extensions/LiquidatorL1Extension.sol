/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { AssetValueAndRiskFactors } from "../../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { LiquidatorL1 } from "../../../src/liquidators/LiquidatorL1.sol";

contract LiquidatorL1Extension is LiquidatorL1 {
    constructor(address owner_, address accountFactory) LiquidatorL1(owner_, accountFactory) { }

    function setInAuction(address account, address creditor, uint128 startDebt) public {
        auctionInformation[account].inAuction = true;
        auctionInformation[account].creditor = creditor;
        auctionInformation[account].startDebt = startDebt;
    }

    function setAssetAddresses(address account, address[] memory assetAddresses) public {
        auctionInformation[account].assetAddresses = assetAddresses;
    }

    function setAssetIds(address account, uint256[] memory assetIds) public {
        auctionInformation[account].assetIds = assetIds;
    }

    function setAssetAmounts(address account, uint256[] memory assetAmounts) public {
        auctionInformation[account].assetAmounts = assetAmounts;
    }

    function setAssetShares(address account, uint32[] memory assetShares) public {
        auctionInformation[account].assetShares = assetShares;
    }

    function getAuctionInformationPartOne(address account_)
        public
        view
        returns (uint128 startDebt_, uint32 cutoffTime_, uint32 startTime_, bool inAuction_)
    {
        startDebt_ = auctionInformation[account_].startDebt;
        cutoffTime_ = auctionInformation[account_].cutoffTime;
        startTime_ = auctionInformation[account_].startTime;
        inAuction_ = auctionInformation[account_].inAuction;
    }

    function getAuctionInformationPartTwo(address account_)
        public
        view
        returns (
            address trustedCreditor_,
            address[] memory assetAddresses_,
            uint32[] memory assetShares_,
            uint256[] memory assetAmounts_,
            uint256[] memory assetIds_
        )
    {
        trustedCreditor_ = auctionInformation[account_].creditor;
        assetAddresses_ = auctionInformation[account_].assetAddresses;
        assetShares_ = auctionInformation[account_].assetShares;
        assetAmounts_ = auctionInformation[account_].assetAmounts;
        assetIds_ = auctionInformation[account_].assetIds;
    }

    function getAuctionIsActive(address account) public view returns (bool) {
        return auctionInformation[account].inAuction;
    }

    function getBase() public view returns (uint64) {
        return base;
    }

    function getCutoffTime() public view returns (uint32) {
        return cutoffTime;
    }

    function getMinPriceMultiplier() public view returns (uint16) {
        return minPriceMultiplier;
    }

    function getStartPriceMultiplier() public view returns (uint16) {
        return startPriceMultiplier;
    }

    function calculateTotalShare(address account, uint256[] memory askedAssetAmounts) public view returns (uint256) {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        return _calculateTotalShare(auctionInformation_, askedAssetAmounts);
    }

    function calculateBidPrice(address account, uint256 askedShare) public view returns (uint256) {
        AuctionInformation storage auctionInformation_ = auctionInformation[account];
        return _calculateBidPrice(auctionInformation_, askedShare);
    }

    function getAssetShares(AssetValueAndRiskFactors[] memory riskValues_)
        public
        pure
        returns (uint32[] memory assetDistribution)
    {
        return _getAssetShares(riskValues_);
    }

    function getAuctionAssetAmounts(address account) public view returns (uint256[] memory) {
        return auctionInformation[account].assetAmounts;
    }

    function getInAuction(address account) external view returns (bool) {
        return auctionInformation[account].inAuction;
    }

    function getAssetRecipient(address creditor) external view returns (address) {
        return creditorToAccountRecipient[creditor];
    }

    function getAccountFactory() public view returns (address) {
        return ACCOUNT_FACTORY;
    }
}
