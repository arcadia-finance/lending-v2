/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: MIT
 */
pragma solidity 0.8.22;

interface IBidCallback {
    /**
     * @notice Called to bidder after transferring the assets.
     * @param data Data passed through back to the bidder via the bidCallback() call.
     */
    function bidCallback(bytes calldata data) external;
}
