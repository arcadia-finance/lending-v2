/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

import { LogExpMath } from "./libraries/LogExpMath.sol";
import { IFactory } from "./interfaces/IFactory.sol";
import { ERC20, SafeTransferLib } from "../lib/solmate/src/utils/SafeTransferLib.sol";
import { IAccount_NEW } from "./interfaces/IAccount_NEW.sol";
import { ILendingPool_NEW } from "./interfaces/ILendingPool_NEW.sol";
import { Owned } from "lib/solmate/src/auth/Owned.sol";
import { ILiquidator_NEW } from "./interfaces/ILiquidator_NEW.sol";
import { RiskModule } from "lib/accounts-v2/src/RiskModule.sol";

contract Liquidator_NEW is Owned {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    uint256 locked;

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() Owned(msg.sender) {
        locked = 1;
    }

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    modifier nonReentrant() {
        require(locked == 1, "L: REENTRANCY");
        locked = 2;
        _;
        locked = 1;
    }

    /*///////////////////////////////////////////////////////////////
                        MANAGE AUCTION SETTINGS
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                            AUCTION LOGIC
    ///////////////////////////////////////////////////////////////*/

    function liquidateAccount(address account) external nonReentrant {
        // Store the initiator address
        address initiator = msg.sender;

        // Call Account to check if account is solvent and if it is solvent start the liquidation in the Account.
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts,
            address creditor,
            uint256 debt,
            RiskModule.AssetValueAndRiskVariables[] memory riskValues
        ) = IAccount_NEW(account).checkAndStartLiquidation();

        // Check if the account has debt in the lending pool and if so, increment auction in progress counter.
        ILendingPool_NEW(creditor).startLiquidation(account, debt);

        // Fill the auction struct
    }

    function _calculateAskPrice(
        uint256[] memory askedAssetAmounts,
        address[] memory askedAssetIds,
        address[] memory assetShares,
        uint256[] memory assetAmounts,
        uint256[] memory assetIds,
        uint256 startPrice,
        uint256 base,
        uint256 startPriceMultiplier,
        uint256 minPriceMultiplier,
        uint256 timePassed
    ) internal pure returns (uint256 askPrice) {
        require(
            askedAssetAmounts.length == askedAssetIds.length && assetAmounts.length == askedAssetAmounts.length,
            "Arrays length mismatch"
        );

        uint256 askedShares;
        uint256 totalShares = 100;

        for (uint256 i = 0; i < askedAssetAmounts.length; i++) {
            askedShares += assetShares[i] * (askedAssetAmounts[i] / assetAmounts[i]);
        }

        unchecked {
            //Bring to 18 decimals precision for LogExpMath.pow()
            //No overflow possible: uint32 * uint64.
            timePassed = timePassed * 1e18;

            //Calculate the price
            askPrice = startPrice * askedShares
                * (
                    LogExpMath.pow(base, timePassed) * (startPriceMultiplier - minPriceMultiplier)
                        + 1e18 * uint256(minPriceMultiplier)
                ) / (1e20 * totalShares);
        }
    }
}
