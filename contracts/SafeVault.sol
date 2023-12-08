// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";
import { ERC4626 } from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { ISafeVault } from "./interfaces/ISafeVault.sol";

/**
 * @title SafeVault
 * @dev The SafeVault contract represents a secure vault for USDC,
 * represented by the SafeYields Token (SAFE) and built on the ERC4626 standard.
 * It inherits from Ownable, Pausable, ERC4626, and ERC20 contracts. The vault supports functionality to update buy
 * and sell taxes, as well as pausing and unpausing contract operations.
 */
contract SafeVault is ISafeVault, ERC4626, Ownable, Pausable {
    uint256 public buyTaxBps;
    uint256 public sellTaxBps;

    /**
     * @dev Constructor to initialize the SafeVault contract.
     * @param _usdc The ERC20 token representing USDC.
     * @param _buyTaxBps The buy tax in basis points (Bps).
     * @param _sellTaxBps The sell tax in basis points (Bps).
     */
    constructor(
        IERC20 _usdc,
        uint256 _buyTaxBps,
        uint256 _sellTaxBps
    ) Ownable(msg.sender) ERC4626(_usdc) ERC20("SafeYields Token", "SAFE") {
        buyTaxBps = _buyTaxBps;
        sellTaxBps = _sellTaxBps;
    }

    /**
     * @dev Updates the buy tax basis points. Only the owner can call this function.
     * @param newBuyTaxBps The new buy tax in basis points (Bps).
     */
    function updateBuyTaxBps(uint256 newBuyTaxBps) external onlyOwner {
        buyTaxBps = newBuyTaxBps;
        emit BuyTaxUpdated(newBuyTaxBps);
    }

    /**
     * @dev Updates the sell tax basis points. Only the owner can call this function.
     * @param newSellTaxBps The new sell tax in basis points (Bps).
     */
    function updateSellTaxBps(uint256 newSellTaxBps) external onlyOwner {
        buyTaxBps = newSellTaxBps;
        emit SellTaxUpdated(newSellTaxBps);
    }

    /**
     * @dev Pauses contract operations. Only the owner can call this function.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses contract operations. Only the owner can call this function.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 assetsAfterTax = assets - ((assets * buyTaxBps) / 10000);

        uint256 shares = previewDeposit(assetsAfterTax);
        _deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-mint}.
     *
     * As opposed to {deposit}, minting is allowed even if the vault is in a state where the price of a share is zero.
     * In this case, the shares will be minted without requiring any assets to be deposited.
     */
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        uint256 assets = previewMint(shares);

        uint256 assetsAfterTax = assets + ((assets * buyTaxBps) / 10000);
        _deposit(_msgSender(), receiver, assetsAfterTax, shares);

        return assets;
    }

    /** @dev See {IERC4626-withdraw}. */
    function withdraw(uint256 assets, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 assetsAfterTax = assets - ((assets * sellTaxBps) / 10000);

        uint256 shares = previewWithdraw(assets);
        _withdraw(_msgSender(), receiver, owner, assetsAfterTax, shares);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);

        uint256 assetsAfterTax = assets - ((assets * sellTaxBps) / 10000);
        _withdraw(_msgSender(), receiver, owner, assetsAfterTax, shares);

        return assets;
    }
}
