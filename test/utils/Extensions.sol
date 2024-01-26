/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { AccountV1 } from "../../lib/accounts-v2/src/accounts/AccountV1.sol";
import { AssetValueAndRiskFactors } from "../../lib/accounts-v2/src/libraries/AssetValuationLib.sol";
import { DebtToken } from "../../src/DebtToken.sol";
import { LendingPool } from "../../src/LendingPool.sol";
import { LendingPoolErrors } from "../../src/libraries/Errors.sol";
import { LendingPoolGuardian } from "../../src/guardians/LendingPoolGuardian.sol";
import { Liquidator } from "../../src/Liquidator.sol";
import { Tranche } from "../../src/Tranche.sol";

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

    function setRealisedDebt(uint256 realisedDebt_) public {
        realisedDebt = realisedDebt_;
    }
}

/* //////////////////////////////////////////////////////////////
                        LENDING POOL
////////////////////////////////////////////////////////////// */

contract LendingPoolExtension is LendingPool {
    constructor(address riskManager_, ERC20 asset_, address treasury_, address account_factory, address liquidator_)
        LendingPool(riskManager_, asset_, treasury_, account_factory, liquidator_)
    { }

    function getMaxTotalPenalty() public pure returns (uint256 maxTotalPenalty) {
        maxTotalPenalty = MAX_TOTAL_PENALTY;
    }

    function popTranche(uint256 index, address tranche) public {
        _popTranche(index, tranche);
    }

    function syncInterestsToLendingPool(uint128 assets) public {
        _syncInterestsToLiquidityProviders(assets);
    }

    function syncLiquidationFee(uint256 assets) public {
        _syncLiquidationFee(assets);
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

    function setInterestRate(uint80 interestRate_) public {
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

    function getLiquidationWeightTreasury() public view returns (uint16 liquidationWeightTreasury_) {
        liquidationWeightTreasury_ = liquidationWeightTreasury;
    }

    function getLiquidationWeightTranche() public view returns (uint16 liquidationWeightTranche_) {
        liquidationWeightTranche_ = liquidationWeightTranche;
    }

    function getMinimumMargin() public view returns (uint96) {
        return minimumMargin;
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

    function getInterestWeightTranches(uint16 id) public view returns (uint16) {
        return interestWeightTranches[id];
    }

    function getTranches(uint16 id) public view returns (address) {
        return tranches[id];
    }

    function getTranches() public view returns (address[] memory) {
        return tranches;
    }

    function getAccountFactory() public view returns (address) {
        return ACCOUNT_FACTORY;
    }

    function getLiquidator() public view returns (address) {
        return LIQUIDATOR;
    }

    function getYearlySeconds() public pure returns (uint256) {
        return YEARLY_SECONDS;
    }

    function setOpenPosition(address account, uint128 amount) public {
        balanceOf[account] = amount;
    }

    function getCalculateRewards(uint256 amount, uint256 minimumMargin_)
        public
        view
        returns (uint256, uint256, uint256)
    {
        return _calculateRewards(amount, minimumMargin_);
    }

    function settleLiquidationHappyFlow(
        address account,
        uint256 startDebt,
        uint256 minimumMargin_,
        address terminator,
        uint256 surplus
    ) external {
        _settleLiquidationHappyFlow(account, startDebt, minimumMargin_, terminator, surplus);
    }

    function getInterestRateVariables() public view returns (uint256, uint256, uint256, uint256) {
        return (baseRatePerYear, lowSlopePerYear, highSlopePerYear, utilisationThreshold);
    }

    function calculateInterestRate(uint256 utilisation) public view returns (uint256) {
        return _calculateInterestRate(utilisation);
    }

    function updateInterestRate(uint256 realisedDebt_, uint256 totalRealisedLiquidity_) public {
        return _updateInterestRate(realisedDebt_, totalRealisedLiquidity_);
    }
}

/* //////////////////////////////////////////////////////////////
                    LENDING POOL GUARDIAN
////////////////////////////////////////////////////////////// */

contract LendingPoolGuardianExtension is LendingPoolGuardian {
    constructor() LendingPoolGuardian() { }

    function setPauseTimestamp(uint256 pauseTimestamp_) public {
        pauseTimestamp = uint96(pauseTimestamp_);
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
}

/* //////////////////////////////////////////////////////////////
                        TRANCHE
////////////////////////////////////////////////////////////// */

contract TrancheExtension is Tranche {
    constructor(address lendingPool_, uint256 vas, string memory prefix_, string memory prefixSymbol_)
        Tranche(lendingPool_, vas, prefix_, prefixSymbol_)
    { }

    function getVas() public view returns (uint256 vas) {
        vas = VAS;
    }
}

/* //////////////////////////////////////////////////////////////
                        LIQUIDATOR
////////////////////////////////////////////////////////////// */

contract LiquidatorExtension is Liquidator {
    constructor(address accountFactory) Liquidator(accountFactory) { }

    function setInAuction(address account, address creditor, uint128 startDebt) public {
        auctionInformation[account].inAuction = true;
        auctionInformation[account].creditor = creditor;
        auctionInformation[account].startDebt = startDebt;
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
        returns (uint128 startDebt_, uint32 cutoffTimeStamp_, uint32 startTime_, bool inAuction_)
    {
        startDebt_ = auctionInformation[account_].startDebt;
        cutoffTimeStamp_ = auctionInformation[account_].cutoffTimeStamp;
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
