// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

interface IGameParameters {
    function craftingCost(uint256 outputId, uint256 inputId) external view returns (uint256);
}

contract GameItems is ERC1155, AccessControl, Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    IGameParameters public parameters;

    event Crafted(address indexed player, uint256 indexed inputId, uint256 indexed outputId, uint256 inputAmount);
    event ParametersUpdated(address indexed parameters);

    constructor(address admin, string memory baseUri) ERC1155(baseUri) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function setParameters(address newParameters) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newParameters != address(0), "parameters zero");
        parameters = IGameParameters(newParameters);
        emit ParametersUpdated(newParameters);
    }

    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data)
        external
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
    }

    function craft(uint256 inputId, uint256 outputId, uint256 outputAmount) external whenNotPaused {
        require(address(parameters) != address(0), "parameters unset");
        require(outputAmount > 0, "amount zero");

        uint256 cost = parameters.craftingCost(outputId, inputId) * outputAmount;
        require(cost > 0, "recipe missing");

        _burn(msg.sender, inputId, cost);
        _mint(msg.sender, outputId, outputAmount, "");

        emit Crafted(msg.sender, inputId, outputId, cost);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
