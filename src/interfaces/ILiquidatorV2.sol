/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.19;

interface ILiquidatorV2 {

    function liquidateAccount(address account) external;

    function bid(address account, address[] calldata assets, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256 bidInBaseCurrenct, bool endAuction) external;

    function endAuction(address account) external;
}
