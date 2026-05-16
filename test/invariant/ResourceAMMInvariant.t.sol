// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {GameItems} from "../../src/gamefi/GameItems.sol";
import {ResourceAMM} from "../../src/gamefi/ResourceAMM.sol";

contract AMMHandler is Test, ERC1155Holder {
    GameItems public items;
    ResourceAMM public amm;
    uint256 public lastK;

    constructor(GameItems items_, ResourceAMM amm_) {
        items = items_;
        amm = amm_;
        items_.setApprovalForAll(address(amm_), true);
        lastK = amm_.reserveA() * amm_.reserveB();
    }

    function swapA(uint96 amount) external {
        amount = uint96(bound(amount, 1, 10));
        uint256 quote = amm.quoteSwap(1, amount);
        if (quote > 0) {
            amm.swapExactInput(1, amount, 0);
            lastK = amm.reserveA() * amm.reserveB();
        }
    }
}

contract ResourceAMMInvariantTest is StdInvariant, Test, ERC1155Holder {
    ResourceAMM private amm;
    AMMHandler private handler;

    function setUp() public {
        GameItems items = new GameItems(address(this), "");
        amm = new ResourceAMM(address(items), 1, 2);

        items.mint(address(this), 1, 10_000, "");
        items.mint(address(this), 2, 10_000, "");
        items.setApprovalForAll(address(amm), true);
        amm.addLiquidity(5_000, 5_000, 1);

        handler = new AMMHandler(items, amm);
        items.mint(address(handler), 1, 10_000, "");
        targetContract(address(handler));
    }

    function invariant_KNeverDecreasesAfterSwap() public view {
        assertGe(amm.reserveA() * amm.reserveB(), handler.lastK());
    }
}
