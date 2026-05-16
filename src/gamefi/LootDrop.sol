// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GameItems} from "./GameItems.sol";

contract LootDrop is AccessControl, ReentrancyGuard {
    bytes32 public constant VRF_COORDINATOR_ROLE = keccak256("VRF_COORDINATOR_ROLE");

    struct Request {
        address player;
        bool fulfilled;
    }

    GameItems public immutable items;
    uint256 public nextRequestId;

    mapping(uint256 requestId => Request) public requests;
    mapping(uint256 rollBucket => uint256 itemId) public lootTable;

    event LootRequested(uint256 indexed requestId, address indexed player);
    event LootFulfilled(uint256 indexed requestId, address indexed player, uint256 indexed itemId, uint256 randomness);
    event LootConfigured(uint256 indexed bucket, uint256 indexed itemId);

    constructor(address admin, GameItems items_) {
        require(address(items_) != address(0), "items zero");
        items = items_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VRF_COORDINATOR_ROLE, admin);
    }

    function setLoot(uint256 bucket, uint256 itemId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(bucket < 100, "bucket too high");
        require(itemId > 0, "item zero");
        lootTable[bucket] = itemId;
        emit LootConfigured(bucket, itemId);
    }

    function requestLoot() external nonReentrant returns (uint256 requestId) {
        requestId = ++nextRequestId;
        requests[requestId] = Request({player: msg.sender, fulfilled: false});
        emit LootRequested(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        external
        onlyRole(VRF_COORDINATOR_ROLE)
        nonReentrant
    {
        Request storage request = requests[requestId];
        require(request.player != address(0), "request missing");
        require(!request.fulfilled, "fulfilled");
        require(randomWords.length > 0, "random missing");

        request.fulfilled = true;
        uint256 bucket = randomWords[0] % 100;
        uint256 itemId = lootTable[bucket];
        if (itemId == 0) {
            itemId = lootTable[99];
        }
        require(itemId != 0, "loot unset");

        items.mint(request.player, itemId, 1, "");
        emit LootFulfilled(requestId, request.player, itemId, randomWords[0]);
    }
}
