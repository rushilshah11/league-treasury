// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";

contract DeployLeagueTreasury is Script {
    function run() external returns (LeagueTreasury) {
        vm.startBroadcast();
        LeagueTreasury leagueTreasury = new LeagueTreasury();
        vm.stopBroadcast();
        return leagueTreasury;
    }
}
