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
    string constant LEAGUE_NAME = "Shah Family League";
    uint64 constant ESPN_LEAGUE_ID = 12345678;
    uint16 constant ESPN_SEASON = 2027;
    uint256 constant STARTING_BALANCE = 1 ether;
    // The commissioner takes this team when creating a league.
    uint32 constant COMMISSIONER_TEAM = 1;

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _espn() internal pure returns (LeagueTreasury.EspnLink memory) {
        return LeagueTreasury.EspnLink(ESPN_LEAGUE_ID, ESPN_SEASON, LeagueTreasury.Sport.BASKETBALL);
    }

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
        leagueId = leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function _join(address who, uint256 leagueId, uint32 teamId) internal {
        vm.prank(who);
        leagueTreasury.joinLeague{value: BUY_IN}(leagueId, teamId);
    }

    /// Fills every open slot with generated members (teams 2..TEAM_COUNT; the commissioner has team 1).
    function _fillLeague(uint256 leagueId) internal {
        for (uint32 i = 2; i <= TEAM_COUNT; i++) {
            address member = _member(i);
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

    /// Owner of `teamId` in leagues made by _createLeague. Team 1 is the commissioner.
    function _member(uint32 teamId) internal returns (address) {
        if (teamId == COMMISSIONER_TEAM) return commissioner;
        return makeAddr(string.concat("member", vm.toString(teamId)));
    }

    /// Owner of `teamId` in leagues made by _runFullLeague. Team 1 is the commissioner.
    function _fm(uint32 teamId) internal returns (address) {
        if (teamId == COMMISSIONER_TEAM) return commissioner;
        return makeAddr(string.concat("fm", vm.toString(teamId)));
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
        vm.deal(commissioner, buyIn);
        vm.prank(commissioner);
        leagueId = leagueTreasury.createLeague{value: buyIn}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            buyIn,
            teamCount,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(teamCount),
            COMMISSIONER_TEAM
        );
        uint32[] memory ranking = new uint32[](teamCount);
        ranking[0] = COMMISSIONER_TEAM;
        for (uint32 i = 2; i <= teamCount; i++) {
            address m = _fm(i);
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
        for (uint32 i = 2; i < TEAM_COUNT; i++) {
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
        vm.deal(commissioner, 10_000 ether);
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
        assertEq(memberCount, 1); // the commissioner
        assertEq(uint8(state), uint8(LeagueTreasury.LeagueState.OPEN));
        assertEq(r, reporter);
        assertEq(standingsDeadline, uint64(block.timestamp + 2 days));
        assertEq(buyIn, BUY_IN);
        assertEq(standingsSubmittedAt, 0);
    }

    function test_CreateLeague_EmitsEvent() public {
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCreated(
            0,
            commissioner,
            reporter,
            TEAM_COUNT,
            BUY_IN,
            LEAGUE_NAME,
            ESPN_LEAGUE_ID,
            ESPN_SEASON,
            LeagueTreasury.Sport.BASKETBALL
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

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamCount.selector, 1));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            1,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
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
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_BuyInIsZero() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidBuyIn.selector, 0));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            0,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_ReporterIsZeroAddress() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidReporter.selector, address(0)));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            address(0),
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_JoinDeadlineNotInFuture() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 joinDeadline = uint64(block.timestamp); // exactly "now" is not allowed

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidJoinDeadline.selector, joinDeadline)
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            joinDeadline,
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
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
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            joinDeadline,
            standingsDeadline,
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_StandingsDeadlineEqualsJoinDeadline() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        uint64 deadline = uint64(block.timestamp + 1 days);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidStandingsDeadline.selector, deadline, deadline)
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME, _espn(), reporter, BUY_IN, TEAM_COUNT, deadline, deadline, payout, COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_PayoutTotalWrong() public {
        uint16[] memory payout = new uint16[](TEAM_COUNT);
        for (uint8 i = 0; i < TEAM_COUNT; i++) {
            payout[i] = 1; // sums to 14, not 10000
        }

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector, TEAM_COUNT));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_PayoutTotalOffByOne() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT); // sums to 10000
        payout[TEAM_COUNT - 1] -= 1; // now sums to 9999

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidPayoutTotal.selector, 9999));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    /*//////////////////////////////////////////////////////////////
              createLeague: commissioner plays, reporter doesn't
    //////////////////////////////////////////////////////////////*/

    function test_CreateLeague_CommissionerJoinsAsFirstTeam() public {
        uint256 leagueId = _createLeague();

        (uint32 teamId, bool joined,,) = leagueTreasury.members(leagueId, commissioner);
        assertEq(teamId, COMMISSIONER_TEAM);
        assertTrue(joined);
        assertEq(leagueTreasury.teamOwners(leagueId, COMMISSIONER_TEAM), commissioner);
        assertEq(address(leagueTreasury).balance, BUY_IN);
    }

    function test_CreateLeague_EmitsMemberJoinedForCommissioner() public {
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.MemberJoined(0, commissioner, COMMISSIONER_TEAM);
        _createLeague();
    }

    function test_CreateLeague_CommissionerCanPickAnyTeamId() public {
        vm.prank(commissioner);
        uint256 leagueId = leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(TEAM_COUNT),
            7
        );
        assertEq(leagueTreasury.teamOwners(leagueId, 7), commissioner);
    }

    function test_RevertWhen_CreatingWithoutBuyIn() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector, 0, BUY_IN));
        vm.prank(commissioner);
        leagueTreasury.createLeague(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_CommissionerTeamIdIsZero() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 0));
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            0
        );
    }

    function test_RevertWhen_CommissionerIsReporter() public {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ReporterCannotPlay.selector, commissioner)
        );
        vm.prank(commissioner);
        leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            _espn(),
            commissioner,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_RevertWhen_ReporterJoins() public {
        uint256 leagueId = _createLeague();
        vm.deal(reporter, STARTING_BALANCE);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ReporterCannotPlay.selector, reporter));
        _join(reporter, leagueId, 2);
    }

    /*//////////////////////////////////////////////////////////////
                           joinLeague: happy path
    //////////////////////////////////////////////////////////////*/

    function test_JoinLeague_StoresMember() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

        (uint32 teamId, bool joined, bool claimed, uint8 finalPlace) = leagueTreasury.members(leagueId, alice);

        assertEq(teamId, 2);
        assertTrue(joined);
        assertFalse(claimed);
        assertEq(finalPlace, 0);
    }

    function test_JoinLeague_RecordsTeamOwner() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

        assertEq(leagueTreasury.teamOwners(leagueId, 2), alice);
    }

    function test_JoinLeague_TakesBuyIn() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

        assertEq(address(leagueTreasury).balance, 2 * BUY_IN); // commissioner + alice
        assertEq(alice.balance, STARTING_BALANCE - BUY_IN);
    }

    function test_JoinLeague_IncrementsMemberCount() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);
        _join(bob, leagueId, 3);

        assertEq(_memberCount(leagueId), 3);
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
        emit LeagueTreasury.MemberJoined(leagueId, alice, 2);
        _join(alice, leagueId, 2);
    }

    function test_JoinLeague_EmitsLeagueActivatedOnLastJoin() public {
        uint256 leagueId = _createLeague();

        // fill every slot except the last one
        for (uint32 i = 2; i < TEAM_COUNT; i++) {
            address member = _member(i);
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
        _join(alice, leagueId, 2);
    }

    function test_RevertWhen_TeamIdIsZero() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 0));
        _join(alice, leagueId, 0);
    }

    function test_RevertWhen_TeamAlreadyTaken() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__TeamAlreadyTaken.selector, leagueId, 2));
        _join(bob, leagueId, 2);
    }

    function test_RevertWhen_BuyInTooLow() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector, BUY_IN - 1, BUY_IN)
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN - 1}(leagueId, 2);
    }

    function test_RevertWhen_BuyInTooHigh() public {
        uint256 leagueId = _createLeague();

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__IncorrectBuyIn.selector, BUY_IN + 1, BUY_IN)
        );
        vm.prank(alice);
        leagueTreasury.joinLeague{value: BUY_IN + 1}(leagueId, 2);
    }

    function test_RevertWhen_MemberJoinsTwice() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__MemberAlreadyJoined.selector, leagueId, alice)
        );
        _join(alice, leagueId, 3);
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
        _join(alice, leagueId, 2);
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
                    dispute resolution: majority vote
    //////////////////////////////////////////////////////////////*/

    /// Votes needed to pass a proposal in a full league: more than half.
    uint256 constant MAJORITY = TEAM_COUNT / 2 + 1; // 8 of 14

    function _propose(address who, uint256 leagueId, uint32[] memory ranking) internal returns (uint256 proposalId) {
        vm.prank(who);
        proposalId = leagueTreasury.proposeStandings(leagueId, ranking);
    }

    function _approve(address who, uint256 leagueId, uint256 proposalId) internal {
        vm.prank(who);
        leagueTreasury.approveProposal(leagueId, proposalId);
    }

    /// Member of team 2 proposes `ranking`; teams 3.. approve until it passes.
    function _voteThrough(uint256 leagueId, uint32[] memory ranking) internal returns (uint256 proposalId) {
        proposalId = _propose(_member(2), leagueId, ranking);
        for (uint32 team = 3; team <= MAJORITY + 1; team++) {
            _approve(_member(team), leagueId, proposalId);
        }
    }

    function _approvals(uint256 leagueId, uint256 proposalId) internal view returns (uint8 approvals) {
        (, approvals) = leagueTreasury.proposals(leagueId, proposalId);
    }

    function test_ProposeStandings_StoresProposalAndCountsProposerVote() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());

        (address proposer, uint8 approvals, uint32[] memory ranking) = leagueTreasury.getProposal(leagueId, proposalId);
        assertEq(proposalId, 0);
        assertEq(leagueTreasury.proposalCount(leagueId), 1);
        assertEq(proposer, _member(2));
        assertEq(approvals, 1);
        assertTrue(leagueTreasury.hasApproved(leagueId, proposalId, _member(2)));
        assertEq(ranking.length, TEAM_COUNT);
        assertEq(ranking[0], TEAM_COUNT);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.DISPUTED));
    }

    function test_ProposeStandings_EmitsEvents() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory ranking = _reversedRanking();

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.StandingsProposed(leagueId, 0, _member(2), ranking);
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.ProposalApproved(leagueId, 0, _member(2), 1);
        _propose(_member(2), leagueId, ranking);
    }

    function test_ProposeStandings_DoesNotChangePlacesUntilPassed() public {
        uint256 leagueId = _disputedLeague();
        _propose(_member(2), leagueId, _reversedRanking());

        // the reporter's original standings stay in place while the vote runs
        assertEq(_finalPlace(leagueId, _member(1)), 1);
    }

    function test_Vote_MajorityFinalizesWithProposedPlaces() public {
        uint256 leagueId = _disputedLeague();
        _voteThrough(leagueId, _reversedRanking());

        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
        for (uint32 teamId = 1; teamId <= TEAM_COUNT; teamId++) {
            // team 14 is now 1st, team 1 is now 14th
            assertEq(_finalPlace(leagueId, _member(teamId)), TEAM_COUNT - teamId + 1);
        }
    }

    function test_Vote_ExactlyHalfIsNotEnough() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());
        for (uint32 team = 3; team <= TEAM_COUNT / 2 + 1; team++) {
            _approve(_member(team), leagueId, proposalId);
        }

        assertEq(_approvals(leagueId, proposalId), TEAM_COUNT / 2); // 7 of 14
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.DISPUTED));

        _approve(_member(TEAM_COUNT), leagueId, proposalId); // 8th vote
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_Vote_EmitsDisputeResolvedOnFinalVote() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());
        for (uint32 team = 3; team <= MAJORITY; team++) {
            _approve(_member(team), leagueId, proposalId);
        }

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.ProposalApproved(leagueId, proposalId, _member(uint32(MAJORITY + 1)), uint8(MAJORITY));
        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.DisputeResolved(leagueId, proposalId);
        _approve(_member(uint32(MAJORITY + 1)), leagueId, proposalId);
    }

    function test_Vote_CanConfirmOriginalStandings() public {
        uint256 leagueId = _disputedLeague();
        _voteThrough(leagueId, _ranking());

        assertEq(_finalPlace(leagueId, _member(1)), 1);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_Vote_CommissionerHasOnlyOneVote() public {
        // the commissioner proposes standings that crown themselves (team 1 is already 1st,
        // so put them first in a reversed order) and can't push it through alone
        uint256 leagueId = _disputedLeague();
        uint32[] memory selfServing = _reversedRanking();
        selfServing[TEAM_COUNT - 1] = selfServing[0]; // swap team 14 and team 1
        selfServing[0] = COMMISSIONER_TEAM;
        uint256 proposalId = _propose(commissioner, leagueId, selfServing);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__AlreadyApproved.selector, leagueId, proposalId, commissioner
            )
        );
        _approve(commissioner, leagueId, proposalId);
        assertEq(_approvals(leagueId, proposalId), 1);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.DISPUTED));
    }

    function test_Vote_FirstProposalToReachMajorityWins() public {
        uint256 leagueId = _disputedLeague();
        uint256 reversed = _propose(_member(2), leagueId, _reversedRanking());
        uint256 original = _propose(_member(3), leagueId, _ranking());
        assertEq(original, 1);

        // members can back both; the original standings get there first
        _approve(_member(2), leagueId, original);
        for (uint32 team = 4; team <= MAJORITY + 1; team++) {
            _approve(_member(team), leagueId, original);
        }
        assertEq(_finalPlace(leagueId, _member(1)), 1);

        // the losing proposal can no longer be approved
        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.DISPUTED,
                LeagueTreasury.LeagueState.FINALIZED
            )
        );
        _approve(_member(TEAM_COUNT), leagueId, reversed);
    }

    function test_Vote_OneSecondBeforeWindowCloses() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());
        for (uint32 team = 3; team <= MAJORITY; team++) {
            _approve(_member(team), leagueId, proposalId);
        }
        vm.warp(block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW() - 1);

        _approve(_member(uint32(MAJORITY + 1)), leagueId, proposalId);
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
    }

    function test_Claim_AfterDisputeUsesCorrectedPlaces() public {
        uint256 leagueId = _disputedLeague();
        _voteThrough(leagueId, _reversedRanking());

        // team 14 now finished 1st, so its owner gets the biggest payout
        uint256 lastToFirst = _claim(_member(TEAM_COUNT), leagueId);
        uint256 firstToLast = _claim(_member(1), leagueId);
        assertGt(lastToFirst, firstToLast);
    }

    function test_RevertWhen_NonMemberProposes() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory ranking = _reversedRanking();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, alice));
        _propose(alice, leagueId, ranking);
    }

    function test_RevertWhen_ReporterVotes() public {
        // the reporter posted the disputed standings, so it gets no say in fixing them
        uint256 leagueId = _disputedLeague();
        uint32[] memory ranking = _reversedRanking();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, reporter));
        _propose(reporter, leagueId, ranking);
    }

    function test_RevertWhen_NonMemberApproves() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, alice));
        _approve(alice, leagueId, proposalId);
    }

    function test_RevertWhen_ProposingWhenNotDisputed() public {
        uint256 leagueId = _submittedLeague();
        uint32[] memory ranking = _reversedRanking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.DISPUTED,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED
            )
        );
        _propose(_member(2), leagueId, ranking);
    }

    function test_RevertWhen_ApprovingMissingProposal() public {
        uint256 leagueId = _disputedLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ProposalNotFound.selector, leagueId, 0));
        _approve(_member(2), leagueId, 0);
    }

    function test_RevertWhen_ApprovingTwice() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());
        _approve(_member(3), leagueId, proposalId);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__AlreadyApproved.selector, leagueId, proposalId, _member(3)
            )
        );
        _approve(_member(3), leagueId, proposalId);
    }

    function test_RevertWhen_ProposedRankingTooShort() public {
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
        _propose(_member(2), leagueId, corrected);
    }

    function test_RevertWhen_ProposedRankingHasDuplicate() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();
        corrected[1] = corrected[0]; // team 14 listed twice, team 13 missing

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__DuplicateTeam.selector, TEAM_COUNT));
        _propose(_member(2), leagueId, corrected);
    }

    function test_RevertWhen_ProposedRankingHasUnknownTeam() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();
        corrected[3] = 99;

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 99));
        _propose(_member(2), leagueId, corrected);
    }

    function test_RevertWhen_ProposedRankingHasTeamZero() public {
        uint256 leagueId = _disputedLeague();
        uint32[] memory corrected = _reversedRanking();
        corrected[0] = 0;

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidTeamId.selector, 0));
        _propose(_member(2), leagueId, corrected);
    }

    function test_RevertWhen_ProposingAtResolutionWindowClose() public {
        uint256 leagueId = _disputedLeague();
        uint256 windowEnd = block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW();
        vm.warp(windowEnd);
        uint32[] memory corrected = _reversedRanking();

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__DisputeResolutionWindowClosed.selector, leagueId, windowEnd
            )
        );
        _propose(_member(2), leagueId, corrected);
    }

    function test_RevertWhen_ApprovingAtResolutionWindowClose() public {
        uint256 leagueId = _disputedLeague();
        uint256 proposalId = _propose(_member(2), leagueId, _reversedRanking());
        uint256 windowEnd = block.timestamp + leagueTreasury.DISPUTE_RESOLUTION_WINDOW();
        vm.warp(windowEnd);

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__DisputeResolutionWindowClosed.selector, leagueId, windowEnd
            )
        );
        _approve(_member(3), leagueId, proposalId);
    }

    function test_RevertWhen_GettingMissingProposal() public {
        uint256 leagueId = _disputedLeague();
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__ProposalNotFound.selector, leagueId, 0));
        leagueTreasury.getProposal(leagueId, 0);
    }

    function test_RevertWhen_DisputingAfterResolution() public {
        uint256 leagueId = _disputedLeague();
        _voteThrough(leagueId, _reversedRanking());

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

    /// Whichever members back a proposal, it passes exactly when more than half
    /// of the league has approved it, and never before.
    function testFuzz_ProposalPassesExactlyAtMajority(uint256 seed) public {
        uint256 leagueId = _disputedLeague();
        // shuffle the voting order so the result doesn't depend on who votes first
        uint32[] memory order = _ranking();
        for (uint256 i = order.length - 1; i > 0; i--) {
            uint256 j = uint256(keccak256(abi.encode(seed, i))) % (i + 1);
            (order[i], order[j]) = (order[j], order[i]);
        }

        uint256 proposalId = _propose(_member(order[0]), leagueId, _reversedRanking());
        for (uint256 k = 1; k < order.length; k++) {
            bool passed = _state(leagueId) == LeagueTreasury.LeagueState.FINALIZED;
            assertEq(passed, k >= MAJORITY);
            if (passed) break;
            _approve(_member(order[k]), leagueId, proposalId);
        }
        assertEq(uint8(_state(leagueId)), uint8(LeagueTreasury.LeagueState.FINALIZED));
        assertEq(_approvals(leagueId, proposalId), MAJORITY);
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
        uint256 first = leagueTreasury.getPayout(leagueId, _fm(1));

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

    function test_Claim_OnlyAffectsOneLeague() public {
        // two leagues' funds sit in one contract; claims must not mix them
        uint256 leagueA = _finalizedLeague();
        _createLeague(); // league B, open, holds no claims yet
        _join(alice, 1, 2);

        for (uint32 i = 1; i <= TEAM_COUNT; i++) {
            _claim(_member(i), leagueA);
        }
        // the commissioner's and alice's buy-ins in league B are untouched
        assertEq(address(leagueTreasury).balance, 2 * BUY_IN);
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
            totalPaid += _claim(_fm(i), leagueId);
        }
        assertEq(totalPaid, buyIn * teamCount);
        assertEq(address(leagueTreasury).balance, 0);
    }

    /// Payouts never increase as finishing place gets worse.
    function testFuzz_BetterPlaceNeverPaysLess(uint256 buyIn) public {
        buyIn = bound(buyIn, 1, 1_000 ether);
        uint256 leagueId = _runFullLeague(TEAM_COUNT, buyIn);

        for (uint32 place = 1; place < TEAM_COUNT; place++) {
            assertGe(leagueTreasury.getPayout(leagueId, _fm(place)), leagueTreasury.getPayout(leagueId, _fm(place + 1)));
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
        _join(alice, leagueId, 2);
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
        _join(alice, leagueId, 2);
        _join(bob, leagueId, 3);
        vm.warp(block.timestamp + 1 days); // join deadline passes, only 3 of 14 joined

        assertEq(_refund(commissioner, leagueId), BUY_IN);
        assertEq(_refund(alice, leagueId), BUY_IN);
        assertEq(_refund(bob, leagueId), BUY_IN);
        assertEq(address(leagueTreasury).balance, 0);
    }

    function test_Refund_AfterCommissionerCancels() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);
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
        _join(alice, leagueId, 2);
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
        _join(alice, leagueId, 2);
        vm.warp(block.timestamp + 1 days);
        _refund(alice, leagueId);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__AlreadyClaimed.selector, leagueId, alice));
        vm.prank(alice);
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_NonMemberRefunds() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);
        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotMember.selector, leagueId, bob));
        vm.prank(bob);
        leagueTreasury.withdrawRefund(leagueId);
    }

    function test_RevertWhen_RefundingBeforeDeadline() public {
        uint256 leagueId = _createLeague();
        _join(alice, leagueId, 2);

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
        joined = uint8(bound(joined, 1, TEAM_COUNT - 1)); // league never fills (commissioner included)

        vm.deal(commissioner, buyIn);
        vm.prank(commissioner);
        uint256 leagueId = leagueTreasury.createLeague{value: buyIn}(
            LEAGUE_NAME,
            _espn(),
            reporter,
            buyIn,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(TEAM_COUNT),
            COMMISSIONER_TEAM
        );
        for (uint32 i = 2; i <= joined; i++) {
            address m = _fm(i);
            vm.deal(m, buyIn);
            vm.prank(m);
            leagueTreasury.joinLeague{value: buyIn}(leagueId, i);
        }
        vm.warp(block.timestamp + 1 days);

        for (uint32 i = 1; i <= joined; i++) {
            address m = _fm(i);
            assertEq(_refund(m, leagueId), buyIn);
            assertEq(m.balance, buyIn);
        }
        assertEq(address(leagueTreasury).balance, 0);
    }

    /*//////////////////////////////////////////////////////////////
                         createLeague: league name
    //////////////////////////////////////////////////////////////*/

    function _createLeagueNamed(string memory name) internal returns (uint256) {
        uint16[] memory payout = _linearPayout(TEAM_COUNT);
        vm.prank(commissioner);
        return leagueTreasury.createLeague{value: BUY_IN}(
            name,
            _espn(),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            payout,
            COMMISSIONER_TEAM
        );
    }

    function test_CreateLeague_AcceptsMaxLengthName() public {
        string memory name = "0123456789012345678901234567890123456789012345678901234567890123"; // 64 bytes
        assertEq(bytes(name).length, leagueTreasury.MAX_NAME_LENGTH());
        _createLeagueNamed(name);
        assertEq(leagueTreasury.nextLeagueId(), 1);
    }

    function test_RevertWhen_NameIsEmpty() public {
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidName.selector, 0));
        this.createLeagueNamedExternal("");
    }

    function test_RevertWhen_NameTooLong() public {
        string memory name = "01234567890123456789012345678901234567890123456789012345678901234"; // 65 bytes
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidName.selector, 65));
        this.createLeagueNamedExternal(name);
    }

    /// External wrapper so expectRevert applies to the whole createLeague call.
    function createLeagueNamedExternal(string memory name) external returns (uint256) {
        return _createLeagueNamed(name);
    }

    /*//////////////////////////////////////////////////////////////
                       createLeague: ESPN league link
    //////////////////////////////////////////////////////////////*/

    function _createLeagueWithEspn(LeagueTreasury.EspnLink memory espn) external returns (uint256) {
        vm.prank(commissioner);
        return leagueTreasury.createLeague{value: BUY_IN}(
            LEAGUE_NAME,
            espn,
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(TEAM_COUNT),
            COMMISSIONER_TEAM
        );
    }

    function test_CreateLeague_EmitsSportAndSeason() public {
        LeagueTreasury.EspnLink memory football = LeagueTreasury.EspnLink(999, 2026, LeagueTreasury.Sport.FOOTBALL);

        vm.expectEmit(true, true, true, true);
        emit LeagueTreasury.LeagueCreated(
            0, commissioner, reporter, TEAM_COUNT, BUY_IN, LEAGUE_NAME, 999, 2026, LeagueTreasury.Sport.FOOTBALL
        );
        this._createLeagueWithEspn(football);
    }

    function test_RevertWhen_EspnLeagueIdIsZero() public {
        LeagueTreasury.EspnLink memory espn = LeagueTreasury.EspnLink(0, ESPN_SEASON, LeagueTreasury.Sport.BASKETBALL);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidEspnLeague.selector, 0, ESPN_SEASON)
        );
        this._createLeagueWithEspn(espn);
    }

    function test_RevertWhen_EspnSeasonIsZero() public {
        LeagueTreasury.EspnLink memory espn =
            LeagueTreasury.EspnLink(ESPN_LEAGUE_ID, 0, LeagueTreasury.Sport.BASKETBALL);

        vm.expectRevert(
            abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__InvalidEspnLeague.selector, ESPN_LEAGUE_ID, 0)
        );
        this._createLeagueWithEspn(espn);
    }

    function test_RevertWhen_SportIsOutOfRange() public {
        // Sport has 4 values; raw calldata with sport = 4 must be rejected by ABI decoding.
        bytes memory data = abi.encodeWithSelector(
            LeagueTreasury.createLeague.selector,
            LEAGUE_NAME,
            ESPN_LEAGUE_ID,
            ESPN_SEASON,
            uint8(4),
            reporter,
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _linearPayout(TEAM_COUNT),
            COMMISSIONER_TEAM
        );
        vm.prank(commissioner);
        (bool ok,) = address(leagueTreasury).call{value: BUY_IN}(data);
        assertFalse(ok);
    }
}
