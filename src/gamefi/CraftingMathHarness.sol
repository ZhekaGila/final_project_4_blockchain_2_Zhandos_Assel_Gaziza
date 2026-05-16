// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {CraftingMath} from "./CraftingMath.sol";

contract CraftingMathHarness {
    function solidityCost(uint256 unitCost, uint256 amount) external pure returns (uint256) {
        return CraftingMath.totalCostSolidity(unitCost, amount);
    }

    function yulCost(uint256 unitCost, uint256 amount) external pure returns (uint256) {
        return CraftingMath.totalCostYul(unitCost, amount);
    }
}
