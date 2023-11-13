/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { DebtToken } from "../../src/DebtToken.sol";
import { InterestRateModule } from "../../src/InterestRateModule.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { LendingPoolGuardian } from "../../src/guardians/LendingPoolGuardian.sol";
import { Liquidator } from "../../src/Liquidator.sol";
import { Liquidator } from "../../src/Liquidator.sol";
import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

/* //////////////////////////////////////////////////////////////
                        DEBT TOKEN
////////////////////////////////////////////////////////////// */

contract DebtTokenExtension is DebtToken {
    constructor(ERC20 asset_) DebtToken(asset_) { }

    function deposit_(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = _deposit(assets, receiver);
    }

    function withdraw_(uint256 assets, address receiver, address owner_) public returns (uint256 shares) {
        shares = _withdraw(assets, receiver, owner_);
    }

    function totalAssets() public view override returns (uint256 totalDebt) {
        totalDebt = realisedDebt;
    }

    function getRealisedDebt() public view returns (uint256) {
        return realisedDebt;
    }

    function getBorrowCap() public view returns (uint256) {
        return borrowCap;
    }

    function setRealisedDebt(uint256 realisedDebt_) public {
        realisedDebt = realisedDebt_;
    }
}

/* //////////////////////////////////////////////////////////////
                    INTEREST RATE MODULE
////////////////////////////////////////////////////////////// */

contract InterestRateModuleExtension is InterestRateModule {
    //Extensions to test internal functions

    function setInterestConfig(InterestRateConfiguration calldata newConfig) public {
        _setInterestConfig(newConfig);
    }

    function calculateInterestRate(uint256 utilisation) public view returns (uint256) {
        return _calculateInterestRate(utilisation);
    }

    function updateInterestRate(uint256 realisedDebt_, uint256 totalRealisedLiquidity_) public {
        return _updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
    }
}

/* //////////////////////////////////////////////////////////////
                        LENDING POOL
////////////////////////////////////////////////////////////// */

