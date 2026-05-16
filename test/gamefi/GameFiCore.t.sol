// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {GameToken} from "../../src/gamefi/GameToken.sol";
import {GameItems} from "../../src/gamefi/GameItems.sol";
import {GameParametersV1} from "../../src/gamefi/GameParametersV1.sol";
import {GameParametersV2} from "../../src/gamefi/GameParametersV2.sol";
import {ResourceAMM} from "../../src/gamefi/ResourceAMM.sol";
import {ResourceAMMFactory} from "../../src/gamefi/ResourceAMMFactory.sol";
import {GameTreasuryVault} from "../../src/gamefi/GameTreasuryVault.sol";
import {LootDrop} from "../../src/gamefi/LootDrop.sol";
import {NFTRentalVault} from "../../src/gamefi/NFTRentalVault.sol";
import {ChainlinkPriceOracle} from "../../src/gamefi/ChainlinkPriceOracle.sol";
import {CraftingMathHarness} from "../../src/gamefi/CraftingMathHarness.sol";
import {GameGovernor} from "../../src/governance/GameGovernor.sol";

contract MockAggregator {
    int256 public answer = 2_000e8;
    uint8 public decimals = 8;
    uint256 public updatedAt = block.timestamp;

    function setAnswer(int256 newAnswer) external {
        answer = newAnswer;
    }

    function setUpdatedAt(uint256 newUpdatedAt) external {
        updatedAt = newUpdatedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, answer, updatedAt, updatedAt, 1);
    }
}

contract MockGameNFT is ERC721 {
    constructor() ERC721("Game NFT", "GNFT") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}

