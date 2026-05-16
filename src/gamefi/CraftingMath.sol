// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CraftingMath {
    function totalCostSolidity(uint256 unitCost, uint256 amount) internal pure returns (uint256) {
        return unitCost * amount;
    }

    function totalCostYul(uint256 unitCost, uint256 amount) internal pure returns (uint256 result) {
        assembly {
            if and(iszero(iszero(unitCost)), gt(amount, div(not(0), unitCost))) {
                mstore(0x00, 0x4e487b71)
                mstore(0x20, 0x11)
                revert(0x1c, 0x24)
            }
            result := mul(unitCost, amount)
        }
    }
}
