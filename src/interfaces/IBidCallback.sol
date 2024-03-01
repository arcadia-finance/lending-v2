/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IBidCallback {
    /**
     * @notice Called to bidder after transferring the assets.
     * @param assetAmounts Array with the assets-amounts bought.
     * @param price The price for which the bid can be purchased, denominated in the Numeraire.
     * @param data Data passed through back to the bidder via the bidCallback() call.
     */
    function bidCallback(uint256[] memory assetAmounts, uint256 price, bytes calldata data) external;
}