contract GameFiCoreTest is Test {
    address private admin = address(this);
    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    GameToken private token;
    GameItems private items;
    GameParametersV1 private parameters;

    function setUp() public {
        token = new GameToken(admin);
        GameParametersV1 implementation = new GameParametersV1();
        ERC1967Proxy proxy =
            new ERC1967Proxy(address(implementation), abi.encodeCall(GameParametersV1.initialize, (admin, 1 hours)));
        parameters = GameParametersV1(address(proxy));
        items = new GameItems(admin, "ipfs://game/{id}.json");
        items.setParameters(address(parameters));
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testGovernanceTokenHasVotesAndPermitName() public {
        token.delegate(admin);
        assertEq(token.getVotes(admin), token.balanceOf(admin));
        assertEq(token.name(), "GameFi Governance");
    }

    function testCraftingBurnsInputAndMintsOutput() public {
        parameters.setCraftingCost(10, 1, 3);
        items.mint(alice, 1, 9, "");

        vm.prank(alice);
        items.craft(1, 10, 2);

        assertEq(items.balanceOf(alice, 1), 3);
        assertEq(items.balanceOf(alice, 10), 2);
    }

    function testCraftingRevertsWhenRecipeMissing() public {
        items.mint(alice, 1, 9, "");

        vm.prank(alice);
        vm.expectRevert("recipe missing");
        items.craft(1, 10, 1);
    }

    function testUUPSUpgradePreservesStorageAndAddsV2State() public {
        parameters.setCraftingCost(10, 1, 3);
        GameParametersV2 v2 = new GameParametersV2();

        parameters.upgradeToAndCall(address(v2), "");
        GameParametersV2 upgraded = GameParametersV2(address(parameters));
        upgraded.setCraftingFeeBps(250);

        assertEq(upgraded.version(), "v2");
        assertEq(upgraded.craftingFeeBps(), 250);
        assertEq(upgraded.craftingCost(10, 1), 3);
    }

    function testFactoryCreateAndCreate2Pools() public {
        ResourceAMMFactory factory = new ResourceAMMFactory();
        address poolA = factory.createPool(address(items), 1, 2);
        bytes32 salt = keccak256("pool-b");
        address predicted = factory.predictPool(address(items), 3, 4, salt);
        address poolB = factory.createPoolDeterministic(address(items), 3, 4, salt);

        assertEq(factory.poolCount(), 2);
        assertEq(poolB, predicted);
        assertTrue(poolA != address(0));
    }

    function testResourceAMMSwapUsesConstantProductFee() public {
        ResourceAMM amm = new ResourceAMM(address(items), 1, 2);
        items.mint(alice, 1, 2_000, "");
        items.mint(alice, 2, 2_000, "");
        items.mint(bob, 1, 100, "");

        vm.startPrank(alice);
        items.setApprovalForAll(address(amm), true);
        amm.addLiquidity(1_000, 1_000, 900);
        vm.stopPrank();

        uint256 quote = amm.quoteSwap(1, 100);

        vm.startPrank(bob);
        items.setApprovalForAll(address(amm), true);
        amm.swapExactInput(1, 100, quote);
        vm.stopPrank();

        assertEq(items.balanceOf(bob, 2), quote);
        assertGt(amm.reserveA() * amm.reserveB(), 1_000_000);
    }

    function testAMMRevertsOnSlippage() public {
        ResourceAMM amm = new ResourceAMM(address(items), 1, 2);
        items.mint(alice, 1, 2_000, "");
        items.mint(alice, 2, 2_000, "");
        items.mint(bob, 1, 100, "");

        vm.startPrank(alice);
        items.setApprovalForAll(address(amm), true);
        amm.addLiquidity(1_000, 1_000, 1);
        vm.stopPrank();

        vm.startPrank(bob);
        items.setApprovalForAll(address(amm), true);
        vm.expectRevert("slippage");
        amm.swapExactInput(1, 100, 10_000);
        vm.stopPrank();
    }

    function testTreasuryVaultDepositsAndWithdraws() public {
        GameTreasuryVault vault = new GameTreasuryVault(token, admin);
        assertTrue(token.transfer(alice, 1_000 ether));

        vm.startPrank(alice);
        token.approve(address(vault), 100 ether);
        uint256 shares = vault.deposit(100 ether, alice);
        vault.redeem(shares, alice, alice);
        vm.stopPrank();

        assertEq(vault.balanceOf(alice), 0);
        assertEq(token.balanceOf(alice), 1_000 ether);
    }

    function testLootDropMintsVRFFulfilledLoot() public {
        LootDrop loot = new LootDrop(admin, items);
        items.grantRole(items.MINTER_ROLE(), address(loot));
        loot.setLoot(99, 42);

        vm.prank(alice);
        uint256 requestId = loot.requestLoot();

        uint256[] memory words = new uint256[](1);
        words[0] = 123;
        loot.fulfillRandomWords(requestId, words);

        assertEq(items.balanceOf(alice, 42), 1);
    }

    function testRentalVaultGivesTemporaryUser() public {
        NFTRentalVault vault = new NFTRentalVault();
        MockGameNFT nft = new MockGameNFT();
        nft.mint(alice, 7);

        vm.startPrank(alice);
        nft.approve(address(vault), 7);
        vault.list(address(nft), 7, 1 ether, 1 days);
        vm.stopPrank();

        vm.prank(bob);
        vault.rent{value: 1 ether}(address(nft), 7);

        assertEq(vault.userOf(address(nft), 7), bob);
        vm.warp(block.timestamp + 1 days);
        assertEq(vault.userOf(address(nft), 7), address(0));
    }

    function testOracleRejectsStalePrice() public {
        vm.warp(10 hours);
        MockAggregator feed = new MockAggregator();
        ChainlinkPriceOracle oracle = new ChainlinkPriceOracle(address(feed), 1 hours);
        feed.setUpdatedAt(block.timestamp - 2 hours);

        vm.expectRevert(
            abi.encodeWithSelector(ChainlinkPriceOracle.StalePrice.selector, block.timestamp - 2 hours, 1 hours)
        );
        oracle.latestPrice();
    }

    function testCraftingMathYulMatchesSolidity(uint96 unitCost, uint96 amount) public {
        CraftingMathHarness harness = new CraftingMathHarness();
        assertEq(harness.yulCost(unitCost, amount), harness.solidityCost(unitCost, amount));
    }

    function testGovernorParametersMatchSpec() public {
        address[] memory proposers = new address[](1);
        proposers[0] = admin;
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        TimelockController timelock = new TimelockController(2 days, proposers, executors, admin);
        GameGovernor governor = new GameGovernor(token, timelock);

        assertEq(governor.votingDelay(), 1 days);
        assertEq(governor.votingPeriod(), 1 weeks);
        assertEq(governor.quorumNumerator(), 4);
        assertEq(timelock.getMinDelay(), 2 days);
    }
}
