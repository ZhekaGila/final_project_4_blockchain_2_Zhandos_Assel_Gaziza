// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NFTRentalVault is ERC721Holder, ReentrancyGuard {
    struct RentalListing {
        address owner;
        address renter;
        address nft;
        uint256 tokenId;
        uint256 price;
        uint64 duration;
        uint64 expiresAt;
    }

    mapping(bytes32 key => RentalListing) public listings;
    mapping(address owner => uint256 balance) public ownerBalances;

    event Listed(address indexed owner, address indexed nft, uint256 indexed tokenId, uint256 price, uint64 duration);
    event Rented(address indexed renter, address indexed nft, uint256 indexed tokenId, uint64 expiresAt);
    event Unlisted(address indexed owner, address indexed nft, uint256 indexed tokenId);
    event RentClaimed(address indexed owner, uint256 amount);

    function list(address nft, uint256 tokenId, uint256 price, uint64 duration) external nonReentrant {
        require(nft != address(0), "nft zero");
        require(price > 0, "price zero");
        require(duration > 0, "duration zero");

        bytes32 key = _key(nft, tokenId);
        require(listings[key].owner == address(0), "listed");

        listings[key] = RentalListing({
            owner: msg.sender,
            renter: address(0),
            nft: nft,
            tokenId: tokenId,
            price: price,
            duration: duration,
            expiresAt: 0
        });

        IERC721(nft).safeTransferFrom(msg.sender, address(this), tokenId);
        emit Listed(msg.sender, nft, tokenId, price, duration);
    }

    function rent(address nft, uint256 tokenId) external payable nonReentrant {
        RentalListing storage listing = listings[_key(nft, tokenId)];
        require(listing.owner != address(0), "not listed");
        require(!_active(listing), "active");
        require(msg.value == listing.price, "wrong price");

        listing.renter = msg.sender;
        listing.expiresAt = uint64(block.timestamp + listing.duration);
        ownerBalances[listing.owner] += msg.value;

        emit Rented(msg.sender, nft, tokenId, listing.expiresAt);
    }

    function unlist(address nft, uint256 tokenId) external nonReentrant {
        bytes32 key = _key(nft, tokenId);
        RentalListing storage listing = listings[key];
        require(msg.sender == listing.owner, "not owner");
        require(!_active(listing), "active");

        address owner = listing.owner;
        delete listings[key];
        IERC721(nft).safeTransferFrom(address(this), owner, tokenId);

        emit Unlisted(owner, nft, tokenId);
    }

    function claimRent() external nonReentrant {
        uint256 amount = ownerBalances[msg.sender];
        require(amount > 0, "nothing to claim");
        ownerBalances[msg.sender] = 0;

        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "transfer failed");

        emit RentClaimed(msg.sender, amount);
    }

    function userOf(address nft, uint256 tokenId) external view returns (address) {
        RentalListing storage listing = listings[_key(nft, tokenId)];
        return _active(listing) ? listing.renter : address(0);
    }

    function _active(RentalListing storage listing) private view returns (bool) {
        return listing.renter != address(0) && block.timestamp < listing.expiresAt;
    }

    function _key(address nft, uint256 tokenId) private pure returns (bytes32) {
        return keccak256(abi.encode(nft, tokenId));
    }
}
