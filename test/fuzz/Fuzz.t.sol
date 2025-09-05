/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.0;

import { ArcadiaLendingFixture } from "../utils/fixtures/arcadia-lending/ArcadiaLendingFixture.f.sol";
import { Base_Lending_Test } from "../Base.t.sol";
import { Fuzz_Test } from "../../lib/accounts-v2/test/fuzz/Fuzz.t.sol";

import { Asset } from "../utils/mocks/Asset.sol";
import { SequencerUptimeOracle } from "../../lib/accounts-v2/test/utils/mocks/oracles/SequencerUptimeOracle.sol";
import { TrancheExtension } from "../utils/extensions/TrancheExtension.sol";

/**
 * @notice Common logic needed by all fuzz tests.
 * @dev Each function must be fuzz tested over its full space of possible state configurations
 * (both the state variables of the contract being tested
 * as the state variables of any external contract with which the function interacts).
 * @dev in practice each input parameter and state variable (as explained above) must be tested over its full range
 * (eg. a uint256 from 0 to type(uint256).max), unless the parameter/variable is bound by an invariant.
 * If this case, said invariant must be explicitly tested in the invariant tests.
 */
abstract contract Fuzz_Lending_Test is Base_Lending_Test, Fuzz_Test, ArcadiaLendingFixture {
    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    Asset internal asset;
    TrancheExtension internal jrTranche;
    TrancheExtension internal srTranche;

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual override(Base_Lending_Test, Fuzz_Test) {
        Base_Lending_Test.setUp();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/
    function deployArcadiaLendingWithoutAccounts() internal virtual {
        // Deploy the sequencer uptime oracle.
        sequencerUptimeOracle = new SequencerUptimeOracle();

        // Warp to have a timestamp of at least two days old.
        vm.warp(2 days);

        // Deploy the underlying asset.
        vm.prank(users.tokenCreator);
        asset = new Asset("Asset", "ASSET", 18);
        vm.label({ account: address(asset), newLabel: "Asset" });

        // Deploy the base test contracts.
        deployArcadiaLending(address(asset));
        srTranche = createTranche("Senior", "SR", 50);
        jrTranche = createTranche("Junior", "JR", 40);
        // For clarity, some contracts have a generalised name in some tests.
        tranche = srTranche;
    }

    function deployArcadiaLendingWithAccounts() internal {
        // Deploy Arcadia Accounts contracts and assets.
        Fuzz_Test.setUp();

        // Deploy the base test contracts.
        deployArcadiaLending(address(mockERC20.stable1));
        srTranche = createTranche("Senior", "SR", 50);
        jrTranche = createTranche("Junior", "JR", 40);

        // Initialise parameters.
        initArcadiaLending();

        // For clarity, some contracts have a generalised name in some tests.
        tranche = srTranche;
    }
}
