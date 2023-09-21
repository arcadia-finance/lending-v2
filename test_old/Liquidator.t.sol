/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "../lib/accounts-v2/src/test_old/fixtures/ArcadiaAccountsFixture.f.sol";

import { Liquidator } from "../src/Liquidator.sol";
import { LendingPool, DebtToken, ERC20 } from "../src/LendingPool.sol";
import { Tranche } from "../src/Tranche.sol";

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

contract LiquidatorTest is DeployArcadiaAccounts {
    using stdStorage for StdStorage;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;
    LiquidatorExtension liquidator;

    bytes3 public emptyBytes3;

    address private liquidationInitiator = address(8);
    address private auctionBuyer = address(9);

    // EVENTS
    event WeightsSet(uint8 initiatorRewardWeight, uint8 penaltyWeight);
    event AuctionCurveParametersSet(uint64 base, uint16 cutoffTime);
    event StartPriceMultiplierSet(uint16 startPriceMultiplier);
    event MinimumPriceMultiplierSet(uint8 minPriceMultiplier);
    event AuctionStarted(address indexed account, address indexed creditor, address baseCurrency, uint128 openDebt);
    event AuctionFinished(
        address indexed account,
        address indexed creditor,
        address baseCurrency,
        uint128 price,
        uint128 badDebt,
        uint128 initiatorReward,
        uint128 liquidationPenalty,
        uint128 remainder
    );

    //this is a before
    constructor() DeployArcadiaAccounts() {
        vm.startPrank(users.creatorAddress);
        liquidator = new LiquidatorExtension(address(factory));

        pool = new LendingPool(ERC20(address(dai)), users.creatorAddress, address(factory), address(liquidator));
        pool.setAccountVersion(1, true);
        pool.setMaxInitiatorFee(type(uint80).max);
        liquidator.setAuctionCurveParameters(3600, 14_400);
        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50, 0);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint64).max, liquidityProvider);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(accountOwner);
        proxyAddr = factory.createAccount(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                    )
                )
            ),
            0,
            address(0),
            address(0)
        );
        proxyAccount = AccountV1(proxyAddr);

        proxyAccount.openTrustedMarginAccount(address(pool));
        dai.approve(address(proxyAccount), type(uint256).max);

        bayc.setApprovalForAll(address(proxyAccount), true);
        mayc.setApprovalForAll(address(proxyAccount), true);
        dickButs.setApprovalForAll(address(proxyAccount), true);
        interleave.setApprovalForAll(address(proxyAccount), true);
        eth.approve(address(proxyAccount), type(uint256).max);
        link.approve(address(proxyAccount), type(uint256).max);
        snx.approve(address(proxyAccount), type(uint256).max);
        safemoon.approve(address(proxyAccount), type(uint256).max);
        dai.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.prank(auctionBuyer);
        dai.approve(address(liquidator), type(uint256).max);
    }

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/



}
