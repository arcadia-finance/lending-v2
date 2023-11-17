/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AccountV1Malicious } from "../../utils/mocks/AccountV1Malicious.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";
import { AccountV1 } from "accounts-v2/src/AccountV1.sol";
import { FixedPointMathLib } from "../../../lib/solmate/src/utils/FixedPointMathLib.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract LiquidateAccount_Liquidator_Fuzz_Test is Liquidator_Fuzz_Test {
    using FixedPointMathLib for uint256;
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_liquidateAccount_AuctionOngoing(address liquidationInitiator, uint128 amountLoaned)
        public
    {
        // Given: Account auction is already started
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // And: Pool rewards are set to zero
        vm.prank(users.creatorAddress);
        pool.setWeights(0, 0, 0);

        vm.prank(liquidationInitiator);
        liquidator.liquidateAccount(address(proxyAccount));

        bool isAuctionActive = liquidator.getAuctionIsActive(address(proxyAccount));
        assertEq(isAuctionActive, true);

        assertGe(pool.getAuctionsInProgress(), 1);

        // When Then: Liquidation Initiator calls liquidateAccount again, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(Liquidator_AuctionOngoing.selector);
        liquidator.liquidateAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_Account_Not_Exist(address liquidationInitiator, address account_)
        public
    {
        // Given: Account does not exist
        vm.assume(account_ != address(proxyAccount));
        // When Then: Liquidate Account is called, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator.liquidateAccount(address(account_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NoCreditorInAccount(address liquidationInitiator) public {
        // Given: Account is there and no creditor
        address proxyAddress_NoCreditor = factory.createAccount(2, 0, address(0), address(0));
        AccountV1 proxyAccount_ = AccountV1(proxyAddress_NoCreditor);

        // When Then: Liquidator tries to liquidate, It should revert because there is no creditor to call to get the account debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator.liquidateAccount(address(proxyAccount_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_NoDebt(address liquidationInitiator) public {
        // Given: Account has no debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(LendingPool_IsNotAnAccountWithDebt.selector);
        liquidator.liquidateAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_Healthy(
        address liquidationInitiator,
        uint128 amountLoaned
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 0);
        vm.assume(amountLoaned <= type(uint128).max - 2); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // And: Pool rewards are set to zero
        vm.prank(users.creatorAddress);
        pool.setWeights(0, 0, 0);

        // When Then: Liquidation Initiator calls liquidateAccount, Account is not liquidatable
        vm.prank(liquidationInitiator);
        vm.expectRevert("A_CASL: Account not liquidatable");
        liquidator.liquidateAccount(address(proxyAccount));
    }

    function testFuzz_Success_liquidateAccount_MaliciousAccount_MaliciousCreditor_NoHarmToProtocol(
        address liquidationInitiator,
        uint128 totalOpenDebt,
        uint128 valueInBaseCurrency,
        uint256 collateralFactor,
        uint256 liquidationFactor
    ) public {
        vm.assume(valueInBaseCurrency > 0);
        vm.assume(totalOpenDebt > 0);
        // Given: Malicious Lending pool
        LendingPoolMalicious pool_malicious = new LendingPoolMalicious();

        // And: AccountV1Malicious is created
        AccountV1Malicious maliciousAccount =
        new AccountV1Malicious(address(pool_malicious), totalOpenDebt, valueInBaseCurrency, collateralFactor, liquidationFactor);

        // When Then: Liquidation Initiator calls liquidateAccount, It will succeed
        vm.prank(liquidationInitiator);
        liquidator.liquidateAccount(address(maliciousAccount));

        // And: No harm to protocol
        // Since lending pool is maliciousAccount, it will not represent the real value in the protocol
        // So, no harm to protocol

        // Then: Auction will be set but lending pool will not be in auction mode
        bool isAuctionActive = liquidator.getAuctionIsActive(address(maliciousAccount));
        assertEq(isAuctionActive, true);

        assertGe(pool.getAuctionsInProgress(), 0);
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_ONE(
        uint128 amountLoaned,
        uint16 initiatorRewardWeight,
        uint16 penaltyWeight,
        uint16 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint32(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // Set weights
        vm.prank(users.creatorAddress);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator.liquidateAccount(address(proxyAccount));

        // Avoid stack too deep
        uint128 amountLoanedStack = amountLoaned;

        assertGe(pool.getAuctionsInProgress(), 1);

        // Then: Auction should be set and started
        (address originalOwner_, uint128 startDebt_, uint32 startTime_, bool inAuction_) =
            liquidator.getAuctionInformationPartOne(address(proxyAccount));

        assertEq(startDebt_, amountLoanedStack + 1);
        assertEq(inAuction_, true);
        assertEq(originalOwner_, users.accountOwner);
        assertEq(startTime_, block.timestamp);
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_PartTwo(
        uint128 amountLoaned,
        uint16 initiatorRewardWeight,
        uint16 penaltyWeight,
        uint16 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint256(amountLoaned) * initiatorRewardWeight <= (type(uint256).max));
        vm.assume(uint256(amountLoaned) * closingRewardWeight <= (type(uint256).max));
        vm.assume(uint256(amountLoaned) * penaltyWeight <= (type(uint256).max));
        vm.assume(uint32(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // Set weights
        vm.prank(users.creatorAddress);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator.liquidateAccount(address(proxyAccount));

        // Avoid stack too deep
        uint16 closingRewardWeightStack = closingRewardWeight;
        uint80 maxInitiatorFeeStack = maxInitiatorFee;
        uint80 maxClosingFeeStack = maxClosingFee;
        uint16 penaltyWeightStack = penaltyWeight;
        uint16 initiatorRewardWeightStack = initiatorRewardWeight;
        uint128 openDebt_ = amountLoaned + 1;

        // Then: Auction should be set and started
        (uint256 liquidationInitiatorReward_, uint256 auctionClosingReward_, uint256 liquidationPenaltyReward_) =
            pool.getCalculateRewards(openDebt_);

        uint256 liquidationInitiatorReward = uint256(openDebt_).mulDivDown(initiatorRewardWeightStack, 10_000);
        liquidationInitiatorReward =
            liquidationInitiatorReward > maxInitiatorFeeStack ? maxInitiatorFeeStack : liquidationInitiatorReward;

        assertEq(liquidationInitiatorReward, liquidationInitiatorReward_);
        uint256 closingReward = uint256(openDebt_).mulDivDown(closingRewardWeightStack, 10_000);
        closingReward = closingReward > maxClosingFeeStack ? maxClosingFeeStack : closingReward;

        uint256 liquidationPenaltyReward = uint256(openDebt_).mulDivUp(penaltyWeightStack, 10_000);

        assertEq(auctionClosingReward_, closingReward);
        assertEq(liquidationPenaltyReward, liquidationPenaltyReward_);

        // And : Liquidation incentives should have been added to openDebt of Account
        assertEq(
            pool.getOpenPosition(address(proxyAccount)),
            openDebt_ + liquidationInitiatorReward + liquidationPenaltyReward + closingReward
        );
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt_PartThree(
        uint128 amountLoaned,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee,
        address liquidationInitiator
    ) public {
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 300) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 1100);

        // Given: Account has debt
        bytes3 emptyBytes3;
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);
        vm.prank(address(srTranche));
        pool.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.prank(users.creatorAddress);
        pool.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // Set weights
        vm.prank(users.creatorAddress);
        pool.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator.liquidateAccount(address(proxyAccount));

        // Avoid stack too deep
        uint256 amountLoanedStack = amountLoaned;

        (
            uint32 cutoffTime_,
            address trustedCreditor_,
            address[] memory assetAddresses_,
            uint32[] memory assetShares_,
            uint256[] memory assetAmounts_,
            uint256[] memory assetIds_
        ) = liquidator.getAuctionInformationPartTwo(address(proxyAccount));

        assertEq(trustedCreditor_, address(pool));
        assertEq(cutoffTime_, liquidator.getCutoffTime());
        assertEq(assetAddresses_[0], address(mockERC20.stable1));
        assertEq(assetShares_[0], ONE_4);
        assertEq(assetAmounts_[0], amountLoanedStack);
        assertEq(assetIds_[0], 0);
    }
}
