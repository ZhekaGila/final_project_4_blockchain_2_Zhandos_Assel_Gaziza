// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {SharedInvestmentPool} from "../src/SharedInvestmentPool.sol";
import {NFTRenting} from "../src/NFTRenting.sol";

contract DeployTasks is Script {
    function run() public returns (SharedInvestmentPool pool, NFTRenting renting) {
        vm.startBroadcast();

        pool = new SharedInvestmentPool();
        renting = new NFTRenting();

        vm.stopBroadcast();
    }
}
