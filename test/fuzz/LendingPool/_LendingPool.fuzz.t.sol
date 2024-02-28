/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

import { Fuzz_Lending_Test } from "../Fuzz.t.sol";

import { LogExpMath } from "../../../src/libraries/LogExpMath.sol";

/**
 * @notice Common logic needed by all "LendingPool" fuzz tests.
 */
abstract contract LendingPool_Fuzz_Test is Fuzz_Lending_Test {
    /* ///////////////////////////////////////////////////////////////
                             VARIABLES
    /////////////////////////////////////////////////////////////// */

    bytes3 internal emptyBytes3;

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
        pool.setLiquidationWeightTranche(20);
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
    function calcUnrealisedDebtChecked(uint256 interestRate, uint24 deltaTimestamp, uint256 realisedDebt)
        internal
        view
        returns (uint256 unrealisedDebt)
    {
        uint256 base = 1e18 + interestRate;
        uint256 exponent = uint256(deltaTimestamp) * 1e18 / pool.getYearlySeconds();
        unrealisedDebt = (uint256(realisedDebt) * (LogExpMath.pow(base, exponent) - 1e18)) / 1e18;
    }
}
