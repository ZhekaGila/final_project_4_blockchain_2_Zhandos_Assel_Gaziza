// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";

contract ChainlinkPriceOracle {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable staleAfter;

    error StalePrice(uint256 updatedAt, uint256 staleAfter);
    error InvalidPrice();

    constructor(address feed_, uint256 staleAfter_) {
        require(feed_ != address(0), "feed zero");
        require(staleAfter_ > 0, "stale zero");
        feed = AggregatorV3Interface(feed_);
        staleAfter = staleAfter_;
    }

    function latestPrice() external view returns (int256 answer, uint8 decimals, uint256 updatedAt) {
        (, answer,, updatedAt,) = feed.latestRoundData();
        if (answer <= 0) {
            revert InvalidPrice();
        }
        if (block.timestamp - updatedAt > staleAfter) {
            revert StalePrice(updatedAt, staleAfter);
        }
        decimals = feed.decimals();
    }
}
