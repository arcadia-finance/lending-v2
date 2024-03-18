/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";
import { AccountV1 } from "lib/accounts-v2/src/accounts/AccountV1.sol";
import { ERC20Mock } from "lib/accounts-v2/test/utils/mocks/tokens/ERC20Mock.sol";

/**
 * @notice Common logic needed by all "Liquidator" fuzz tests.
 */
abstract contract Liquidator_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    /* ///////////////////////////////////////////////////////////////
                              SETUP
    /////////////////////////////////////////////////////////////// */

    function setUp() public virtual override(Fuzz_Lending_Test) {
        Fuzz_Lending_Test.setUp();
        deployArcadiaLendingWithAccounts();

        vm.startPrank(users.creatorAddress);
        pool.setTreasuryWeights(10, 80);
        pool.addTranche(address(srTranche), 50);
        pool.addTranche(address(jrTranche), 40);
        pool.setAccountVersion(1, true);
        vm.stopPrank();

        vm.prank(users.tokenCreatorAddress);
        mockERC20.stable1.mint(users.liquidityProvider, type(uint256).max);

        vm.prank(users.liquidityProvider);
        mockERC20.stable1.approve(address(pool), type(uint256).max);

        vm.prank(users.accountOwner);
        proxyAccount.openMarginAccount(address(pool));
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

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
}
