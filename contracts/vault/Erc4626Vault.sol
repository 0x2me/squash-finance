// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "solmate/tokens/ERC20.sol";

import "../interfaces/IERC4626.sol";
import "../interfaces/IStrategy.sol";

import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeERC20 as _SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract ERC4626Vault is IERC4626, ERC20, Ownable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable vaultAsset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        vaultAsset = _asset;
    }

    /// @notice The address of the underlying ERC20 token used for
    /// the Vault for accounting, depositing, and withdrawing.
    function asset() external view returns (address) {
        return address(vaultAsset);
    }

    /*//////////////////////////////////////////////////////////////
                               Variables
    //////////////////////////////////////////////////////////////*/

    IStrategy public strategy;

    /*////////////////////////////////////////////////////////
                      Deposit/Withdrawal Logic
    ////////////////////////////////////////////////////////*/

    /// @notice Mints `shares` Vault shares to `receiver` by
    /// depositing exactly `assets` of underlying tokens.
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares) {
        // Check for 0 deposit. This may happen as we round down in preview deposit
        require((shares = previewDeposit(assets)) != 0, "0_SHARES");

        //console.log(shares);

        // Need to transfer before minting to prevent a reentrancy attack
        vaultAsset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /// @notice Mints exactly `shares` Vault shares to `receiver`
    /// by depositing `assets` of underlying tokens.
    function mint(
        uint256 shares,
        address receiver
    ) external returns (uint256 assets) {
        assets = previewMint(shares);

        vaultAsset.safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        _afterDeposit(assets, shares);
    }

    /// @notice Redeems `shares` from `owner` and sends `assets`
    /// of underlying tokens to `receiver`.
    function withdraw(
        uint256 assets,
        address receiver,
        address /*owner*/
    ) external returns (uint256 shares) {
        shares = previewWithdraw(assets);
        _withdraw(receiver, assets, shares);

        return shares;
    }

    /**
     * @dev Withdraw/redeem common workflow.
     */
    function _withdraw(
        address receiver,
        uint256 assets,
        uint256 shares
    ) internal virtual {
        // Conclusion: we need to do the transfer after the burn so that any reentrancy would happen after the
        // shares are burned and after the assets are transferred, which is a valid state.
        _burn(msg.sender, shares);
        SafeTransferLib.safeTransfer(vaultAsset, receiver, assets);

        emit Withdraw(msg.sender, receiver, assets, shares);
    }

    /// @notice Redeems `shares` from `owner` and sends `assets`
    /// of underlying tokens to `receiver`.
    function redeem(
        uint256 shares,
        address receiver,
        address /*owner*/
    ) external returns (uint256 assets) {
        assets = previewRedeem(shares);
        _withdraw(receiver, assets, shares);
    }

    /*////////////////////////////////////////////////////////
                      Vault Accounting Logic
    ////////////////////////////////////////////////////////*/

    function totalAssets() public view override returns (uint256) {
        return vaultAsset.balanceOf(address(this));
    }

    /// @notice The amount of shares that the vault would
    /// exchange for the amount of assets provided, in an
    /// ideal scenario where all the conditions are met.
    function convertToShares(
        uint256 assets
    ) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? assets : assets.mulDivDown(supply, totalAssets());
    }
    /// @notice The amount of assets that the vault would
    /// exchange for the amount of shares provided, in an
    /// ideal scenario where all the conditions are met.
    function convertToAssets(
        uint256 shares
    ) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivDown(totalAssets(), supply);
    }
    /// @notice Total number of underlying assets that can
    /// be deposited by `owner` into the Vault, where `owner`
    /// corresponds to the input parameter `receiver` of a
    /// `deposit` call.
    function maxDeposit(address) external pure returns (uint256 maxAssets) {
        return type(uint256).max;
    }

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their deposit at the current block, given
    /// current on-chain conditions.
    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    /// @notice Total number of underlying shares that can be minted
    /// for `owner`, where `owner` corresponds to the input
    /// parameter `receiver` of a `mint` call.
    function maxMint(address) external pure returns (uint256 maxShares) {
        return type(uint256).max;
    }

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their mint at the current block, given
    /// current on-chain conditions.
    function previewMint(uint256 shares) public view virtual returns (uint256) {
        uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

        return supply == 0 ? shares : shares.mulDivUp(totalAssets(), supply);
    }
    /// withdrawn from the Vault by `owner`, where `owner`
    /// corresponds to the input parameter of a `withdraw` call.
    function maxWithdraw(
        address owner
    ) external view returns (uint256 maxAssets) {
        return convertToAssets(vaultAsset.balanceOf(address(owner)));
    }

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their withdrawal at the current block,
    /// given current on-chain conditions.
    function previewWithdraw(
        uint256 assets
    ) public view returns (uint256 shares) {
        return convertToShares(assets);
    }

    /// @notice Total number of underlying shares that can be
    /// redeemed from the Vault by `owner`, where `owner` corresponds
    /// to the input parameter of a `redeem` call.
    function maxRedeem(address owner) external view returns (uint256) {
        return vaultAsset.balanceOf(owner);
    }

    /// @notice Allows an on-chain or off-chain user to simulate
    /// the effects of their redeemption at the current block,
    /// given current on-chain conditions.
    function previewRedeem(
        uint256 shares
    ) public view returns (uint256 assets) {
        return convertToAssets(shares);
    }

    /**
     * @dev Custom logic in here for how much the vault allows to be borrowed.
     * We return 100% of tokens for now. Under certain conditions we might
     * want to keep some of the system funds at hand in the vault, instead
     * of putting them to work.
     */
    function available() public view returns (uint256) {
        return vaultAsset.balanceOf(address(this));
    }

    /*////////////////////////////////////////////////////////
                      Strategy Logic
    ////////////////////////////////////////////////////////*/

    /**
     * @dev Function to send funds into the strategy and put them to work. It's primarily called
     * by the vault's deposit() function.
     */
    function earn() public {
        uint _bal = available();
        vaultAsset.safeTransfer(address(strategy), _bal);
        strategy.deposit();
    }

    /// @notice Sets a new strategy for the vault
    /// @dev This function can only be called by the owner of the contract
    /// @param _strategy The address of the new strategy contract to be set
    /// @custom:security-risk High - Ensure the new strategy is trusted and properly audited
    function setStrategy(IStrategy _strategy) external onlyOwner {
        strategy = _strategy;
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL HOOKS LOGIC
    //////////////////////////////////////////////////////////////*/

    function _beforeWithdraw(uint256 assets, uint256 shares) internal virtual {}

    function _afterDeposit(uint256 assets, uint256 shares) internal virtual {}
}
