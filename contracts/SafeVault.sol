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

    address public managementAddress;
    address public aiFundAddress;

    uint256 public constant MANAGEMENT_FEE = 2500;
    uint256 public constant AI_FUND_FEE = 2500;

    /**
     * @dev Constructor to initialize the SafeVault contract.
     * @param _usdc The ERC20 token representing USDC.
     * @param _buyTaxBps The buy tax in basis points (Bps).
     * @param _sellTaxBps The sell tax in basis points (Bps).
     */
    constructor(
        IERC20 _usdc,
        uint256 _buyTaxBps,
        uint256 _sellTaxBps,
        address _managementAddress,
        address _aiFundAddress
    ) Ownable(msg.sender) ERC4626(_usdc) ERC20("SafeYields Token", "SAFE") {
        buyTaxBps = _buyTaxBps;
        sellTaxBps = _sellTaxBps;
        managementAddress = _managementAddress;
        aiFundAddress = _aiFundAddress;
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

    /** @dev See {IERC4626-deposit}.
     *
     * This is the equivalent of trading USDC for $SAFE.
     */
    function deposit(uint256 assets, address receiver) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        // Calculate tax for buying $SAFE
        uint256 vaultTax = (assets * buyTaxBps) / 10000;

        // Calclulate the management tax
        uint256 managementTax = (vaultTax * MANAGEMENT_FEE) / 10000;

        // Calculate the AI Fund tax
        uint256 aiFundTax = (vaultTax * AI_FUND_FEE) / 10000;

        // Calculate assets after tax is deducted
        uint256 assetsAfterTax = assets - vaultTax;

        // Calculate shares equivalent to the assets after tax
        uint256 shares = previewDeposit(assetsAfterTax);

        // Transfer the assets (USDC) to the $SAFE Vault Contract
        SafeERC20.safeTransferFrom(IERC20(asset()), _msgSender(), address(this), assets);

        // Transfer the management tax
        IERC20(asset()).transfer(managementAddress, managementTax);

        // Transfer the AI fund tax
        IERC20(asset()).transfer(aiFundAddress, aiFundTax);

        // Mint $SAFE
        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /** @dev See {IERC4626-mint}.
     *
     * This is the equivalent of buying exact amount of $SAFE
     */
    function mint(uint256 shares, address receiver) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxMint(receiver);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxMint(receiver, shares, maxShares);
        }

        // Get the fair USDC value for the amount of $SAFE
        uint256 assets = previewMint(shares);

        // Calculate the Vault tax
        uint256 vaultTax = (assets * buyTaxBps) / 10000;

        // Calculate the assets with inclusive tax
        uint256 assetsAfterTax = assets + vaultTax;

        // Calclulate the management tax
        uint256 managementTax = (vaultTax * MANAGEMENT_FEE) / 10000;

        // Calculate the AI Fund tax
        uint256 aiFundTax = (vaultTax * AI_FUND_FEE) / 10000;

        // Transfer the USDC to the Vault
        SafeERC20.safeTransferFrom(IERC20(asset()), _msgSender(), address(this), assetsAfterTax);

        // Transfer the management tax
        IERC20(asset()).transfer(managementAddress, managementTax);

        // Transfer the AI fund tax
        IERC20(asset()).transfer(aiFundAddress, aiFundTax);

        // Mint $SAFE
        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assetsAfterTax, shares);

        return assets;
    }

    /** @dev See {IERC4626-withdraw}.
     *
     * This is the equivalent of trading $SAFE for USDC.
     */
    function withdraw(uint256 assets, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        // Calculate tax for buying $SAFE
        uint256 vaultTax = (assets * sellTaxBps) / 10000;

        // Calclulate the management tax
        uint256 managementTax = (vaultTax * MANAGEMENT_FEE) / 10000;

        // Calculate the AI Fund tax
        uint256 aiFundTax = (vaultTax * AI_FUND_FEE) / 10000;

        // Calculate assets after tax is deducted
        uint256 assetsAfterTax = assets - vaultTax;

        uint256 shares = previewWithdraw(assets);

        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        // Burn $SAFE
        _burn(owner, shares);

        // Transfet the assets (USDC) to the owner
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assetsAfterTax);

        // Transfer the management tax
        IERC20(asset()).transfer(managementAddress, managementTax);

        // Transfer the AI fund tax
        IERC20(asset()).transfer(aiFundAddress, aiFundTax);

        emit Withdraw(_msgSender(), receiver, owner, assetsAfterTax, shares);

        return shares;
    }

    /** @dev See {IERC4626-redeem}. */
    function redeem(uint256 shares, address receiver, address owner) public override whenNotPaused returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        // Get the fair USDC value for the amount of $SAFE
        uint256 assets = previewRedeem(shares);

        // Calculate the total Vault Tax
        uint256 vaultTax = (assets * sellTaxBps) / 10000;

        // Calclulate the management tax
        uint256 managementTax = (vaultTax * MANAGEMENT_FEE) / 10000;

        // Calculate the AI Fund tax
        uint256 aiFundTax = (vaultTax * AI_FUND_FEE) / 10000;

        // Calculate the assets to distribute after tax
        uint256 assetsAfterTax = assets - vaultTax;

        if (_msgSender() != owner) {
            _spendAllowance(owner, _msgSender(), shares);
        }

        // Burn $SAFE
        _burn(owner, shares);

        // Transfer USDC to owner after tax is deducted
        SafeERC20.safeTransfer(IERC20(asset()), receiver, assetsAfterTax);

        // Transfer the management tax
        IERC20(asset()).transfer(managementAddress, managementTax);

        // Transfer the AI fund tax
        IERC20(asset()).transfer(aiFundAddress, aiFundTax);

        emit Withdraw(_msgSender(), receiver, owner, assetsAfterTax, shares);

        return assets;
    }
}
