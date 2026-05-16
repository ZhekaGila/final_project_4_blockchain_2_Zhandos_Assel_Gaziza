// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GameTreasuryVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    constructor(IERC20 asset_, address owner_)
        ERC20("GameFi Treasury Vault", "gVAULT")
        ERC4626(asset_)
        Ownable(owner_)
    {}

    function sweepFees(address to, uint256 assets) external onlyOwner {
        require(to != address(0), "to zero");
        IERC20(asset()).safeTransfer(to, assets);
    }
}
