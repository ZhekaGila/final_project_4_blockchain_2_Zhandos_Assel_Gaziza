# Gas Optimization Report

## Benchmarked Areas

`CraftingMathHarness` compares pure Solidity multiplication with an inline Yul equivalent. `ResourceAMM` uses cached reserves and immutable token ids. Rental and vault flows use pull payments.

## L1 vs L2 Estimate Table

Replace estimates with measured deployment output after running scripts on Sepolia and the chosen L2.

| Operation | Ethereum Sepolia gas | Arbitrum Sepolia gas | Notes |
| --- | ---: | ---: | --- |
| Craft item | TBD | TBD | ERC1155 burn + mint |
| Add liquidity | TBD | TBD | Two ERC1155 transfers + LP mint |
| Swap resource | TBD | TBD | Constant product swap |
| Rent NFT | TBD | TBD | ETH payment + state update |
| Claim rent | TBD | TBD | Pull payment |
| Propose vote | TBD | TBD | Governor proposal |

## Before/After Notes

SafeERC20 was added to the vault sweep path so ERC20 return values are handled correctly.

AMM reserve values are stored explicitly instead of reading ERC1155 balances repeatedly.
