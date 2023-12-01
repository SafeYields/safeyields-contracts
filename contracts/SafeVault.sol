// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { ISafeVault } from "./interfaces/ISafeVault.sol";

contract SafeVault is ISafeVault, ERC4626, Ownable {
    uint256 public buyTaxBps;
    uint256 public sellTaxBps;

    constructor(
        IERC20 _usdc,
        uint256 _buyTaxBps,
        uint256 _sellTaxBps
    ) Ownable(msg.sender) ERC4626(_usdc) ERC20("SafeYields Token", "SAFE") {
        buyTaxBps = _buyTaxBps;
        sellTaxBps = _sellTaxBps;
    }

    function updateBuyTaxBps(uint256 newBuyTaxBps) external onlyOwner {
        buyTaxBps = newBuyTaxBps;
        emit BuyTaxUpdated(newBuyTaxBps);
    }

    function updateSellTaxBps(uint256 newSellTaxBps) external onlyOwner {
        buyTaxBps = newSellTaxBps;
        emit SellTaxUpdated(newSellTaxBps);
    }
}
