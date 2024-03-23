/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaContractAddresses {
    // Todo: Update these addresses
    address public constant lendingPoolUSDC = address(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
    address public constant lendingPoolWETH = address(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
}

library ArcadiaAddresses {
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);
    address public constant multiSig3 = address(0);

    address public constant lendingPoolUSDCOwner = multiSig1;
    address public constant lendingPoolWETHOwner = multiSig1;
    address public constant guardian = multiSig2;
    // risk manager
    // account recipient
    // tranches
    // liquidator
}
