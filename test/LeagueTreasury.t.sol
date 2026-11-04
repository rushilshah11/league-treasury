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
    uint256 constant STARTING_BALANCE = 1 ether;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _linearPayout(
        uint8 teamCount
    ) internal pure returns (uint16[] memory) {
        uint256 n = teamCount;
        uint256 weightSum = (n * (n + 1)) / 2; // sum of 1..n

        uint16[] memory payout = new uint16[](teamCount);
        uint256 totalBps = 0;
        for (uint8 i = 0; i < n; i++) {
            payout[i] = uint16(((n - i) * 10000) / weightSum);
            totalBps += payout[i];
        }
        // give the rounding remainder to 1st place so the total is exactly 10000
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
    }

    function _join(address who, uint256 leagueId, uint32 teamId) internal {
        vm.prank(who);
        leagueTreasury.joinLeague{value: BUY_IN}(leagueId, teamId);
    }

    /// Fills every slot in the league with generated members (teams 1..TEAM_COUNT).
    function _fillLeague(uint256 leagueId) internal {
        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            address member = makeAddr(string.concat("member", vm.toString(i)));
            vm.deal(member, STARTING_BALANCE);
            _join(member, leagueId, i);
        }
    }

    function _state(
        uint256 leagueId
    ) internal view returns (LeagueTreasury.LeagueState state) {
        (, , , , state, , , ) = leagueTreasury.leagues(leagueId);
    }

    function _memberCount(
        uint256 leagueId
    ) internal view returns (uint8 memberCount) {
        (, , , memberCount, , , , ) = leagueTreasury.leagues(leagueId);
    }

    function setUp() public {
        leagueTreasury = new LeagueTreasury();
        vm.deal(alice, STARTING_BALANCE);
        vm.deal(bob, STARTING_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          createLeague: happy path
    //////////////////////////////////////////////////////////////*/

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
        uint16[] memory expectedPayout = _linearPayout(TEAM_COUNT);

        assertEq(storedPayout.length, TEAM_COUNT);
        uint256 totalPayout = 0;
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            totalPayout += storedPayout[i];
            assertEq(storedPayout[i], expectedPayout[i]);
        }
        assertEq(totalPayout, leagueTreasury.TOTAL_BPS());
    }

    /*//////////////////////////////////////////////////////////////
                          createLeague: reverts
    //////////////////////////////////////////////////////////////*/

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

    function test_RevertWhen_JoinDeadlineNotInFuture() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 joinDeadline = uint64(block.timestamp); // exactly "now" is not allowed

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
        uint64 joinDeadline = uint64(block.timestamp + 2 days);
        uint64 standingsDeadline = uint64(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury
                    .LeagueTreasury__InvalidStandingsDeadline
                    .selector,
                standingsDeadline,
                joinDeadline
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            joinDeadline,
            standingsDeadline,
            payout
        );
    }

    function test_RevertWhen_StandingsDeadlineEqualsJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 deadline = uint64(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury
                    .LeagueTreasury__InvalidStandingsDeadline
                    .selector,
                deadline,
                deadline
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter,
            BUY_IN,
            TEAM_COUNT,
            deadline,
            deadline,
            payout
        );
    }

    function test_RevertWhen_PayoutTotalWrong() public {
        uint16[] memory payout = new uint16[](TEAM_COUNT);
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            payout[i] = 1; // sums to 14, not 10000
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
        uint16[] memory payout = _linearPayout(TEAM_COUNT); // sums to 10000
        payout[TEAM_COUNT - 1] -= 1; // now sums to 9999

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

    /*//////////////////////////////////////////////////////////////
                           joinLeague: happy path
    //////////////////////////////////////////////////////////////*/

    function test_JoinLeague_StoresMember() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        (
            uint32 teamId,
            bool joined,
            bool claimed,
            uint8 finalPlace
        ) = leagueTreasury.members(leagueId, alice);

        assertEq(teamId, 1);
        assertTrue(joined);
        assertFalse(claimed);
        assertEq(finalPlace, 0);
    }

    function test_JoinLeague_RecordsTeamOwner() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        assertEq(leagueTreasury.teamOwners(leagueId, 1), alice);
    }

    function test_JoinLeague_TakesBuyIn() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        assertEq(address(leagueTreasury).balance, BUY_IN);
        assertEq(alice.balance, STARTING_BALANCE - BUY_IN);
    }

    function test_JoinLeague_IncrementsMemberCount() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        _join(bob, leagueId, 2);

        assertEq(_memberCount(leagueId), 2);
        assertEq(
            uint8(_state(leagueId)),
            uint8(LeagueTreasury.LeagueState.OPEN)
        );
    }

    function test_JoinLeague_ActivatesWhenFull() public {
        uint256 leagueId = _createLeague();
        _fillLeague(leagueId);

        assertEq(_memberCount(leagueId), TEAM_COUNT);
        assertEq(
            uint8(_state(leagueId)),
            uint8(LeagueTreasury.LeagueState.ACTIVE)
        );
        assertEq(address(leagueTreasury).balance, BUY_IN * TEAM_COUNT);
    }

    function test_JoinLeague_EmitsMemberJoined() public {
        uint256 leagueId = _createLeague();

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.MemberJoined(leagueId, alice, 1);
        _join(alice, leagueId, 1);
    }

    function test_JoinLeague_EmitsLeagueActivatedOnLastJoin() public {
        uint256 leagueId = _createLeague();

        // fill every slot except the last one
        for (uint32 i = 1; i < TEAM_COUNT; i++) {
            address member = makeAddr(string.concat("member", vm.toString(i)));
            vm.deal(member, STARTING_BALANCE);
            _join(member, leagueId, i);
        }

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueActivated(leagueId);
        _join(alice, leagueId, TEAM_COUNT);
    }

    /*//////////////////////////////////////////////////////////////
                            joinLeague: reverts
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_JoiningLeagueThatDoesNotExist() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__LeagueNotFound.selector,
                0
            )
        );
        _join(alice, 0, 1);
    }

    function test_RevertWhen_JoiningFullLeague() public {
        uint256 leagueId = _createLeague();
        _fillLeague(leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__LeagueNotOpen.selector,
                leagueId,
                LeagueTreasury.LeagueState.ACTIVE
            )
        );
        _join(alice, leagueId, 99);
    }

    function test_RevertWhen_JoiningAtJoinDeadline() public {
        uint256 leagueId = _createLeague();
        uint64 joinDeadline = uint64(block.timestamp + 1 days);
        vm.warp(joinDeadline); // exactly at the deadline, joining is closed

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__JoinDeadlinePassed.selector,
                leagueId,
                joinDeadline
            )
        );
        _join(alice, leagueId, 1);
    }

    function test_RevertWhen_TeamIdIsZero() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidTeamId.selector,
                0
            )
        );
        _join(alice, leagueId, 0);
    }

    function test_RevertWhen_TeamAlreadyTaken() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__TeamAlreadyTaken.selector,
                leagueId,
                1
            )
        );
        _join(bob, leagueId, 1);
    }

    function test_RevertWhen_BuyInTooLow() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector,
                BUY_IN - 1,
                BUY_IN
            )
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN - 1}(leagueId, 1);
    }

    function test_RevertWhen_BuyInTooHigh() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector,
                BUY_IN + 1,
                BUY_IN
            )
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN + 1}(leagueId, 1);
    }

    function test_RevertWhen_MemberJoinsTwice() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__MemberAlreadyJoined.selector,
                leagueId,
                alice
            )
        );
        _join(alice, leagueId, 2);
    }
}
