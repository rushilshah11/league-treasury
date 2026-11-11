// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeagueTreasury} from "../../src/LeagueTreasury.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";

contract Handler is Test {
    LeagueTreasury public treasury;
    MockUSDC public usdc;
    address public reporter = makeAddr("reporter");
    address[] public actors; // the players Foundry can act as
    uint256[] public leagueIds; // leagues the handler has created

    // Ghost variables: what the handler believes has moved in and out of the treasury.
    uint256 public ghost_deposited;
    uint256 public ghost_refunded;

    uint256 internal constant STARTING_BALANCE = 1_000_000_000e6;
    uint256 internal constant MAX_BUY_IN = 1_000e6;

    constructor(LeagueTreasury _treasury, MockUSDC _usdc) {
        treasury = _treasury;
        usdc = _usdc;
        for (uint256 i = 0; i < 5; i++) {
            address actor = makeAddr(string.concat("actor", vm.toString(i)));
            actors.push(actor);
            // enough to buy into thousands of leagues at the max buy-in
            usdc.mint(actor, STARTING_BALANCE);
            vm.prank(actor);
            usdc.approve(address(treasury), type(uint256).max);
        }
    }

    function createLeague(uint256 actorSeed, uint256 buyIn, uint8 teamCount) external {
        address commissioner = actors[actorSeed % actors.length];
        buyIn = bound(buyIn, 1, MAX_BUY_IN);
        teamCount = uint8(bound(teamCount, 2, actors.length)); // can't have more teams than players

        vm.prank(commissioner);
        uint256 leagueId = treasury.createLeague(
            "Invariant League",
            LeagueTreasury.EspnLink(1, 2027, LeagueTreasury.Sport.BASKETBALL),
            reporter,
            buyIn,
            teamCount,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(teamCount),
            1 // commissioner takes team 1
        );
        leagueIds.push(leagueId);
        ghost_deposited += buyIn;
    }

    function joinLeague(uint256 leagueSeed, uint256 actorSeed) external {
        if (leagueIds.length == 0) return; // nothing to join yet
        uint256 leagueId = leagueIds[leagueSeed % leagueIds.length];
        address player = actors[actorSeed % actors.length];

        (, uint64 joinDeadline,, uint8 memberCount, LeagueTreasury.LeagueState state,,, uint256 buyIn,,) =
            treasury.leagues(leagueId);
        if (state != LeagueTreasury.LeagueState.OPEN) return;
        if (block.timestamp >= joinDeadline) return;
        (, bool joined,,) = treasury.members(leagueId, player);
        if (joined) return;

        // Members never leave an OPEN league, so teams 1..memberCount are taken
        // and memberCount + 1 is always free.
        vm.prank(player);
        treasury.joinLeague(leagueId, uint32(memberCount) + 1);
        ghost_deposited += buyIn;
    }

    function warp(uint256 seconds_) external {
        seconds_ = bound(seconds_, 1 hours, 3 days);
        vm.warp(block.timestamp + seconds_);
    }

    function withdrawRefund(uint256 leagueSeed, uint256 actorSeed) external {
        if (leagueIds.length == 0) return;
        uint256 leagueId = leagueIds[leagueSeed % leagueIds.length];
        address player = actors[actorSeed % actors.length];

        if (!treasury.isRefundable(leagueId)) return;
        (, bool joined, bool claimed,) = treasury.members(leagueId, player);
        if (!joined || claimed) return;

        (,,,,,,, uint256 buyIn,,) = treasury.leagues(leagueId);
        vm.prank(player);
        treasury.withdrawRefund(leagueId);
        ghost_refunded += buyIn;
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function leagueCount() external view returns (uint256) {
        return leagueIds.length;
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    /// Same as _linearPayout in LeagueTreasury.t.sol: weights n..1, remainder to 1st place.
    function _linearPayout(uint8 teamCount) internal pure returns (uint16[] memory payout) {
        uint256 n = teamCount;
        uint256 weightSum = (n * (n + 1)) / 2;
        payout = new uint16[](teamCount);
        uint256 totalBps = 0;
        for (uint256 i = 0; i < n; i++) {
            payout[i] = uint16(((n - i) * 10000) / weightSum);
            totalBps += payout[i];
        }
        payout[0] += uint16(10000 - totalBps);
    }
}
