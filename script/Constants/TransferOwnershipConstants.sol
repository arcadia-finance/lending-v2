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
    // Multisigs
    address public constant owner = address(0xb4d72B1c91e640e4ED7d7397F3244De4D8ACc50B);
    address public constant guardian = address(0xEdD41f9740b06eCBfe1CE9194Ce2715C28263187);
    address public constant riskManager = address(0xD5FA6C6e284007743d4263255385eDA78dDa268c);
    address public constant treasury = address(0xFd6db26eDc581D8F381f46eF4a6396A762b66E95);

    address public constant accountRecipient = address(0x0f518becFC14125F23b8422849f6393D59627ddB);
}
