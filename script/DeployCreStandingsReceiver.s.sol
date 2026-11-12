// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";
import {CreStandingsReceiver} from "../src/CreStandingsReceiver.sol";

/// Deploys the contract that lets a Chainlink CRE workflow post league standings.
///
/// Reads from .env:
///   TREASURY_ADDRESS   the deployed LeagueTreasury
///   DEPLOYER_ADDRESS   becomes the receiver's owner (can change the forwarder and workflow checks)
///   CRE_FORWARDER      optional: the forwarder to trust. Defaults to Chainlink's simulation
///                      forwarder on Base Sepolia, which is what `cre workflow simulate --broadcast` uses.
contract DeployCreStandingsReceiver is Script {
    // Chainlink's MockKeystoneForwarder on Base Sepolia (from the CRE forwarder directory).
    address public constant MOCK_FORWARDER_BASE_SEPOLIA = 0x82300bd7c3958625581cc2F77bC6464dcEcDF3e5;

    function run() external returns (CreStandingsReceiver) {
        require(block.chainid == 84532, "Base Sepolia only");

        LeagueTreasury treasury = LeagueTreasury(vm.envAddress("TREASURY_ADDRESS"));
        address owner = vm.envAddress("DEPLOYER_ADDRESS");
        address forwarder = vm.envOr("CRE_FORWARDER", MOCK_FORWARDER_BASE_SEPOLIA);

        vm.startBroadcast();
        CreStandingsReceiver receiver = new CreStandingsReceiver(treasury, forwarder, owner);
        vm.stopBroadcast();

        return receiver;
    }
}
