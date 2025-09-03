/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { ERC20 } from "../../../lib/accounts-v2/lib/solmate/src/tokens/ERC20.sol";
import { DebtToken } from "../../../src/DebtToken.sol";

contract DebtTokenExtension is DebtToken {
    constructor(ERC20 asset_) DebtToken(asset_) { }

    function deposit_(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = _deposit(assets, receiver);
    }

    function withdraw_(uint256 assets, address receiver, address owner_) public returns (uint256 shares) {
        shares = _withdraw(assets, receiver, owner_);
    }

    function totalAssets() public view override returns (uint256 totalDebt) {
        totalDebt = realisedDebt;
    }

    function getRealisedDebt() public view returns (uint256) {
        return realisedDebt;
    }

    function setRealisedDebt(uint256 realisedDebt_) public {
        realisedDebt = realisedDebt_;
    }
}
