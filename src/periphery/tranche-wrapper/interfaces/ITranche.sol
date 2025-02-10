/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity ^0.8.22;

interface ITranche {
    function LENDING_POOL() external returns (address lendingPool);

    function previewMintAndSync(uint256 shares) external returns (uint256 assets);

    function previewWithdrawAndSync(uint256 assets) external returns (uint256 shares);
}
