# GameFi Economy Final Project

Option B implementation for the Blockchain Technologies 2 final project.

## Implemented Criteria

- ERC1155 in-game items and resources: `src/gamefi/GameItems.sol`
- Crafting with DAO-governed recipe costs: `src/gamefi/GameParametersV1.sol`
- Constant-product AMM for fungible ERC1155 resources with 0.3% fee and LP token: `src/gamefi/ResourceAMM.sol`
- NFT rental vault with temporary `userOf`: `src/gamefi/NFTRentalVault.sol`
- Chainlink-style VRF loot fulfillment hook: `src/gamefi/LootDrop.sol`
- Chainlink price feed adapter with stale-price check: `src/gamefi/ChainlinkPriceOracle.sol`
- ERC20Votes + ERC20Permit governance token: `src/gamefi/GameToken.sol`
- OpenZeppelin Governor + TimelockController: `src/governance/GameGovernor.sol`
- ERC4626 treasury vault: `src/gamefi/GameTreasuryVault.sol`
- UUPS upgrade path V1 to V2: `src/gamefi/GameParametersV1.sol`, `src/gamefi/GameParametersV2.sol`
- Factory using CREATE and CREATE2: `src/gamefi/ResourceAMMFactory.sol`
- Inline Yul benchmark target: `src/gamefi/CraftingMath.sol`
- Subgraph: `subgraph/`
- Frontend dApp: `frontend/`
- CI pipeline: `.github/workflows/ci.yml`
- Architecture, audit, gas, coverage, and deployment docs: `docs/`

## Commands

```shell
forge build
forge test -vv
forge coverage --report summary
```

Frontend:

```shell
cd frontend
npm install
npm run dev
```

## L2 Deployment

Target network: Arbitrum Sepolia.

```shell
forge script script/DeployGameFi.s.sol:DeployGameFi \
  --rpc-url $ARBITRUM_SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ARBISCAN_API_KEY
```

After deployment, fill `docs/deployment-addresses.md`, update `subgraph/subgraph.yaml`, and run:

```shell
forge script script/VerifyDeployment.s.sol:VerifyDeployment --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

## GraphQL Queries

```graphql
{ crafts(first: 10, orderBy: timestamp, orderDirection: desc) { player inputId outputId inputAmount } }
{ pools(first: 5) { id reserveA reserveB swaps liquidityEvents } }
{ swaps(first: 10, orderBy: timestamp, orderDirection: desc) { trader tokenIn amountIn tokenOut amountOut } }
{ liquidityPositions(first: 10) { provider liquidityAdded liquidityRemoved } }
{ rentals(where: { active: true }) { owner renter nft tokenId expiresAt } }
```

## Current Local Verification

`forge test -vv`: 23 passed, 0 failed.

Real L2 addresses and explorer verification require funded deployer credentials and RPC/API keys.
