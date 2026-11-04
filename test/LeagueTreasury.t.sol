// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";

contract LeagueTreasuryTest is Test {
    LeagueTreasury public leagueTreasury;
    address public commissioner = makeAddr("commissioner");
    address public reporter = makeAddr("reporter");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    uint256 constant BUY_IN = 0.01 ether;
    uint8 constant TEAM_COUNT = 14;

    function _linearPayout(
        uint8 teamCount
    ) internal pure returns (uint16[] memory) {
        uint256 n = teamCount;
        uint256 weightSum = (n * (n + 1)) / 2; // Sum of first n natural numbers

        uint16[] memory payout = new uint16[](teamCount);
        uint256 totalBps = 0;
        for (uint8 i = 0; i < n; i++) {
            payout[i] = uint16(((n - i) * 10000) / weightSum);
            totalBps += payout[i];
        }
        // Adjust the first payout to ensure the total is exactly 10000 bps. give remaining to first place
        payout[0] += uint16(10000 - totalBps);
        return payout;
    }

    function _createLeague() internal returns (uint256 leagueId) {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        vm.prank(commissioner);
        leagueId = leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
        return leagueId;
    }

    function setUp() public {
        leagueTreasury = new LeagueTreasury();
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
    }

    function test_CreateLeague_IncrementsLeagueId() public {
        uint256 leagueId1 = _createLeague();
        assertEq(leagueId1, 0);
        uint256 leagueId2 = _createLeague();
        assertEq(leagueId2, leagueId1 + 1);
        assertEq(leagueTreasury.nextLeagueId(), 2);
    }

    function test_CreateLeague_StoresLeague() public {
        uint256 leagueId = _createLeague();

        (
            address c,
            uint64 joinDeadline,
            uint8 teamCount,
            uint8 memberCount,
            LeagueTreasury.LeagueState state,
            address r,
            uint64 standingsDeadline,
            uint256 buyIn
        ) = leagueTreasury.leagues(leagueId);

        assertEq(c, commissioner);
        assertEq(joinDeadline, uint64(block.timestamp + 1 days));
        assertEq(teamCount, TEAM_COUNT);
        assertEq(memberCount, 0);
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.OPEN));
        assertEq(r, reporter);
        assertEq(standingsDeadline, uint64(block.timestamp + 2 days));
        assertEq(buyIn, BUY_IN);
    }

    function test_CreateLeague_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCreated(
            0,
            commissioner,
            reporter,
            TEAM_COUNT,
            BUY_IN
        );
        _createLeague();
    }

    function test_CreateLeague_StoresPayoutTable() public {
        uint256 leagueId = _createLeague();
        uint16[] memory storedPayout = leagueTreasury.getPayoutBps(leagueId);

        assertEq(storedPayout.length, TEAM_COUNT);
        uint256 totalPayout = 0;
        uint16[] memory expectedPayout = _linearPayout(TEAM_COUNT);
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            totalPayout += storedPayout[i];
            assertEq(storedPayout[i], expectedPayout[i]);
        }
        assertEq(totalPayout, leagueTreasury.TOTAL_BPS());
    }

    function test_RevertWhen_TeamCountBelowTwo() public {
        uint16[] memory payout = _linearPayout(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidTeamCount.selector,
                1
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            1,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_PayoutLengthMismatch() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__PayoutLengthMismatch.selector,
                TEAM_COUNT,
                TEAM_COUNT - 1
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_BuyInIsZero() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidBuyIn.selector,
                0
            )
        );
        vm.prank(commissioner);

        leagueTreasury.createLeague(
            reporter,
            0,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_ReporterIsZeroAddress() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidReporter.selector,
                address(0)
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            address(0),
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_JoinDeadlineInPast() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 joinDeadline = uint64(block.timestamp);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidJoinDeadline.selector,
                joinDeadline
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            joinDeadline,
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_StandingsDeadlineBeforeJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury
                    .LeagueTreasury__InvalidStandingsDeadline
                    .selector,
                uint64(block.timestamp + 1 days),
                uint64(block.timestamp + 2 days)
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 2 days),
            uint64(block.timestamp + 1 days),
            payout
        );
    }

    function test_RevertWhen_StandingsDeadlineEqualsJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury
                    .LeagueTreasury__InvalidStandingsDeadline
                    .selector,
                uint64(block.timestamp + 1 days),
                uint64(block.timestamp + 1 days)
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 1 days),
            payout
        );
    }

    function test_RevertWhen_PayoutTotalWrong() public {
        uint16[] memory payout = new uint16[](TEAM_COUNT);
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            payout[i] = 1; // This will not sum to 10000 bps
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector,
                TEAM_COUNT
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }

    function test_RevertWhen_PayoutTotalOffByOne() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        payout[TEAM_COUNT - 1] -= 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector,
                9999
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout
        );
    }
}
