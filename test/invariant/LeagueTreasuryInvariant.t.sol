// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {LeagueTreasury} from "../../src/LeagueTreasury.sol";
import {MockUSDC} from "../mocks/MockUSDC.sol";
import {Handler} from "./Handler.sol";

contract LeagueTreasuryInvariantTest is StdInvariant, Test {
    LeagueTreasury treasury;
    MockUSDC usdc;
    Handler handler;

    function setUp() public {
        usdc = new MockUSDC();
        treasury = new LeagueTreasury(usdc);
        handler = new Handler(treasury, usdc);

        // Only let Foundry call the handler's action functions
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = Handler.createLeague.selector;
        selectors[1] = Handler.joinLeague.selector;
        selectors[2] = Handler.warp.selector;
        selectors[3] = Handler.withdrawRefund.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    /// Invariant 1: the contract's balance matches the handler's own bookkeeping.
    function invariant_BalanceMatchesGhostAccounting() public view {
        assertEq(usdc.balanceOf(address(treasury)), handler.ghost_deposited() - handler.ghost_refunded());
    }

    /// Invariant 2: the contract holds exactly what it owes, no more (stuck) and no less (insolvent).
    function invariant_BalanceEqualsWhatIsOwed() public view {
        uint256 owed;
        uint256 leagueCount = handler.leagueCount();
        uint256 actorCount = handler.actorCount();

        for (uint256 i = 0; i < leagueCount; i++) {
            uint256 leagueId = handler.leagueIds(i);
            (,,,, LeagueTreasury.LeagueState state,,, uint256 buyIn,,) = treasury.leagues(leagueId);

            for (uint256 j = 0; j < actorCount; j++) {
                address actor = handler.actors(j);
                (, bool joined, bool claimed,) = treasury.members(leagueId, actor);
                if (!joined || claimed) continue;

                if (state == LeagueTreasury.LeagueState.FINALIZED) {
                    owed += treasury.getPayout(leagueId, actor);
                } else {
                    owed += buyIn;
                }
            }
        }

        assertEq(usdc.balanceOf(address(treasury)), owed);
    }
}
