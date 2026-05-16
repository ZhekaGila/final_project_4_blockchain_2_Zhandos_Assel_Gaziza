// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {LPToken} from "./LPToken.sol";

contract ResourceAMM is ERC1155Holder, ReentrancyGuard {
    uint256 public constant FEE_DENOMINATOR = 1_000;
    uint256 public constant SWAP_FEE = 3;

    IERC1155 public immutable items;
    uint256 public immutable resourceA;
    uint256 public immutable resourceB;
    LPToken public immutable lpToken;

    uint256 public reserveA;
    uint256 public reserveB;

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swapped(
        address indexed trader, uint256 indexed tokenIn, uint256 amountIn, uint256 tokenOut, uint256 amountOut
    );

    constructor(address items_, uint256 resourceA_, uint256 resourceB_) {
        require(items_ != address(0), "items zero");
        require(resourceA_ != resourceB_, "same resource");
        items = IERC1155(items_);
        resourceA = resourceA_;
        resourceB = resourceB_;
        lpToken = new LPToken(address(this));
    }

    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLiquidity)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        require(amountA > 0 && amountB > 0, "amount zero");

        uint256 supply = lpToken.totalSupply();
        if (supply == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            liquidity = Math.min((amountA * supply) / reserveA, (amountB * supply) / reserveB);
        }
        require(liquidity >= minLiquidity && liquidity > 0, "slippage");

        reserveA += amountA;
        reserveB += amountB;

        items.safeTransferFrom(msg.sender, address(this), resourceA, amountA, "");
        items.safeTransferFrom(msg.sender, address(this), resourceB, amountB, "");
        lpToken.mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity, uint256 minA, uint256 minB)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        require(liquidity > 0, "liquidity zero");
        uint256 supply = lpToken.totalSupply();

        amountA = (liquidity * reserveA) / supply;
        amountB = (liquidity * reserveB) / supply;
        require(amountA >= minA && amountB >= minB, "slippage");

        reserveA -= amountA;
        reserveB -= amountB;
        lpToken.burn(msg.sender, liquidity);

        items.safeTransferFrom(address(this), msg.sender, resourceA, amountA, "");
        items.safeTransferFrom(address(this), msg.sender, resourceB, amountB, "");

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapExactInput(uint256 tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "amount zero");
        require(tokenIn == resourceA || tokenIn == resourceB, "bad resource");

        bool aToB = tokenIn == resourceA;
        uint256 reserveIn = aToB ? reserveA : reserveB;
        uint256 reserveOut = aToB ? reserveB : reserveA;
        uint256 tokenOut = aToB ? resourceB : resourceA;
        require(reserveIn > 0 && reserveOut > 0, "empty pool");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE);
        amountOut = (amountInWithFee * reserveOut) / ((reserveIn * FEE_DENOMINATOR) + amountInWithFee);
        require(amountOut >= minAmountOut && amountOut > 0, "slippage");

        if (aToB) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        items.safeTransferFrom(msg.sender, address(this), tokenIn, amountIn, "");
        items.safeTransferFrom(address(this), msg.sender, tokenOut, amountOut, "");

        emit Swapped(msg.sender, tokenIn, amountIn, tokenOut, amountOut);
    }

    function quoteSwap(uint256 tokenIn, uint256 amountIn) external view returns (uint256) {
        require(tokenIn == resourceA || tokenIn == resourceB, "bad resource");
        bool aToB = tokenIn == resourceA;
        uint256 reserveIn = aToB ? reserveA : reserveB;
        uint256 reserveOut = aToB ? reserveB : reserveA;
        if (reserveIn == 0 || reserveOut == 0 || amountIn == 0) {
            return 0;
        }
        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - SWAP_FEE);
        return (amountInWithFee * reserveOut) / ((reserveIn * FEE_DENOMINATOR) + amountInWithFee);
    }
}
