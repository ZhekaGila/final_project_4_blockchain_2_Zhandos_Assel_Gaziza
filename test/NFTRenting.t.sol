// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFTRenting} from "../src/NFTRenting.sol";

contract MockNFT {
    mapping(uint256 => address) public ownerOf;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function transferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "not owner");
        require(msg.sender == from || isApprovedForAll[from][msg.sender], "not approved");
        ownerOf[tokenId] = to;
    }
}

contract NFTRentingTest is Test {
    NFTRenting private renting;
    MockNFT private nft;

    address private owner = address(0xA11CE);
    address private renter = address(0xB0B);
    uint256 private tokenId = 1;

    function setUp() public {
        renting = new NFTRenting();
        nft = new MockNFT();
        nft.mint(owner, tokenId);
        vm.deal(renter, 10 ether);

        vm.prank(owner);
        nft.setApprovalForAll(address(renting), true);
    }

    function testOwnerCanListAndRenterTemporarilyUsesNFT() public {
        vm.prank(owner);
        renting.list(address(nft), tokenId, 1 ether, 7 days);

        vm.prank(renter);
        renting.rent{value: 1 ether}(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), address(renting));
        assertEq(renting.ownerOfDeposit(address(nft), tokenId), owner);
        assertEq(renting.userOf(address(nft), tokenId), renter);
    }

    function testTemporaryUseExpires() public {
        vm.prank(owner);
        renting.list(address(nft), tokenId, 1 ether, 1 days);

        vm.prank(renter);
        renting.rent{value: 1 ether}(address(nft), tokenId);

        vm.warp(block.timestamp + 1 days);

        assertEq(renting.userOf(address(nft), tokenId), address(0));

        renting.endRental(address(nft), tokenId);
        vm.prank(owner);
        renting.withdrawNFT(address(nft), tokenId);

        assertEq(nft.ownerOf(tokenId), owner);
    }

    function testOwnerCanClaimRent() public {
        vm.prank(owner);
        renting.list(address(nft), tokenId, 2 ether, 1 days);

        vm.prank(renter);
        renting.rent{value: 2 ether}(address(nft), tokenId);

        uint256 beforeBalance = owner.balance;
        vm.prank(owner);
        renting.claimRent();

        assertEq(owner.balance, beforeBalance + 2 ether);
    }
}
