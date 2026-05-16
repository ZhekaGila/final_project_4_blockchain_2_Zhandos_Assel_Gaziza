// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GameGovernor} from "../src/governance/GameGovernor.sol";
import {GameToken} from "../src/gamefi/GameToken.sol";

contract VerifyDeployment is Script {
    function run() external view {
        GameGovernor governor = GameGovernor(payable(vm.envAddress("GOVERNOR")));
        TimelockController timelock = TimelockController(payable(vm.envAddress("TIMELOCK")));
        GameToken token = GameToken(vm.envAddress("GAME_TOKEN"));

        require(governor.votingDelay() == 1 days, "bad voting delay");
        require(governor.votingPeriod() == 1 weeks, "bad voting period");
        require(governor.quorumNumerator() == 4, "bad quorum");
        require(governor.proposalThreshold() == 10_000 ether, "bad proposal threshold");
        require(timelock.getMinDelay() == 2 days, "bad timelock delay");
        require(token.owner() == address(timelock), "token owner not timelock");

        console2.log("Deployment verification passed");
    }
}
