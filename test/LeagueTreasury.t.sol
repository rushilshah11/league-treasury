// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";
import {RejectingWallet, ReentrantWallet} from "./mocks/MaliciousWallets.sol";

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

    function _linearPayout(uint8 teamCount) internal pure returns (uint16[] memory) {
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
            reporter, BUY_IN, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
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

    /// Ranking where team i finishes in place i (team 1 wins, team 14 is last).
    function _ranking() internal pure returns (uint32[] memory ranking) {
        ranking = new uint32[](TEAM_COUNT);
        for (uint32 i = 0; i < TEAM_COUNT; i++) {
            ranking[i] = i + 1;
        }
    }

    /// Creates a league and fills it, so it's ACTIVE and ready for standings.
    function _activeLeague() internal returns (uint256 leagueId) {
        leagueId = _createLeague();
        _fillLeague(leagueId);
    }

    function _submit(uint256 leagueId, uint32[] memory ranking) internal {
        vm.prank(reporter);
        leagueTreasury.submitStandings(leagueId, ranking);
    }

    function _member(uint32 teamId) internal returns (address) {
        return makeAddr(string.concat("member", vm.toString(teamId)));
    }

    function _finalPlace(uint256 leagueId, address who) internal view returns (uint8 finalPlace) {
        (,,, finalPlace) = leagueTreasury.members(leagueId, who);
    }

    /// Active league with standings submitted (team i in place i). Window is open.
    function _submittedLeague() internal returns (uint256 leagueId) {
        leagueId = _activeLeague();
        _submit(leagueId, _ranking());
    }

    /// Submitted league that member1 (team 1's owner) has disputed.
    function _disputedLeague() internal returns (uint256 leagueId) {
        leagueId = _submittedLeague();
        vm.prank(_member(1));
        leagueTreasury.dispute(leagueId);
    }

    /// Ranking where team 14 wins and team 1 is last.
    function _reversedRanking() internal pure returns (uint32[] memory ranking) {
        ranking = new uint32[](TEAM_COUNT);
        for (uint32 i = 0; i < TEAM_COUNT; i++) {
            ranking[i] = TEAM_COUNT - i;
        }
    }

    function _disputedAt(uint256 leagueId) internal view returns (uint64 disputedAt) {
        (,,,,,,,,, disputedAt) = leagueTreasury.leagues(leagueId);
    }

    /// Submitted league with the challenge window passed and finalize() called.
    function _finalizedLeague() internal returns (uint256 leagueId) {
        leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());
        leagueTreasury.finalize(leagueId);
    }

    function _claim(address who, uint256 leagueId) internal returns (uint256 received) {
        uint256 before = who.balance;
        vm.prank(who);
        leagueTreasury.claim(leagueId);
        received = who.balance - before;
    }

    /// Runs a full league of `teamCount` teams with `buyIn`, from creation to
    /// finalization. Team i finishes in place i. Members are named "fm<i>".
    function _runFullLeague(uint8 teamCount, uint256 buyIn) internal returns (uint256 leagueId) {
        vm.prank(commissioner);
        leagueId = leagueTreasury.createLeague(
            reporter,
            buyIn,
            teamCount,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(teamCount)
        );
        uint32[] memory ranking = new uint32[](teamCount);
        for (uint32 i = 1; i <= teamCount; i++) {
            address m = makeAddr(string.concat("fm", vm.toString(i)));
            vm.deal(m, buyIn);
            vm.prank(m);
            leagueTreasury.joinLeague{value: buyIn}(leagueId, i);
            ranking[i - 1] = i;
        }
        _submit(leagueId, ranking);
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());
        leagueTreasury.finalize(leagueId);
    }

    /// Joins all teams except the last, then has `wallet` join with the last team.
    /// Returns the league after standings are finalized, with the wallet in `place`.
    function _finalizedLeagueWithContractMember(address wallet, bool isReentrant, uint32 place)
        internal
        returns (uint256 leagueId)
    {
        leagueId = _createLeague();
        for (uint32 i = 1; i < TEAM_COUNT; i++) {
            address member = _member(i);
            vm.deal(member, STARTING_BALANCE);
            _join(member, leagueId, i);
        }
        vm.deal(address(this), BUY_IN);
        if (isReentrant) {
            ReentrantWallet(payable(wallet)).join{value: BUY_IN}(leagueId, TEAM_COUNT);
        } else {
            RejectingWallet(wallet).join{value: BUY_IN}(leagueId, TEAM_COUNT);
        }

        // put the contract wallet's team (TEAM_COUNT) in `place`
        uint32[] memory ranking = new uint32[](TEAM_COUNT);
        uint32 next = 1;
        for (uint32 pos = 1; pos <= TEAM_COUNT; pos++) {
            if (pos == place) {
                ranking[pos - 1] = TEAM_COUNT;
            } else {
                ranking[pos - 1] = next++;
            }
        }
        _submit(leagueId, ranking);
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());
        leagueTreasury.finalize(leagueId);
    }

    function _claimed(uint256 leagueId, address who) internal view returns (bool claimed) {
        (,, claimed,) = leagueTreasury.members(leagueId, who);
    }

    function _refund(address who, uint256 leagueId) internal returns (uint256 received) {
        uint256 before = who.balance;
        vm.prank(who);
        leagueTreasury.withdrawRefund(leagueId);
        received = who.balance - before;
    }

    function _state(uint256 leagueId) internal view returns (LeagueTreasury.LeagueState state) {
        (,,,, state,,,,,) = leagueTreasury.leagues(leagueId);
    }

    function _memberCount(uint256 leagueId) internal view returns (uint8 memberCount) {
        (,,, memberCount,,,,,,) = leagueTreasury.leagues(leagueId);
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
            uint256 buyIn,
            uint64 standingsSubmittedAt,
        ) = leagueTreasury.leagues(leagueId);

        assertEq(c, commissioner);
        assertEq(joinDeadline, uint64(block.timestamp + 1 days));
        assertEq(teamCount, TEAM_COUNT);
        assertEq(memberCount, 0);
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.OPEN));
        assertEq(r, reporter);
        assertEq(standingsDeadline, uint64(block.timestamp + 2 days));
        assertEq(buyIn, BUY_IN);
        assertEq(standingsSubmittedAt, 0);
    }

    function test_CreateLeague_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCreated(0, commissioner, reporter, TEAM_COUNT, BUY_IN);
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

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamCount.selector, 1));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, BUY_IN, 1, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_PayoutLengthMismatch() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__PayoutLengthMismatch.selector, TEAM_COUNT, TEAM_COUNT - 1
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, BUY_IN, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_BuyInIsZero() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidBuyIn.selector, 0));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, 0, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_ReporterIsZeroAddress() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidReporter.selector, address(0)));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            address(0), BUY_IN, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_JoinDeadlineNotInFuture() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 joinDeadline = uint64(block.timestamp); // exactly "now" is not allowed

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidJoinDeadline.selector, joinDeadline)
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, BUY_IN, TEAM_COUNT, joinDeadline, uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_StandingsDeadlineBeforeJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 joinDeadline = uint64(block.timestamp + 2 days);
        uint64 standingsDeadline = uint64(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidStandingsDeadline.selector, standingsDeadline, joinDeadline
            )
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(reporter, BUY_IN, TEAM_COUNT, joinDeadline, standingsDeadline, payout);
    }

    function test_RevertWhen_StandingsDeadlineEqualsJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 deadline = uint64(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidStandingsDeadline.selector, deadline, deadline)
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague(reporter, BUY_IN, TEAM_COUNT, deadline, deadline, payout);
    }

    function test_RevertWhen_PayoutTotalWrong() public {
        uint16[] memory payout = new uint16[](TEAM_COUNT);
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            payout[i] = 1; // sums to 14, not 10000
        }

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector, TEAM_COUNT));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, BUY_IN, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    function test_RevertWhen_PayoutTotalOffByOne() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT); // sums to 10000
        payout[TEAM_COUNT - 1] -= 1; // now sums to 9999

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector, 9999));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            reporter, BUY_IN, TEAM_COUNT, uint64(block.timestamp + 1 days), uint64(block.timestamp + 2 days), payout
        );
    }

    /*//////////////////////////////////////////////////////////////
                           joinLeague: happy path
    //////////////////////////////////////////////////////////////*/

    function test_JoinLeague_StoresMember() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        (uint32 teamId, bool joined, bool claimed, uint8 finalPlace) = leagueTreasury.members(leagueId, alice);

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
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.OPEN));
    }

    function test_JoinLeague_ActivatesWhenFull() public {
        uint256 leagueId = _createLeague();
        _fillLeague(leagueId);

        assertEq(_memberCount(leagueId), TEAM_COUNT);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.ACTIVE));
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
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__LeagueNotFound.selector, 0));
        _join(alice, 0, 1);
    }

    function test_RevertWhen_JoiningFullLeague() public {
        uint256 leagueId = _createLeague();
        _fillLeague(leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__LeagueNotOpen.selector, leagueId, LeagueTreasury.LeagueState.ACTIVE
            )
        );
        _join(alice, leagueId, 99);
    }

    function test_RevertWhen_JoiningAtJoinDeadline() public {
        uint256 leagueId = _createLeague();
        uint64 joinDeadline = uint64(block.timestamp + 1 days);
        vm.warp(joinDeadline); // exactly at the deadline, joining is closed

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__JoinDeadlinePassed.selector, leagueId, joinDeadline)
        );
        _join(alice, leagueId, 1);
    }

    function test_RevertWhen_TeamIdIsZero() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 0));
        _join(alice, leagueId, 0);
    }

    function test_RevertWhen_TeamAlreadyTaken() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__TeamAlreadyTaken.selector, leagueId, 1));
        _join(bob, leagueId, 1);
    }

    function test_RevertWhen_BuyInTooLow() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector, BUY_IN - 1, BUY_IN)
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN - 1}(leagueId, 1);
    }

    function test_RevertWhen_BuyInTooHigh() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector, BUY_IN + 1, BUY_IN)
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN + 1}(leagueId, 1);
    }

    function test_RevertWhen_MemberJoinsTwice() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__MemberAlreadyJoined.selector, leagueId, alice)
        );
        _join(alice, leagueId, 2);
    }

    /*//////////////////////////////////////////////////////////////
                        submitStandings: happy path
    //////////////////////////////////////////////////////////////*/

    function test_SubmitStandings_SetsFinalPlaces() public {
        uint256 leagueId = _activeLeague();
        _submit(leagueId, _ranking());

        for (uint32 teamId = 1; teamId <= TEAM_COUNT; teamId++) {
            assertEq(_finalPlace(leagueId, _member(teamId)), teamId);
        }
    }

    function test_SubmitStandings_ReversedRanking() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = new uint32[](TEAM_COUNT);
        for (uint32 i = 0; i < TEAM_COUNT; i++) {
            ranking[i] = TEAM_COUNT - i; // team 14 wins, team 1 is last
        }
        _submit(leagueId, ranking);

        assertEq(_finalPlace(leagueId, _member(TEAM_COUNT)), 1);
        assertEq(_finalPlace(leagueId, _member(1)), TEAM_COUNT);
    }

    function test_SubmitStandings_UpdatesStateAndTimestamp() public {
        uint256 leagueId = _activeLeague();
        _submit(leagueId, _ranking());

        (,,,, LeagueTreasury.LeagueState state,,,, uint64 submittedAt,) = leagueTreasury.leagues(leagueId);
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.STANDINGS_SUBMITTED));
        assertEq(submittedAt, uint64(block.timestamp));
    }

    function test_SubmitStandings_EmitsEvent() public {
        uint256 leagueId = _activeLeague();

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.StandingsSubmitted(leagueId, uint64(block.timestamp));
        _submit(leagueId, _ranking());
    }

    function test_SubmitStandings_JustBeforeDeadline() public {
        uint256 leagueId = _activeLeague();
        vm.warp(block.timestamp + 2 days - 1); // one second before the standings deadline
        _submit(leagueId, _ranking());

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.STANDINGS_SUBMITTED));
    }

    /*//////////////////////////////////////////////////////////////
                          submitStandings: reverts
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_NonReporterSubmits() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = _ranking();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotReporter.selector, alice));
        vm.prank(alice);
        leagueTreasury.submitStandings(leagueId, ranking);
    }

    function test_RevertWhen_SubmittingForMissingLeague() public {
        uint32[] memory ranking = _ranking();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__LeagueNotFound.selector, 0));
        _submit(0, ranking);
    }

    function test_RevertWhen_SubmittingBeforeLeagueIsFull() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        uint32[] memory ranking = _ranking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.ACTIVE,
                LeagueTreasury.LeagueState.OPEN
            )
        );
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_SubmittingTwice() public {
        uint256 leagueId = _activeLeague();
        _submit(leagueId, _ranking());
        uint32[] memory ranking = _ranking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.ACTIVE,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED
            )
        );
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_SubmittingAtStandingsDeadline() public {
        uint256 leagueId = _activeLeague();
        uint64 standingsDeadline = uint64(block.timestamp + 2 days);
        vm.warp(standingsDeadline);
        uint32[] memory ranking = _ranking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__StandingsDeadlinePassed.selector, leagueId, standingsDeadline
            )
        );
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_RankingTooShort() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = new uint32[](TEAM_COUNT - 1);
        for (uint32 i = 0; i < TEAM_COUNT - 1; i++) {
            ranking[i] = i + 1;
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__RankingLengthMismatch.selector, TEAM_COUNT, TEAM_COUNT - 1
            )
        );
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_RankingHasUnknownTeam() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = _ranking();
        ranking[5] = 99; // no one registered team 99

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 99));
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_RankingHasTeamZero() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = _ranking();
        ranking[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 0));
        _submit(leagueId, ranking);
    }

    function test_RevertWhen_RankingHasDuplicateTeam() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = _ranking();
        ranking[1] = 1; // team 1 listed 1st and 2nd; team 2 is missing

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__DuplicateTeam.selector, 1));
        _submit(leagueId, ranking);
    }

    /*//////////////////////////////////////////////////////////////
                                 dispute
    //////////////////////////////////////////////////////////////*/

    function test_Dispute_SetsStateAndTimestamp() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + 1 hours);

        vm.prank(_member(1));
        leagueTreasury.dispute(leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.DISPUTED));
        assertEq(_disputedAt(leagueId), uint64(block.timestamp));
    }

    function test_Dispute_EmitsEvent() public {
        uint256 leagueId = _submittedLeague();
        address disputer = _member(3);

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.StandingsDisputed(leagueId, disputer);
        vm.prank(disputer);
        leagueTreasury.dispute(leagueId);
    }

    function test_Dispute_OneSecondBeforeWindowCloses() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW() - 1);

        vm.prank(_member(1));
        leagueTreasury.dispute(leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.DISPUTED));
    }

    function test_RevertWhen_NonMemberDisputes() public {
        uint256 leagueId = _submittedLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, alice));
        vm.prank(alice); // alice never joined this league
        leagueTreasury.dispute(leagueId);
    }

    function test_RevertWhen_DisputingBeforeStandingsSubmitted() public {
        uint256 leagueId = _activeLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.ACTIVE
            )
        );
        vm.prank(_member(1));
        leagueTreasury.dispute(leagueId);
    }

    function test_RevertWhen_DisputingTwice() public {
        uint256 leagueId = _disputedLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.DISPUTED
            )
        );
        vm.prank(_member(2));
        leagueTreasury.dispute(leagueId);
    }

    function test_RevertWhen_DisputingAtWindowClose() public {
        uint256 leagueId = _submittedLeague();
        uint256 windowEnd = block.timestamp + leagueTreasury.CHALLENGE_WINDOW();
        vm.warp(windowEnd);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ChallengeWindowClosed.selector, leagueId, windowEnd)
        );
        vm.prank(_member(1));
        leagueTreasury.dispute(leagueId);
    }

    /*//////////////////////////////////////////////////////////////
                                finalize
    //////////////////////////////////////////////////////////////*/

    function test_Finalize_AtWindowClose() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());

        leagueTreasury.finalize(leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_Finalize_AnyoneCanCall() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());

        vm.prank(makeAddr("randomStranger"));
        leagueTreasury.finalize(leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_Finalize_EmitsEvent() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.StandingsFinalized(leagueId);
        leagueTreasury.finalize(leagueId);
    }

    function test_RevertWhen_FinalizingWhileWindowOpen() public {
        uint256 leagueId = _submittedLeague();
        uint256 windowEnd = block.timestamp + leagueTreasury.CHALLENGE_WINDOW();
        vm.warp(windowEnd - 1);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ChallengeWindowOpen.selector, leagueId, windowEnd)
        );
        leagueTreasury.finalize(leagueId);
    }

    function test_RevertWhen_FinalizingDisputedLeague() public {
        uint256 leagueId = _disputedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.DISPUTED
            )
        );
        leagueTreasury.finalize(leagueId);
    }

    function test_RevertWhen_FinalizingBeforeStandings() public {
        uint256 leagueId = _activeLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.ACTIVE
            )
        );
        leagueTreasury.finalize(leagueId);
    }

    function test_RevertWhen_FinalizingTwice() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + leagueTreasury.CHALLENGE_WINDOW());
        leagueTreasury.finalize(leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.FINALIZED
            )
        );
        leagueTreasury.finalize(leagueId);
    }

    /*//////////////////////////////////////////////////////////////
                             resolveDispute
    //////////////////////////////////////////////////////////////*/

    function test_ResolveDispute_ReplacesPlaces() public {
        uint256 leagueId = _disputedLeague();

        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, _reversedRanking());

        for (uint32 teamId = 1; teamId <= TEAM_COUNT; teamId++) {
            // team 14 is now 1st, team 1 is now 14th
            assertEq(_finalPlace(leagueId, _member(teamId)), TEAM_COUNT - teamId + 1);
        }
    }

    function test_ResolveDispute_WithSameRanking() public {
        // the commissioner can also confirm the original standings
        uint256 leagueId = _disputedLeague();

        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, _ranking());

        assertEq(_finalPlace(leagueId, _member(1)), 1);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_ResolveDispute_FinalizesAndEmits() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.DisputeResolved(leagueId);
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_RevertWhen_NonCommissionerResolves() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotCommissioner.selector, reporter));
        vm.prank(reporter); // even the reporter can't resolve disputes
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_RevertWhen_ResolvingUndisputedLeague() public {
        uint256 leagueId = _submittedLeague();
        uint32[] memory corrected = _reversedRanking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.DISPUTED,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED
            )
        );
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_RevertWhen_CorrectedRankingTooShort() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = new uint32[](TEAM_COUNT - 1);
        for (uint32 i = 0; i < TEAM_COUNT - 1; i++) {
            corrected[i] = i + 1;
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__RankingLengthMismatch.selector, TEAM_COUNT, TEAM_COUNT - 1
            )
        );
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_RevertWhen_CorrectedRankingHasDuplicate() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();
        corrected[1] = corrected[0]; // team 14 listed twice, team 13 missing

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__DuplicateTeam.selector, TEAM_COUNT));
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_RevertWhen_CorrectedRankingHasUnknownTeam() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();
        corrected[3] = 99;

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 99));
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_RevertWhen_DisputingAfterResolution() public {
        uint256 leagueId = _disputedLeague();
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, _reversedRanking());

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED,
                LeagueTreasury.LeagueState.FINALIZED
            )
        );
        vm.prank(_member(2));
        leagueTreasury.dispute(leagueId);
    }

    /*//////////////////////////////////////////////////////////////
                           getPayout and claim
    //////////////////////////////////////////////////////////////*/

    function test_GetPayout_ZeroBeforeFinalized() public {
        uint256 leagueId = _submittedLeague();
        assertEq(leagueTreasury.getPayout(leagueId, _member(1)), 0);
    }

    function test_GetPayout_ZeroForNonMember() public {
        uint256 leagueId = _finalizedLeague();
        assertEq(leagueTreasury.getPayout(leagueId, alice), 0);
    }

    function test_GetPayout_MatchesPayoutTable() public {
        uint256 leagueId = _finalizedLeague();
        uint256 pot = BUY_IN * TEAM_COUNT;
        uint16[] memory bps = _linearPayout(TEAM_COUNT);

        // places 2..14 get exactly their share of the pot
        for (uint32 place = 2; place <= TEAM_COUNT; place++) {
            assertEq(leagueTreasury.getPayout(leagueId, _member(place)), (pot * bps[place - 1]) / 10000);
        }
    }

    function test_GetPayout_FirstPlaceGetsRoundingRemainder() public {
        // a 10 wei buy-in makes a 140 wei pot, so rounding leaves dust
        uint256 leagueId = _runFullLeague(TEAM_COUNT, 10);
        uint256 pot = 140;
        uint16[] memory bps = _linearPayout(TEAM_COUNT);

        uint256 othersTotal;
        for (uint256 i = 1; i < TEAM_COUNT; i++) {
            othersTotal += (pot * bps[i]) / 10000;
        }
        uint256 first = leagueTreasury.getPayout(leagueId, makeAddr("fm1"));

        assertEq(first, pot - othersTotal);
        assertGt(first, (pot * bps[0]) / 10000); // strictly more than its plain share
    }

    function test_Claim_PaysMemberTheirPayout() public {
        uint256 leagueId = _finalizedLeague();
        uint256 expected = leagueTreasury.getPayout(leagueId, _member(3));

        uint256 received = _claim(_member(3), leagueId);

        assertEq(received, expected);
        assertGt(received, 0);
    }

    function test_Claim_MarksClaimed() public {
        uint256 leagueId = _finalizedLeague();
        _claim(_member(1), leagueId);
        assertTrue(_claimed(leagueId, _member(1)));
        assertFalse(_claimed(leagueId, _member(2)));
    }

    function test_Claim_EmitsEvent() public {
        uint256 leagueId = _finalizedLeague();
        uint256 expected = leagueTreasury.getPayout(leagueId, _member(1));

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.PayoutClaimed(leagueId, _member(1), expected);
        _claim(_member(1), leagueId);
    }

    function test_Claim_EveryonePaidAndContractEmptied() public {
        uint256 leagueId = _finalizedLeague();
        uint256 totalPaid;
        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            totalPaid += _claim(_member(i), leagueId);
        }
        assertEq(totalPaid, BUY_IN * TEAM_COUNT);
        assertEq(address(leagueTreasury).balance, 0);
    }

    function test_Claim_AfterDisputeUsesCorrectedPlaces() public {
        uint256 leagueId = _disputedLeague();
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, _reversedRanking());

        // team 14 now finished 1st, so its owner gets the biggest payout
        uint256 lastToFirst = _claim(_member(TEAM_COUNT), leagueId);
        uint256 firstToLast = _claim(_member(1), leagueId);
        assertGt(lastToFirst, firstToLast);
    }

    function test_Claim_OnlyAffectsOneLeague() public {
        // two leagues' funds sit in one contract; claims must not mix them
        uint256 leagueA = _finalizedLeague();
        _createLeague(); // league B, open, holds no claims yet
        _join(alice, 1, 1);

        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            _claim(_member(i), leagueA);
        }
        assertEq(address(leagueTreasury).balance, BUY_IN); // alice's buy-in in league B is untouched
    }

    function test_RevertWhen_NonMemberClaims() public {
        uint256 leagueId = _finalizedLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, alice));
        vm.prank(alice);
        leagueTreasury.claim(leagueId);
    }

    function test_RevertWhen_ClaimingBeforeFinalized() public {
        uint256 leagueId = _submittedLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.FINALIZED,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED
            )
        );
        vm.prank(_member(1));
        leagueTreasury.claim(leagueId);
    }

    function test_RevertWhen_ClaimingTwice() public {
        uint256 leagueId = _finalizedLeague();
        _claim(_member(1), leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__AlreadyClaimed.selector, leagueId, _member(1))
        );
        vm.prank(_member(1));
        leagueTreasury.claim(leagueId);
    }

    function test_RevertWhen_ClaimingMissingLeague() public {
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__LeagueNotFound.selector, 7));
        vm.prank(alice);
        leagueTreasury.claim(7);
    }

    /*//////////////////////////////////////////////////////////////
                    claim: wallets that misbehave
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_WalletRejectsEth() public {
        RejectingWallet wallet = new RejectingWallet(leagueTreasury);
        uint256 leagueId = _finalizedLeagueWithContractMember(address(wallet), false, 1);
        uint256 payout = leagueTreasury.getPayout(leagueId, address(wallet));

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__TransferFailed.selector, address(wallet), payout)
        );
        wallet.claim(leagueId);

        // the revert undid claimed = true, so the payout is still owed
        assertFalse(_claimed(leagueId, address(wallet)));
    }

    function test_RejectingWalletDoesNotBlockOthers() public {
        RejectingWallet wallet = new RejectingWallet(leagueTreasury);
        uint256 leagueId = _finalizedLeagueWithContractMember(address(wallet), false, 1);

        // every other member can still claim (pull pattern)
        for (uint32 i = 1; i < TEAM_COUNT; i++) {
            assertGt(_claim(_member(i), leagueId), 0);
        }
        // only the rejecting wallet's own payout remains
        assertEq(address(leagueTreasury).balance, leagueTreasury.getPayout(leagueId, address(wallet)));
    }

    function test_ReentrancyCannotDoubleClaim() public {
        ReentrantWallet attacker = new ReentrantWallet(leagueTreasury);
        uint256 leagueId = _finalizedLeagueWithContractMember(address(attacker), true, 1);
        uint256 payout = leagueTreasury.getPayout(leagueId, address(attacker));
        uint256 contractBefore = address(leagueTreasury).balance;

        attacker.claim();

        assertTrue(attacker.reentryAttempted());
        assertFalse(attacker.reentrySucceeded()); // second claim was blocked
        assertEq(attacker.timesPaid(), 1);
        assertEq(address(attacker).balance, payout);
        assertEq(address(leagueTreasury).balance, contractBefore - payout);
    }

    /*//////////////////////////////////////////////////////////////
                               fuzz tests
    //////////////////////////////////////////////////////////////*/

    /// For any buy-in and league size, every member claiming pays out
    /// exactly the pot and leaves the contract empty.
    function testFuzz_PayoutsSumExactlyToPot(uint256 buyIn, uint8 teamCount) public {
        buyIn = bound(buyIn, 1, 1_000 ether);
        teamCount = uint8(bound(teamCount, 2, 20));

        uint256 leagueId = _runFullLeague(teamCount, buyIn);

        uint256 totalPaid;
        for (uint32 i = 1; i <= teamCount; i++) {
            totalPaid += _claim(makeAddr(string.concat("fm", vm.toString(i))), leagueId);
        }
        assertEq(totalPaid, buyIn * teamCount);
        assertEq(address(leagueTreasury).balance, 0);
    }

    /// Payouts never increase as finishing place gets worse.
    function testFuzz_BetterPlaceNeverPaysLess(uint256 buyIn) public {
        buyIn = bound(buyIn, 1, 1_000 ether);
        uint256 leagueId = _runFullLeague(TEAM_COUNT, buyIn);

        for (uint32 place = 1; place < TEAM_COUNT; place++) {
            assertGe(
                leagueTreasury.getPayout(leagueId, makeAddr(string.concat("fm", vm.toString(place)))),
                leagueTreasury.getPayout(leagueId, makeAddr(string.concat("fm", vm.toString(place + 1))))
            );
        }
    }

    /*//////////////////////////////////////////////////////////////
                              cancelLeague
    //////////////////////////////////////////////////////////////*/

    function test_CancelLeague_SetsCancelledAndEmits() public {
        uint256 leagueId = _createLeague();

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCancelled(leagueId);
        vm.prank(commissioner);
        leagueTreasury.cancelLeague(leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.CANCELLED));
    }

    function test_RevertWhen_NonCommissionerCancels() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotCommissioner.selector, alice));
        vm.prank(alice);
        leagueTreasury.cancelLeague(leagueId);
    }

    function test_RevertWhen_CancellingActiveLeague() public {
        uint256 leagueId = _activeLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.OPEN,
                LeagueTreasury.LeagueState.ACTIVE
            )
        );
        vm.prank(commissioner);
        leagueTreasury.cancelLeague(leagueId);
    }

    function test_RevertWhen_JoiningCancelledLeague() public {
        uint256 leagueId = _createLeague();
        vm.prank(commissioner);
        leagueTreasury.cancelLeague(leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__LeagueNotOpen.selector, leagueId, LeagueTreasury.LeagueState.CANCELLED
            )
        );
        _join(alice, leagueId, 1);
    }

    /*//////////////////////////////////////////////////////////////
                              isRefundable
    //////////////////////////////////////////////////////////////*/

    function test_IsRefundable_OpenLeagueOnlyAtJoinDeadline() public {
        uint256 leagueId = _createLeague();
        uint256 joinDeadline = block.timestamp + 1 days;

        vm.warp(joinDeadline - 1);
        assertFalse(leagueTreasury.isRefundable(leagueId));
        vm.warp(joinDeadline);
        assertTrue(leagueTreasury.isRefundable(leagueId));
    }

    function test_IsRefundable_ActiveLeagueOnlyAtStandingsDeadline() public {
        uint256 leagueId = _activeLeague();
        uint256 standingsDeadline = block.timestamp + 2 days;

        vm.warp(standingsDeadline - 1);
        assertFalse(leagueTreasury.isRefundable(leagueId));
        vm.warp(standingsDeadline);
        assertTrue(leagueTreasury.isRefundable(leagueId));
    }

    function test_IsRefundable_DisputedLeagueOnlyAfterResolutionWindow() public {
        uint256 leagueId = _disputedLeague();
        uint256 windowEnd = block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW();

        vm.warp(windowEnd - 1);
        assertFalse(leagueTreasury.isRefundable(leagueId));
        vm.warp(windowEnd);
        assertTrue(leagueTreasury.isRefundable(leagueId));
    }

    function test_IsRefundable_FalseOnceStandingsSubmitted() public {
        uint256 leagueId = _submittedLeague();
        vm.warp(block.timestamp + 365 days); // even long after every deadline
        assertFalse(leagueTreasury.isRefundable(leagueId));
    }

    function test_IsRefundable_FalseWhenFinalized() public {
        uint256 leagueId = _finalizedLeague();
        vm.warp(block.timestamp + 365 days);
        assertFalse(leagueTreasury.isRefundable(leagueId));
    }

    function test_IsRefundable_TrueWhenCancelled() public {
        uint256 leagueId = _createLeague();
        vm.prank(commissioner);
        leagueTreasury.cancelLeague(leagueId);
        assertTrue(leagueTreasury.isRefundable(leagueId));
    }

    /*//////////////////////////////////////////////////////////////
                        withdrawRefund: each exit
    //////////////////////////////////////////////////////////////*/

    function test_Refund_LeagueNeverFills() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        _join(bob, leagueId, 2);
        vm.warp(block.timestamp + 1 days); // join deadline passes, only 2 of 14 joined

        assertEq(_refund(alice, leagueId), BUY_IN);
        assertEq(_refund(bob, leagueId), BUY_IN);
        assertEq(address(leagueTreasury).balance, 0);
    }

    function test_Refund_AfterCommissionerCancels() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        vm.prank(commissioner);
        leagueTreasury.cancelLeague(leagueId);

        assertEq(_refund(alice, leagueId), BUY_IN);
        assertEq(alice.balance, STARTING_BALANCE);
    }

    function test_Refund_ReporterNeverSubmits() public {
        uint256 leagueId = _activeLeague();
        vm.warp(block.timestamp + 2 days); // standings deadline passes

        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            assertEq(_refund(_member(i), leagueId), BUY_IN);
        }
        assertEq(address(leagueTreasury).balance, 0);
    }

    function test_Refund_DisputeNeverResolved() public {
        uint256 leagueId = _disputedLeague();
        vm.warp(block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW());

        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            assertEq(_refund(_member(i), leagueId), BUY_IN);
        }
        assertEq(address(leagueTreasury).balance, 0);
    }

    function test_Refund_FirstRefundCancelsLeague() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCancelled(leagueId);
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.RefundWithdrawn(leagueId, alice, BUY_IN);
        _refund(alice, leagueId);

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.CANCELLED));
    }

    /*//////////////////////////////////////////////////////////////
               withdrawRefund: once an exit opens, others close
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_ResolvingAtResolutionWindowClose() public {
        uint256 leagueId = _disputedLeague();
        uint256 windowEnd = block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW();
        vm.warp(windowEnd);
        uint32[] memory corrected = _reversedRanking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__DisputeResolutionWindowClosed.selector, leagueId, windowEnd
            )
        );
        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, corrected);
    }

    function test_ResolveDispute_OneSecondBeforeWindowCloses() public {
        uint256 leagueId = _disputedLeague();
        vm.warp(block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW() - 1);

        vm.prank(commissioner);
        leagueTreasury.resolveDispute(leagueId, _reversedRanking());

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_RevertWhen_ClaimingAfterRefundsStart() public {
        uint256 leagueId = _disputedLeague();
        vm.warp(block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW());
        _refund(_member(1), leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.FINALIZED,
                LeagueTreasury.LeagueState.CANCELLED
            )
        );
        vm.prank(_member(2));
        leagueTreasury.claim(leagueId);
    }

    function test_RevertWhen_SubmittingAfterRefundsStart() public {
        uint256 leagueId = _activeLeague();
        vm.warp(block.timestamp + 2 days);
        _refund(_member(1), leagueId);
        uint32[] memory ranking = _ranking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.ACTIVE,
                LeagueTreasury.LeagueState.CANCELLED
            )
        );
        _submit(leagueId, ranking);
    }

    /*//////////////////////////////////////////////////////////////
                         withdrawRefund: reverts
    //////////////////////////////////////////////////////////////*/

    function test_RevertWhen_RefundingTwice() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        vm.warp(block.timestamp + 1 days);
        _refund(alice, leagueId);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__AlreadyClaimed.selector, leagueId, alice));
        vm.prank(alice);
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_NonMemberRefunds() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);
        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, bob));
        vm.prank(bob);
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_RefundingBeforeDeadline() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__NotRefundable.selector, leagueId, LeagueTreasury.LeagueState.OPEN
            )
        );
        vm.prank(alice);
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_RefundingFinalizedLeague() public {
        uint256 leagueId = _finalizedLeague();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__NotRefundable.selector, leagueId, LeagueTreasury.LeagueState.FINALIZED
            )
        );
        vm.prank(_member(1));
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_RefundingAfterClaiming() public {
        // a member who claimed a payout can never also take a refund
        uint256 leagueId = _finalizedLeague();
        _claim(_member(1), leagueId);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__AlreadyClaimed.selector, leagueId, _member(1))
        );
        vm.prank(_member(1));
        leagueTreasury.withdrawRefund(leagueId);
    }

    /*//////////////////////////////////////////////////////////////
                           refund fuzz test
    //////////////////////////////////////////////////////////////*/

    /// However many members joined and whatever the buy-in, refunding everyone
    /// returns exactly what they paid and empties the contract.
    function testFuzz_RefundsReturnExactlyWhatWasPaid(uint256 buyIn, uint8 joined) public {
        buyIn = bound(buyIn, 1, 1_000 ether);
        joined = uint8(bound(joined, 1, TEAM_COUNT - 1)); // league never fills

        vm.prank(commissioner);
        uint256 leagueId = leagueTreasury.createLeague(
            reporter,
            buyIn,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(TEAM_COUNT)
        );
        for (uint32 i = 1; i <= joined; i++) {
            address m = makeAddr(string.concat("fm", vm.toString(i)));
            vm.deal(m, buyIn);
            vm.prank(m);
            leagueTreasury.joinLeague{value: buyIn}(leagueId, i);
        }
        vm.warp(block.timestamp + 1 days);

        for (uint32 i = 1; i <= joined; i++) {
            address m = makeAddr(string.concat("fm", vm.toString(i)));
            assertEq(_refund(m, leagueId), buyIn);
            assertEq(m.balance, buyIn);
        }
        assertEq(address(leagueTreasury).balance, 0);
    }
}
