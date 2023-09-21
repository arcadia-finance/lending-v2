/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { LendingPool } from "../../src/LendingPool.sol";
import { Liquidator } from "../../src/Liquidator.sol";

/* //////////////////////////////////////////////////////////////
                        LENDING POOL
////////////////////////////////////////////////////////////// */

contract LendingPoolExtension is LendingPool {
    constructor(ERC20 _asset, address _treasury, address _vaultFactory, address _liquidator)
        LendingPool(_asset, _treasury, _vaultFactory, _liquidator)
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
}

/* //////////////////////////////////////////////////////////////
                            LENDING POOL
    ////////////////////////////////////////////////////////////// */

contract LiquidatorExtension is Liquidator {
    constructor(address factory_) Liquidator(factory_) { }

    function getAuctionInformationPartOne(address account_)
        public
        view
        returns (uint128 openDebt, uint32 startTime, bool inAuction, uint80 maxInitiatorFee, address baseCurrency)
    {
        openDebt = auctionInformation[account_].openDebt;
        startTime = auctionInformation[account_].startTime;
        inAuction = auctionInformation[account_].inAuction;
        maxInitiatorFee = auctionInformation[account_].maxInitiatorFee;
        baseCurrency = auctionInformation[account_].baseCurrency;
    }

    function getAuctionInformationPartTwo(address account_)
        public
        view
        returns (
            uint16 startPriceMultiplier_,
            uint8 minPriceMultiplier_,
            uint8 initiatorRewardWeight_,
            uint8 penaltyWeight_,
            uint16 cutoffTime_,
            address originalOwner,
            address trustedCreditor,
            uint64 base_
        )
    {
        startPriceMultiplier_ = auctionInformation[account_].startPriceMultiplier;
        minPriceMultiplier_ = auctionInformation[account_].minPriceMultiplier;
        initiatorRewardWeight_ = auctionInformation[account_].initiatorRewardWeight;
        penaltyWeight_ = auctionInformation[account_].penaltyWeight;
        cutoffTime_ = auctionInformation[account_].cutoffTime;
        originalOwner = auctionInformation[account_].originalOwner;
        trustedCreditor = auctionInformation[account_].trustedCreditor;
        base_ = auctionInformation[account_].base;
    }
}
