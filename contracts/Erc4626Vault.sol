// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.17;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IERC4626.sol";
contract ERC4626Vault is IERC4626, ERC20 {

    /*//////////////////////////////////////////////////////////////
                               IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    ERC20 public immutable asset;

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol, _asset.decimals()) {
        asset = _asset;
    }

}