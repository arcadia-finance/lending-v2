/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { Base_Lending_Test } from "../Base.t.sol";
import { Fuzz_Test } from "../../lib/accounts-v2/test/fuzz/Fuzz.t.sol";

import { ERC20 } from "../../lib/solmate/src/tokens/ERC20.sol";

import { AccountV1 } from "../../lib/accounts-v2/src/AccountV1.sol";
import { Asset } from "../utils/mocks/Asset.sol";
import { DebtTokenExtension } from "../utils/Extensions.sol";
import { LendingPoolExtension, LendingPool, LendingPoolExtension_NEW } from "../utils/Extensions.sol";
import { LiquidatorExtension } from "../utils/Extensions.sol";
import { LiquidatorExtension_NEW } from "../utils/Extensions.sol";
import { Tranche } from "../../src/Tranche.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
abstract contract Fuzz_Lending_Test is Base_Lending_Test, Fuzz_Test {
    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                     VARIABLES
    //////////////////////////////////////////////////////////////////////////*/

    // ToDo : move to Types users
    address internal treasury;
    LendingPool public poolTest;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(Base_Lending_Test, Fuzz_Test) {
        // ToDo : move to Types users
        treasury = address(34_567);

        vm.label({ account: treasury, newLabel: "Treasury" });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
    function deployArcadiaLendingWithoutAccounts() internal virtual {
        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        asset = new Asset("Asset", "ASSET", 18);
        liquidator = new LiquidatorExtension(address(factory));
        liquidator_new = new LiquidatorExtension_NEW();
        pool = new LendingPoolExtension(asset, treasury, address(factory), address(liquidator));
        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        // Set the Guardian.
        vm.prank(users.creatorAddress);
        pool.changeGuardian(users.guardian);

        // For clarity, some contracts have a generalised name in some tests.
        tranche = srTranche;

        // For clarity, some contracts with multiple functionalities (in different abstract contracts) have a different name in some tests.
        debt = DebtTokenExtension(address(pool));

        // Label the base test contracts.
        vm.label({ account: address(asset), newLabel: "Asset" });
        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(pool), newLabel: "Lending Pool" });
        vm.label({ account: address(srTranche), newLabel: "Senior Tranche" });
        vm.label({ account: address(jrTranche), newLabel: "Junior Tranche" });
    }

    function deployArcadiaLendingWithAccounts() internal {
        Fuzz_Test.setUp();

        // Deploy the base test contracts.
        vm.startPrank(users.creatorAddress);
        liquidator = new LiquidatorExtension(address(factory));
        liquidator_new = new LiquidatorExtension_NEW();
        pool =
            new LendingPoolExtension(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator));

        pool_new =
            new LendingPoolExtension_NEW(ERC20(address(mockERC20.stable1)), treasury, address(factory), address(liquidator_new));

        srTranche = new Tranche(address(pool), "Senior", "SR");
        jrTranche = new Tranche(address(pool), "Junior", "JR");
        vm.stopPrank();

        // Set the Guardian.
        vm.prank(users.creatorAddress);
        pool.changeGuardian(users.guardian);

        // For clarity, some contracts have a generalised name in some tests.
        tranche = srTranche;

        // For clarity, some contracts with multiple functionalities (in different abstract contracts) have a different name in some tests.
        debt = DebtTokenExtension(address(pool));

        // Label the base test contracts.
        vm.label({ account: address(liquidator), newLabel: "Liquidator" });
        vm.label({ account: address(liquidator_new), newLabel: "Liquidator_NEW" });
        vm.label({ account: address(pool), newLabel: "Lending Pool" });
        vm.label({ account: address(pool_new), newLabel: "Lending Pool New" });
        vm.label({ account: address(srTranche), newLabel: "Senior Tranche" });
        vm.label({ account: address(jrTranche), newLabel: "Junior Tranche" });
    }
}
