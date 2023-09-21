/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import "./AccountV1.sol";

contract Factory {
    mapping(address => uint256) public accountIndex;
    mapping(uint256 => address) public ownerOf;

    address[] public allAccounts;

    constructor() { }

    function createAccount(uint256 salt) external returns (address account) {
        account = address(
            new AccountV1{salt: bytes32(salt)}(
                msg.sender
            )
        );

        allAccounts.push(account);
        uint256 index = allAccounts.length;
        accountIndex[account] = index;
        ownerOf[index] = msg.sender;
    }

    function isAccount(address account) public view returns (bool) {
        return accountIndex[account] > 0;
    }

    function ownerOfAccount(address account) public view returns (address owner_) {
        owner_ = ownerOf[accountIndex[account]];
    }
}
