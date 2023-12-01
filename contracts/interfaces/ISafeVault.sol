// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

interface ISafeVault {
    /* ========== EVENTS ========== */
    event BuyTaxUpdated(uint256 newBuyTaxBps);
    event SellTaxUpdated(uint256 newSellTaxBps);

    function updateBuyTaxBps(uint256 newBuyTaxBps) external;
    function updateSellTaxBps(uint256 newSellTaxBps) external;
}
