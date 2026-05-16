// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameParametersV1} from "./GameParametersV1.sol";

contract GameParametersV2 is GameParametersV1 {
    uint256 public craftingFeeBps;

    event CraftingFeeSet(uint256 basisPoints);

    function setCraftingFeeBps(uint256 basisPoints) external onlyOwner {
        require(basisPoints <= 1_000, "fee too high");
        craftingFeeBps = basisPoints;
        emit CraftingFeeSet(basisPoints);
    }

    function version() external pure override returns (string memory) {
        return "v2";
    }
}
