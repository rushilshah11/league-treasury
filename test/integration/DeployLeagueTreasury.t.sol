// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {DeployLeagueTreasury} from "../../script/DeployLeagueTreasury.s.sol";
import {LeagueTreasury} from "../../src/LeagueTreasury.sol";

/// Integration test: runs the real deploy script, then drives the deployed
/// contract through a full join flow the way users would.
contract DeployLeagueTreasuryTest is Test {
    uint256 constant BUY_IN = 0.01 ether;
    uint8 constant TEAM_COUNT = 2;

    LeagueTreasury leagueTreasury;
    address commissioner = makeAddr("commissioner");
    address reporter = makeAddr("reporter");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function setUp() public {
        DeployLeagueTreasury deployer = new DeployLeagueTreasury();
        leagueTreasury = deployer.run();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
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
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );

        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN}(leagueId, 1);
        vm.prank(bob);
        leagueTreasury.joinLeague{value: BUY_IN}(leagueId, 2);

        (, , , uint8 memberCount, LeagueTreasury.LeagueState state, , , , ) = leagueTreasury.leagues(leagueId);
        assertEq(memberCount, TEAM_COUNT);
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.ACTIVE));
        assertEq(address(leagueTreasury).balance, BUY_IN * TEAM_COUNT);
    }
}