contract LendingPoolExtension is LendingPool {
    constructor(address riskManager_, ERC20 asset_, address treasury_, address accountFactory_, address liquidator_)
        LendingPool(riskManager_, asset_, treasury_, accountFactory_, liquidator_)
    { }

    function popTranche(uint256 index, address tranche) public {
        _popTranche(index, tranche);
    }

    function syncInterestsToLendingPool(uint128 assets) public {
        _syncInterestsToLiquidityProviders(assets);
    }

    function syncLiquidationFeeToLiquidityProviders(uint128 assets) public {
        _syncLiquidationFeeToLiquidityProviders(assets);
    }

    function processDefault(uint256 assets) public {
        _processDefault(assets);
    }

    function syncInterests() public {
        _syncInterests();
    }

    function setTotalRealisedLiquidity(uint128 totalRealisedLiquidity_) public {
        totalRealisedLiquidity = totalRealisedLiquidity_;
    }

    function setLastSyncedTimestamp(uint32 lastSyncedTimestamp_) public {
        lastSyncedTimestamp = lastSyncedTimestamp_;
    }

    function setRealisedDebt(uint256 realisedDebt_) public {
        realisedDebt = realisedDebt_;
    }

    function setInterestRate(uint256 interestRate_) public {
        interestRate = interestRate_;
    }

    function setIsValidVersion(uint256 version, bool allowed) public {
        isValidVersion[version] = allowed;
    }

    function numberOfTranches() public view returns (uint256) {
        return tranches.length;
    }

    function setAuctionsInProgress(uint16 amount) public {
        auctionsInProgress = amount;
    }

    function setLiquidationInitiator(address account, address initiator) public {
        liquidationInitiator[account] = initiator;
    }

    function setInterestWeight(address tranche, uint256 interestWeight_) public {
        interestWeight[tranche] = interestWeight_;
    }

    function setRealisedLiquidityOf(address tranche, uint256 amount) public {
        realisedLiquidityOf[tranche] = amount;
    }

    function getLastSyncedTimestamp() public view returns (uint32 lastSyncedTimestamp_) {
        lastSyncedTimestamp_ = lastSyncedTimestamp;
    }

    function getOriginationFee() public view returns (uint8 originationFee_) {
        originationFee_ = originationFee;
    }

    function getTotalInterestWeight() public view returns (uint24 totalInterestWeight_) {
        totalInterestWeight_ = totalInterestWeight;
    }

    function getInterestWeightTreasury() public view returns (uint16 interestWeightTreasury_) {
        interestWeightTreasury_ = interestWeightTreasury;
    }

    function getTotalLiquidationWeight() public view returns (uint24 totalLiquidationWeight_) {
        totalLiquidationWeight_ = totalLiquidationWeight;
    }

    function getLiquidationWeightTreasury() public view returns (uint16 liquidationWeightTreasury_) {
        liquidationWeightTreasury_ = liquidationWeightTreasury;
    }

    function getFixedLiquidationCost() public view returns (uint96) {
        return fixedLiquidationCost;
    }

    function getMaxInitiatorFee() public view returns (uint80) {
        return maxInitiatorFee;
    }

    function getMaxClosingFee() public view returns (uint80) {
        return maxClosingFee;
    }

    function getAuctionsInProgress() public view returns (uint16) {
        return auctionsInProgress;
    }

    function getTreasury() public view returns (address) {
        return treasury;
    }

    function getIsTranche(address tranche) public view returns (bool) {
        return isTranche[tranche];
    }

    function getInterestWeight(address tranche) public view returns (uint256) {
        return interestWeight[tranche];
    }

    function getLiquidationInitiator(address account) public view returns (address inititator) {
        return liquidationInitiator[account];
    }

    function getInterestWeightTranches(uint16 id) public view returns (uint16) {
        return interestWeightTranches[id];
    }

    function getLiquidationWeightTranches(uint16 id) public view returns (uint16) {
        return liquidationWeightTranches[id];
    }

    function getTranches(uint16 id) public view returns (address) {
        return tranches[id];
    }

    function getAccountFactory() public view returns (address) {
        return accountFactory;
    }

    function getLiquidator() public view returns (address) {
        return liquidator;
    }

    function getBorrowCap() public view returns (uint256) {
        return borrowCap;
    }

    function getYearlySeconds() public pure returns (uint256) {
        return YEARLY_SECONDS;
    }

    function setOpenPosition(address account, uint128 amount) public {
        balanceOf[account] = amount;
    }

    function setMaxLiquidationFees_(uint80 maxInitiatorFee_, uint80 maxClosingFee_) public {
        maxInitiatorFee = maxInitiatorFee_;
        maxClosingFee = maxClosingFee_;
    }
}

/* //////////////////////////////////////////////////////////////
                    LENDING POOL GUARDIAN
////////////////////////////////////////////////////////////// */

contract LendingPoolGuardianExtension is LendingPoolGuardian {
    constructor() LendingPoolGuardian() { }

    function setPauseTimestamp(uint256 pauseTimestamp_) public {
        pauseTimestamp = pauseTimestamp_;
    }

    function setFlags(
        bool repayPaused_,
        bool withdrawPaused_,
        bool borrowPaused_,
        bool depositPaused_,
        bool liquidationPaused_
    ) public {
        repayPaused = repayPaused_;
        withdrawPaused = withdrawPaused_;
        borrowPaused = borrowPaused_;
        depositPaused = depositPaused_;
        liquidationPaused = liquidationPaused_;
    }

    function isRepayPaused() public view returns (bool) {
        return repayPaused;
    }

    function isBorrowPaused() public view returns (bool) {
        return borrowPaused;
    }

    function isLiquidationPaused() public view returns (bool) {
        return liquidationPaused;
    }
}

/* //////////////////////////////////////////////////////////////
                        LIQUIDATOR
////////////////////////////////////////////////////////////// */

