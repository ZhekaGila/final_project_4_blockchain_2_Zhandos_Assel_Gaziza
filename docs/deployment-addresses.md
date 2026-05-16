# L2 Deployment Addresses

Chosen L2: Arbitrum Sepolia.

Run:

```shell
forge script script/DeployGameFi.s.sol:DeployGameFi --rpc-url $ARBITRUM_SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ARBISCAN_API_KEY
forge script script/VerifyDeployment.s.sol:VerifyDeployment --rpc-url $ARBITRUM_SEPOLIA_RPC_URL
```

| Contract | Address | Explorer |
| --- | --- | --- |
| GameToken | TBD | TBD |
| GameParameters Proxy | TBD | TBD |
| GameItems | TBD | TBD |
| ResourceAMMFactory | TBD | TBD |
| GameTreasuryVault | TBD | TBD |
| LootDrop | TBD | TBD |
| NFTRentalVault | TBD | TBD |
| ChainlinkPriceOracle | TBD | TBD |
| TimelockController | TBD | TBD |
| GameGovernor | TBD | TBD |
