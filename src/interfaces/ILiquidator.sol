/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface ILiquidator {
    function liquidateAccount(address account) external;

    function bid(address account, uint256[] calldata assetAmounts, uint256[] calldata assetIds, bool endAuction)
        external
        payable;
}
