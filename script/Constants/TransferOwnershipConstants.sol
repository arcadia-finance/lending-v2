/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.22;

library ArcadiaContractAddresses {
    address public constant lendingPool_usdc = address(0x3ec4a293Fb906DD2Cd440c20dECB250DeF141dF1);
    address public constant lendingPool_weth = address(0x803ea69c7e87D1d6C86adeB40CB636cC0E6B98E2);
    address public constant tranche_usdc = address(0xEFE32813dBA3A783059d50e5358b9e3661218daD);
    address public constant tranche_weth = address(0x393893caeB06B5C16728bb1E354b6c36942b1382);
    address public constant liquidator = address(0xA4B0b9fD1d91fA2De44F6ABFd59cC14bA1E1a7Af);
}

library ArcadiaAddresses {
    // Todo: Update these addresses
    address public constant multiSig1 = address(0);
    address public constant multiSig2 = address(0);
    address public constant multiSig3 = address(0);
    address public constant accountRecipient = address(0);

    address public constant lendingPoolOwner_usdc = multiSig1;
    address public constant lendingPoolOwner_weth = multiSig1;
    address public constant trancheOwner_usdc = multiSig1;
    address public constant trancheOwner_weth = multiSig1;
    address public constant liquidatorOwner = multiSig1;

    address public constant guardian = multiSig2;

    address public constant riskManager = multiSig3;
}
