// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GameToken} from "../src/gamefi/GameToken.sol";
import {GameItems} from "../src/gamefi/GameItems.sol";
import {GameParametersV1} from "../src/gamefi/GameParametersV1.sol";
import {ResourceAMMFactory} from "../src/gamefi/ResourceAMMFactory.sol";
import {GameTreasuryVault} from "../src/gamefi/GameTreasuryVault.sol";
import {LootDrop} from "../src/gamefi/LootDrop.sol";
import {NFTRentalVault} from "../src/gamefi/NFTRentalVault.sol";
import {ChainlinkPriceOracle} from "../src/gamefi/ChainlinkPriceOracle.sol";
import {GameGovernor} from "../src/governance/GameGovernor.sol";

contract DeployGameFi is Script {
    uint256 public constant TIMELOCK_DELAY = 2 days;

    function run() external {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        address chainlinkFeed = vm.envOr("CHAINLINK_FEED", address(0x0000000000000000000000000000000000000001));
        uint256 staleAfter = vm.envOr("STALE_AFTER", uint256(1 hours));

        vm.startBroadcast();

        GameToken token = new GameToken(deployer);
        GameParametersV1 parametersImpl = new GameParametersV1();
        ERC1967Proxy parametersProxy = new ERC1967Proxy(
            address(parametersImpl), abi.encodeCall(GameParametersV1.initialize, (deployer, staleAfter))
        );
        GameParametersV1 parameters = GameParametersV1(address(parametersProxy));

        GameItems items = new GameItems(deployer, vm.envOr("ITEM_BASE_URI", string("ipfs://gamefi/{id}.json")));
        items.setParameters(address(parameters));

        ResourceAMMFactory factory = new ResourceAMMFactory();
        GameTreasuryVault vault = new GameTreasuryVault(token, deployer);
        LootDrop loot = new LootDrop(deployer, items);
        NFTRentalVault rentalVault = new NFTRentalVault();
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(chainlinkFeed, staleAfter);

        address[] memory proposers = new address[](1);
        proposers[0] = deployer;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(TIMELOCK_DELAY, proposers, executors, deployer);
        GameGovernor governor = new GameGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.PROPOSER_ROLE(), deployer);
        timelock.revokeRole(timelock.CANCELLER_ROLE(), deployer);

        token.transferOwnership(address(timelock));
        parameters.transferOwnership(address(timelock));
        vault.transferOwnership(address(timelock));

        items.grantRole(items.DEFAULT_ADMIN_ROLE(), address(timelock));
        items.grantRole(items.MINTER_ROLE(), address(loot));
        items.grantRole(items.PAUSER_ROLE(), address(timelock));
        items.renounceRole(items.DEFAULT_ADMIN_ROLE(), deployer);
        items.renounceRole(items.PAUSER_ROLE(), deployer);

        loot.grantRole(loot.DEFAULT_ADMIN_ROLE(), address(timelock));
        loot.renounceRole(loot.DEFAULT_ADMIN_ROLE(), deployer);

        oracle;
        factory;
        rentalVault;

        vm.stopBroadcast();
    }
}
