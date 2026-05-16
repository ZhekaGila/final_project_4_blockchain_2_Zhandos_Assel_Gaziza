// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {SharedInvestmentPool} from "../src/SharedInvestmentPool.sol";

contract SharedInvestmentPoolTest is Test {
    SharedInvestmentPool private pool;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);

    function setUp() public {
        pool = new SharedInvestmentPool();
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }

    function testProfitIsSplitByContribution() public {
        vm.prank(alice);
        pool.invest{value: 1 ether}();

        vm.prank(bob);
        pool.invest{value: 3 ether}();

        pool.distributeProfit{value: 4 ether}();

        assertEq(pool.pendingProfit(alice), 1 ether);
        assertEq(pool.pendingProfit(bob), 3 ether);
    }

    function testInvestorKeepsEarnedProfitWhenContributionChanges() public {
        vm.prank(alice);
        pool.invest{value: 1 ether}();

        pool.distributeProfit{value: 1 ether}();

        vm.prank(alice);
        pool.invest{value: 1 ether}();

        pool.distributeProfit{value: 2 ether}();

        assertEq(pool.pendingProfit(alice), 3 ether);
    }

    function testClaimProfitPaysInvestor() public {
        vm.prank(alice);
        pool.invest{value: 2 ether}();

        pool.distributeProfit{value: 1 ether}();

        uint256 beforeBalance = alice.balance;
        vm.prank(alice);
        pool.claimProfit();

        assertEq(alice.balance, beforeBalance + 1 ether);
        assertEq(pool.pendingProfit(alice), 0);
    }
}
