/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { Tranche } from "../../../src/Tranche.sol";

contract TrancheExtension is Tranche {
    constructor(address lendingPool_, uint256 vas, string memory prefix_, string memory prefixSymbol_)
        Tranche(lendingPool_, vas, prefix_, prefixSymbol_)
    { }

    function getVas() public view returns (uint256 vas) {
        vas = VAS;
    }
}
