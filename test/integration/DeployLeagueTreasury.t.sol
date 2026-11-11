// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployLeagueTreasury} from "../../script/DeployLeagueTreasury.s.sol";
import {LeagueTreasury} from "../../src/LeagueTreasury.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

/// Integration test: runs the real deploy script, then drives the deployed
/// contract through a full join flow the way users would.
contract DeployLeagueTreasuryTest is Test {
    uint256 constant BUY_IN = 20e6; // 20 USDC
    uint8 constant TEAM_COUNT = 2;
    uint64 constant ESPN_LEAGUE_ID = 87654321;

    LeagueTreasury leagueTreasury;
    MockUSDC usdc;
    address commissioner = makeAddr("commissioner");
    address reporter = makeAddr("reporter");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        DeployLeagueTreasury deployer = new DeployLeagueTreasury();
        leagueTreasury = deployer.run();
        // on the local chain the script deploys a MockUSDC; the treasury knows its address
        usdc = MockUSDC(address(leagueTreasury.usdc()));
        _fund(commissioner);
        _fund(alice);
        _fund(bob);
    }

    function _fund(address who) internal {
        usdc.mint(who, 100e6);
        vm.prank(who);
        usdc.approve(address(leagueTreasury), type(uint256).max);
    }

    function test_DeployScript_DeploysFreshContract() public view {
        assertGt(address(leagueTreasury).code.length, 0);
        assertEq(leagueTreasury.nextLeagueId(), 0);
    }

    function test_DeployedContract_CreateAndFillLeague() public {
        uint16[] memory payout = new uint16[](TEAM_COUNT);
        payout[0] = 6000;
        payout[1] = 4000;

        vm.prank(commissioner);
        uint256 leagueId = leagueTreasury.createLeague(
            "Integration League",
            LeagueTreasury.EspnLink(ESPN_LEAGUE_ID, 2027, LeagueTreasury.Sport.BASKETBALL),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            1 // the commissioner takes team 1
        );

        vm.prank(alice);
        leagueTreasury.joinLeague(leagueId, 2);

        (,,, uint8 memberCount, LeagueTreasury.LeagueState state,,,,,) = leagueTreasury.leagues(leagueId);
        assertEq(memberCount, TEAM_COUNT);
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.ACTIVE));
        assertEq(usdc.balanceOf(address(leagueTreasury)), BUY_IN * TEAM_COUNT);
    }
}
