/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

/**
 * @title Creditor implementation.
 * @author Pragma Labs
 * @notice This contract contains the minimum functionality a Creditor, interacting with Arcadia Accounts, needs to implement.
 * @dev For the implementation of Arcadia Accounts, see: https://github.com/arcadia-finance/accounts-v2.
 */
abstract contract Creditor {
    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // The address of the riskManager.
    address public riskManager;

    // Map accountVersion => status.
    mapping(uint256 => bool) public isValidVersion;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event RiskManagerUpdated(address riskManager);
    event ValidAccountVersionsUpdated(uint256 indexed accountVersion, bool valid);

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    /**
     * @param riskManager_ The address of the Risk Manager.
     */
    constructor(address riskManager_) {
        _setRiskManager(riskManager_);
    }

    /* //////////////////////////////////////////////////////////////
                            ACCOUNT LOGIC
    ////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets a new Risk Manager. A risk manager can:
     * -Set risk parameters for collateral assets, including: max exposures, collateral factors and liquidation factors.
     * -Set minimum usd value taken into account to avoid dust attacks.
     * @param riskManager_ The address of the new Risk Manager.
     */
    function _setRiskManager(address riskManager_) internal {
        riskManager = riskManager_;

        emit RiskManagerUpdated(riskManager_);
    }

    /**
     * @notice Sets the validity of Account version to valid.
     * @param accountVersion The current version of the Account.
     * @param isValid Will be "true" if respective Account version is valid, "false" if not.
     */
    function _setAccountVersion(uint256 accountVersion, bool isValid) internal {
        isValidVersion[accountVersion] = isValid;

        emit ValidAccountVersionsUpdated(accountVersion, isValid);
    }

    /**
     * @notice Checks if Account fulfills all requirements and returns creditor settings.
     * @param accountVersion The version of the Arcadia Account.
     * @return success Bool indicating if all requirements are met.
     * @return baseCurrency The base currency of the creditor.
     * @return liquidator The liquidator of the creditor.
     * @return fixedLiquidationCost Estimated fixed costs (independent of size of debt) to liquidate a position.
     */
    function openMarginAccount(uint256 accountVersion)
        external
        view
        virtual
        returns (bool success, address baseCurrency, address liquidator, uint256 fixedLiquidationCost);

    /**
     * @notice Returns the open position of the Account.
     * @param account The Account address.
     * @return openPosition The open position of the Account.
     */
    function getOpenPosition(address account) external view virtual returns (uint256 openPosition);

    /**
     * @notice Starts the liquidation of an account and returns the open position of the Account.
     * @param initiator The address of the liquidation initiator.
     * @return openPosition the open position of the Account.
     */
    function startLiquidation(address initiator) external virtual returns (uint256);
}
