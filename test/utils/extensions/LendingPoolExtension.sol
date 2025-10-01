/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { LendingPool } from "../../../src/LendingPool.sol";

contract LendingPoolExtension is LendingPool {
    constructor(
        address owner_,
        address riskManager_,
        ERC20 asset_,
        address treasury_,
        address accountFactory,
        address liquidator_
    ) LendingPool(owner_, riskManager_, asset_, treasury_, accountFactory, liquidator_) { }

    function getCallbackAccount() public view returns (address callbackAccount_) {
        callbackAccount_ = callbackAccount;
    }

    function setCallbackAccount(address callbackAccount_) public {
        callbackAccount = callbackAccount_;
    }

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
