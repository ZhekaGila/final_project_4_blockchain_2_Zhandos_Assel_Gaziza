// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ResourceAMM} from "./ResourceAMM.sol";

contract ResourceAMMFactory {
    event PoolCreated(
        address indexed pool, address indexed items, uint256 indexed resourceA, uint256 resourceB, bytes32 salt
    );

    address[] public allPools;

    function createPool(address items, uint256 resourceA, uint256 resourceB) external returns (address pool) {
        pool = address(new ResourceAMM(items, resourceA, resourceB));
        allPools.push(pool);
        emit PoolCreated(pool, items, resourceA, resourceB, bytes32(0));
    }

    function createPoolDeterministic(address items, uint256 resourceA, uint256 resourceB, bytes32 salt)
        external
        returns (address pool)
    {
        pool = address(new ResourceAMM{salt: salt}(items, resourceA, resourceB));
        allPools.push(pool);
        emit PoolCreated(pool, items, resourceA, resourceB, salt);
    }

    function predictPool(address items, uint256 resourceA, uint256 resourceB, bytes32 salt)
        external
        view
        returns (address)
    {
        bytes32 bytecodeHash =
            keccak256(abi.encodePacked(type(ResourceAMM).creationCode, abi.encode(items, resourceA, resourceB)));
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, bytecodeHash)))));
    }

    function poolCount() external view returns (uint256) {
        return allPools.length;
    }
}
