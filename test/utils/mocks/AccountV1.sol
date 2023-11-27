/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

contract AccountV1 {
    address public owner;
    uint256 public totalValue;
    uint256 public lockedValue;
    address public numeraire;
    address public creditor;
    uint16 public accountVersion;

    uint256 public mockToSurpressWarning;

    constructor(address _owner) payable {
        owner = _owner;
    }

    function setTotalValue(uint256 _totalValue) external {
        totalValue = _totalValue;
    }

    function setCreditor(address _trustedCreditor) external {
        creditor = _trustedCreditor;
    }

    function isAccountHealthy(uint256 amount, uint256 totalOpenDebt)
        external
        view
        returns (bool success, address _trustedCreditor, uint256 accountVersion_)
    {
        if (amount != 0) {
            //Check if Account is still healthy after an increase of used margin.
            success = totalValue >= lockedValue + amount;
        } else {
            //Check if Account is healthy for a given amount of openDebt.
            success = totalValue >= totalOpenDebt;
        }

        return (success, creditor, accountVersion);
    }

    function accountManagementAction(address, bytes calldata) external returns (address, uint256) {
        mockToSurpressWarning = 1;
        return (creditor, accountVersion);
    }
}
