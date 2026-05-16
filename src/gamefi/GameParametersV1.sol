// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GameParametersV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    mapping(uint256 outputId => mapping(uint256 inputId => uint256 cost)) private _craftingCosts;
    mapping(uint256 lootId => uint16 basisPoints) public dropRateBps;
    uint256 public stalePriceWindow;

    event CraftingCostSet(uint256 indexed outputId, uint256 indexed inputId, uint256 cost);
    event DropRateSet(uint256 indexed lootId, uint16 basisPoints);
    event StalePriceWindowSet(uint256 window);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialOwner, uint256 initialStalePriceWindow) public initializer {
        __Ownable_init(initialOwner);
        stalePriceWindow = initialStalePriceWindow;
    }

    function setCraftingCost(uint256 outputId, uint256 inputId, uint256 cost) external onlyOwner {
        _craftingCosts[outputId][inputId] = cost;
        emit CraftingCostSet(outputId, inputId, cost);
    }

    function setDropRate(uint256 lootId, uint16 basisPoints) external onlyOwner {
        require(basisPoints <= 10_000, "rate too high");
        dropRateBps[lootId] = basisPoints;
        emit DropRateSet(lootId, basisPoints);
    }

    function setStalePriceWindow(uint256 window) external onlyOwner {
        require(window > 0, "window zero");
        stalePriceWindow = window;
        emit StalePriceWindowSet(window);
    }

    function craftingCost(uint256 outputId, uint256 inputId) external view returns (uint256) {
        return _craftingCosts[outputId][inputId];
    }

    function version() external pure virtual returns (string memory) {
        return "v1";
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
