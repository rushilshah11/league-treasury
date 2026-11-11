// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockUSDC} from "../test/mocks/MockUSDC.sol";

contract DeployLeagueTreasury is Script {
    address public constant USDC_SEPOLIA = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant USDC_BASE_SEPOLIA = 0x036CbD53842c5426634e7929541eC2318f3dCF7e;

    IERC20 usdc;

    function run() external returns (LeagueTreasury) {
        vm.startBroadcast();

        if (block.chainid == 11155111) {
            usdc = IERC20(USDC_SEPOLIA);
        } else if (block.chainid == 84532) {
            usdc = IERC20(USDC_BASE_SEPOLIA);
        } else if (block.chainid == 31337) {
            MockUSDC mockUSDC = new MockUSDC();
            usdc = IERC20(address(mockUSDC));
        } else {
            revert("Unsupported chain");
        }

        LeagueTreasury leagueTreasury = new LeagueTreasury(usdc);

        vm.stopBroadcast();
        return leagueTreasury;
    }
}