contract LiquidatorExtension is Liquidator {
    constructor(address factory_) Liquidator(factory_) { }

    function getAuctionInformationPartOne(address account_)
        public
        view
        returns (
            address originalOwner_,
            uint128 openDebt_,
            uint32 startTime_,
            uint256 totalBids_,
            bool inAuction_,
            address initiator_,
            uint80 liquidationInitiatorReward_,
            uint80 auctionClosingReward_,
            uint8 liquidationPenaltyWeight_
        )
    {
        originalOwner_ = auctionInformation[account_].originalOwner;
        openDebt_ = auctionInformation[account_].startDebt;
        startTime_ = auctionInformation[account_].startTime;
        totalBids_ = auctionInformation[account_].totalBids;
        inAuction_ = auctionInformation[account_].inAuction;
        initiator_ = auctionInformation[account_].initiator;
        liquidationInitiatorReward_ = auctionInformation[account_].liquidationInitiatorReward;
        auctionClosingReward_ = auctionInformation[account_].auctionClosingReward;
        liquidationPenaltyWeight_ = auctionInformation[account_].liquidationPenaltyWeight;
    }

    function getAuctionInformationPartTwo(address account_)
        public
        view
        returns (
            uint16 cutoffTime_,
            address trustedCreditor_,
            address[] memory assetAddresses_,
            uint32[] memory assetShares_,
            uint256[] memory assetAmounts_,
            uint256[] memory assetIds_
        )
    {
        cutoffTime_ = auctionInformation[account_].cutoffTime;
        trustedCreditor_ = auctionInformation[account_].trustedCreditor;
        assetAddresses_ = auctionInformation[account_].assetAddresses;
        assetShares_ = auctionInformation[account_].assetShares;
        assetAmounts_ = auctionInformation[account_].assetAmounts;
        assetIds_ = auctionInformation[account_].assetIds;
    }

    function getLocked() public view returns (uint256) {
        return locked;
    }

    function getAuctionIsActive(address account) public view returns (bool) {
        return auctionInformation[account].inAuction;
    }

    function getAuctionStartPrice(address account) public view returns (uint256) {
        return _calculateStartPrice(auctionInformation[account].startDebt, startPriceMultiplier);
    }

    function getBase() public view returns (uint64) {
        return base;
    }

    function getCutoffTime() public view returns (uint16) {
        return cutoffTime;
    }

    function getMinPriceMultiplier() public view returns (uint64) {
        return minPriceMultiplier;
    }

    function getStartPriceMultiplier() public view returns (uint16) {
        return startPriceMultiplier;
    }

    function getPenaltyWeight() public view returns (uint8) {
        return penaltyWeight;
    }

    function getInitiatorRewardWeight() public view returns (uint8) {
        return initiatorRewardWeight;
    }

    function calculateAskPrice(address account, uint256[] memory askedAssetAmounts, uint256[] memory askedAssetIds)
        public
        view
        returns (uint256)
    {
        AuctionInformation memory auctionInformation_ = auctionInformation[account];
        return _calculateAskPrice(auctionInformation_, askedAssetAmounts, askedAssetIds);
    }

    function calculateAskPrice(
        uint256[] memory askedAssetAmounts,
        uint256[] memory askedAssetIds,
        uint32[] memory assetShares,
        uint256[] memory assetAmounts,
        uint128 startPrice,
        uint256 timePassed
    ) public view returns (uint256) {
        return _calculateAskPrice(askedAssetAmounts, askedAssetIds, assetShares, assetAmounts, startPrice, timePassed);
    }

    function getClosingRewardWeight() public view returns (uint8) {
        return closingRewardWeight;
    }

    function getAssetDistribution(RiskModule.AssetValueAndRiskFactors[] memory riskValues_)
        public
        pure
        returns (uint32[] memory assetDistribution)
    {
        return _getAssetDistribution(riskValues_);
    }

    function getAuctionTotalBids(address account) public view returns (uint256) {
        return auctionInformation[account].totalBids;
    }

    function getAuctionAssetAmounts(address account) public view returns (uint256[] memory) {
        return auctionInformation[account].assetAmounts;
    }

    function setTotalBidsOnAccount(address account, uint256 totalBids_) public {
        auctionInformation[account].totalBids = totalBids_;
    }

    function getOwner(address account) public view returns (address) {
        return auctionInformation[account].originalOwner;
    }

    function setLocked(uint256 locked_) external {
        locked = locked_;
    }

    function getInAuction(address account) external returns (bool) {
        return auctionInformation[account].inAuction;
    }
}
