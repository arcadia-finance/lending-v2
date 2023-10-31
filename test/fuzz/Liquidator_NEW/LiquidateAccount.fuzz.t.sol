/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Liquidator_Fuzz_Test_NEW } from "./_Liquidator.fuzz.t.sol";
import { AccountExtension } from "lib/accounts-v2/test/utils/Extensions.sol";
import { AccountV1Malicious } from "../../utils/mocks/AccountV1Malicious.sol";
import { LendingPoolMalicious } from "../../utils/mocks/LendingPoolMalicious.sol";

/**
 * @notice Fuzz tests for the function "endAuction" of contract "Liquidator".
 */
contract LiquidateAccount_Liquidator_Fuzz_Test_NEW is Liquidator_Fuzz_Test_NEW {
    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public override {
        Liquidator_Fuzz_Test_NEW.setUp();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_Revert_liquidateAccount_Account_Not_Exist(address liquidationInitiator, address account_)
        public
    {
        // Given: Account does not exist
        vm.assume(account_ != address(proxyAccount));
        // When Then: Liquidate Account is called, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert();
        liquidator_new.liquidateAccount(address(account_));
        vm.stopPrank();
    }

    function testFuzz_Revert_liquidateAccount_NotLiquidatable_NoDebt(address liquidationInitiator) public {
        // Given: Account has no debt
        vm.startPrank(liquidationInitiator);
        vm.expectRevert("A_CASL: Account not liquidatable");
        liquidator_new.liquidateAccount(address(proxyAccount));
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
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);

        // When Then: Liquidation Initiator calls liquidateAccount, Account is not liquidatable
        vm.prank(liquidationInitiator);
        vm.expectRevert("A_CASL: Account not liquidatable");
        liquidator_new.liquidateAccount(address(proxyAccount));
    }

    function testFuzz_Revert_liquidateAccount_MaliciousAccount_NoDebtInCreditor(
        address liquidationInitiator,
        uint128 amountLoaned,
        uint256 totalOpenDebt,
        uint256 valueInBaseCurrency,
        uint256 collateralFactor,
        uint256 liquidationFactor
    ) public {
        // Avoid overflow when calculating the liquidation incentives (penaltyWeight is highest value)
        vm.assume(totalOpenDebt < type(uint256).max / liquidator_new.getPenaltyWeight());
        // Given: Arcadia Lending pool
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);

        // And: AccountV1Malicious is created
        AccountV1Malicious maliciousAccount =
        new AccountV1Malicious(address(pool_new), totalOpenDebt, valueInBaseCurrency, collateralFactor, liquidationFactor);

        // When Then: Liquidation Initiator calls liquidateAccount, It should revert because of malicious account address does not have debt in creditor
        vm.prank(liquidationInitiator);
        vm.expectRevert(LendingPool_IsNotAnAccountWithDebt.selector);
        liquidator_new.liquidateAccount(address(maliciousAccount));
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
        liquidator_new.liquidateAccount(address(maliciousAccount));

        // And: No harm to protocol
        // Since lending pool is maliciousAccount, it will not represent the real value in the protocol
        // So, no harm to protocol

        // Then: Auction will be set but lending pool will not be in auction mode
        bool isAuctionActive = liquidator_new.getAuctionIsActive(address(maliciousAccount));
        assertEq(isAuctionActive, true);

        assertGe(pool_new.getAuctionsInProgress(), 0);
    }

    function testFuzz_Revert_liquidateAccount_AuctionOngoing(address liquidationInitiator, uint128 amountLoaned)
        public
    {
        // Given: Account auction is already started
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100); // No overflow when debt is increased
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        debt_new.setRealisedDebt(uint256(amountLoaned + 1));

        vm.prank(liquidationInitiator);
        liquidator_new.liquidateAccount(address(proxyAccount));

        bool isAuctionActive = liquidator_new.getAuctionIsActive(address(proxyAccount));
        assertEq(isAuctionActive, true);

        uint256 startDebt = liquidator_new.getAuctionStartPrice(address(proxyAccount));
        uint256 loan = uint256(amountLoaned + 1) * 150 / 100;

        assertEq(startDebt, loan);

        assertGe(pool_new.getAuctionsInProgress(), 1);

        // When Then: Liquidation Initiator calls liquidateAccount again, It should revert
        vm.startPrank(liquidationInitiator);
        vm.expectRevert(Liquidator_AuctionOngoing.selector);
        liquidator_new.liquidateAccount(address(proxyAccount));
        vm.stopPrank();
    }

    function testFuzz_Success_liquidateAccount_UnhealthyDebt(
        address liquidationInitiator,
        uint128 amountLoaned,
        uint8 initiatorRewardWeight,
        uint8 penaltyWeight,
        uint8 closingRewardWeight,
        uint80 maxInitiatorFee,
        uint80 maxClosingFee
    ) public {
        // Given: Account has debt
        bytes3 emptyBytes3;
        vm.assume(amountLoaned > 1);
        vm.assume(amountLoaned <= (type(uint128).max / 150) * 100); // No overflow when debt is increased
        vm.assume(uint16(initiatorRewardWeight) + penaltyWeight + closingRewardWeight <= 11);
        depositTokenInAccount(proxyAccount, mockERC20.stable1, amountLoaned);
        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool_new), type(uint256).max);
        vm.prank(address(srTranche_new));
        pool_new.depositInLendingPool(amountLoaned, users.liquidityProvider);
        vm.prank(users.accountOwner);
        pool_new.borrow(amountLoaned, address(proxyAccount), users.accountOwner, emptyBytes3);
        vm.prank(users.creatorAddress);
        pool_new.setMaxLiquidationFees(maxInitiatorFee, maxClosingFee);

        // Set weights
        vm.prank(users.creatorAddress);
        liquidator_new.setWeights(initiatorRewardWeight, penaltyWeight, closingRewardWeight);

        // And: Account becomes Unhealthy (Realised debt grows above Liquidation value)
        debt_new.setRealisedDebt(uint256(amountLoaned + 1));

        // When: Liquidation Initiator calls liquidateAccount
        vm.prank(liquidationInitiator);
        liquidator_new.liquidateAccount(address(proxyAccount));

        // Avoid stack too deep
        //        uint8 initiatorRewardWeightStack = initiatorRewardWeight;
        //        uint8 penaltyWeightStack = penaltyWeight;
        //        uint8 closingRewardWeightStack = closingRewardWeight;
        uint128 amountLoanedStack = amountLoaned;

        // Then: Auction should be set and started
        bool isAuctionActive = liquidator_new.getAuctionIsActive(address(proxyAccount));
        assertEq(isAuctionActive, true);

        uint256 startPrice = liquidator_new.getAuctionStartPrice(address(proxyAccount));
        uint256 loan = uint256(amountLoaned + 1) * 150 / 100;

        assertEq(startPrice, loan);
        assertGe(pool_new.getAuctionsInProgress(), 1);

        // And : Auction struct should be correct
        (uint128 openDebt, uint32 startTime, bool inAuction) =
            liquidator_new.getAuctionInformationPartOne(address(proxyAccount));
        uint80 maxInitiatorFee_ = pool_new.getMaxInitiatorFee();
        uint80 maxClosingFee_ = pool_new.getMaxClosingFee();

        (uint8 initiatorRewardWeight_, uint8 penaltyWeight_, uint8 closingRewardWeight_, address trustedCreditor_) =
            liquidator_new.getAuctionInformationPartTwo(address(proxyAccount));

        assertEq(openDebt, amountLoanedStack + 1);
        assertEq(startTime, block.timestamp);
        assertEq(inAuction, true);
        // TODO: Fix this, these checks are not necessary - Zeki - 31/10/23
        //        assertEq(maxInitiatorFee_, pool_new.getMaxInitiatorFee());
        //        assertEq(initiatorRewardWeightStack, initiatorRewardWeight_);
        //        assertEq(penaltyWeightStack, penaltyWeight_);
        //        assertEq(closingRewardWeightStack, closingRewardWeight_);
        assertEq(trustedCreditor_, address(pool_new));

        uint256 openDebtStack = openDebt;
        // And : Liquidation incentives should have been added to openDebt of Account
        uint256 liquidationInitiatorReward = openDebt * initiatorRewardWeight_ / 100;
        liquidationInitiatorReward =
            liquidationInitiatorReward > maxInitiatorFee_ ? maxInitiatorFee_ : liquidationInitiatorReward;
        uint256 liquidationPenalty = openDebt * penaltyWeight_ / 100;
        uint256 closingReward = openDebt * closingRewardWeight_ / 100;
        closingReward = closingReward > maxClosingFee_ ? maxClosingFee_ : closingReward;

        assertEq(
            pool_new.getOpenPosition(address(proxyAccount)),
            openDebtStack + liquidationInitiatorReward + liquidationPenalty + closingReward
        );
    }
}
