// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract LeagueTreasury {
    enum LeagueState {
        OPEN,
        ACTIVE,
        STANDINGS_SUBMITTED,
        DISPUTED,
        FINALIZED,
        CANCELLED
    }

    uint256 public constant TOTAL_BPS = 10000; // 100% in basis points

    // fields ordered to pack into 3 storage slots
    struct League {
        address commissioner;
        uint64 joinDeadline;
        uint8 teamCount;
        uint8 memberCount;
        LeagueState state;
        address reporter;
        uint64 standingsDeadline;
        uint256 buyIn;
    }

    struct Member {
        uint32 teamId;
        bool joined;
        bool claimed;
        uint8 finalPlace;
    }

    uint256 public nextLeagueId;
    mapping(uint256 => League) public leagues;
    mapping(uint256 => uint16[]) public payoutBps;
    mapping(uint256 => mapping(address => Member)) public members;
    mapping(uint256 => mapping(uint32 => address)) public teamOwners;

    event LeagueCreated(
        uint256 indexed leagueId,
        address indexed commissioner,
        address indexed reporter,
        uint8 teamCount,
        uint256 buyIn
    );
    error LeagueTreasury__InvalidTeamCount(uint8 teamCount);
    error LeagueTreasury__PayoutLengthMismatch(
        uint8 teamCount,
        uint256 payoutLength
    );
    error LeagueTreasury__InvalidBuyIn(uint256 buyIn);
    error LeagueTreasury__InvalidReporter(address reporter);
    error LeagueTreasury__InvalidJoinDeadline(uint64 joinDeadline);
    error LeagueTreasury__InvalidStandingsDeadline(
        uint64 standingsDeadline,
        uint64 joinDeadline
    );
    error LeagueTreasury__InvalidPayoutTotal(uint256 total);

    error LeagueTreasury__LeagueNotFound(uint256 leagueId);
    modifier leagueExists(uint256 leagueId) {
        if (leagueId >= nextLeagueId) {
            revert LeagueTreasury__LeagueNotFound(leagueId);
        }
        _;
    }
    function createLeague(
        address reporter,
        uint256 buyIn,
        uint8 teamCount,
        uint64 joinDeadline,
        uint64 standingsDeadline,
        uint16[] calldata payout
    ) external returns (uint256 leagueId) {
        if (teamCount < 2) {
            revert LeagueTreasury__InvalidTeamCount(teamCount);
        }
        if (payout.length != teamCount) {
            revert LeagueTreasury__PayoutLengthMismatch(
                teamCount,
                payout.length
            );
        }
        if (buyIn == 0) {
            revert LeagueTreasury__InvalidBuyIn(buyIn);
        }
        if (reporter == address(0)) {
            revert LeagueTreasury__InvalidReporter(reporter);
        }
        if (joinDeadline <= block.timestamp) {
            revert LeagueTreasury__InvalidJoinDeadline(joinDeadline);
        }
        if (standingsDeadline <= joinDeadline) {
            revert LeagueTreasury__InvalidStandingsDeadline(
                standingsDeadline,
                joinDeadline
            );
        }

        uint256 total = 0;
        for (uint256 i = 0; i < payout.length; i++) {
            total += payout[i];
        }
        if (total != TOTAL_BPS) {
            revert LeagueTreasury__InvalidPayoutTotal(total);
        }

        leagueId = nextLeagueId++;
        leagues[leagueId] = League({
            commissioner: msg.sender,
            joinDeadline: joinDeadline,
            teamCount: teamCount,
            memberCount: 0,
            state: LeagueState.OPEN,
            reporter: reporter,
            standingsDeadline: standingsDeadline,
            buyIn: buyIn
        });
        payoutBps[leagueId] = payout;

        emit LeagueCreated(leagueId, msg.sender, reporter, teamCount, buyIn);
    }

    event MemberJoined(
        uint256 indexed leagueId,
        address indexed member,
        uint32 indexed teamId
    );
    event LeagueActivated(uint256 indexed leagueId);
    error LeagueTreasury__LeagueNotOpen(uint256 leagueId, LeagueState state);
    error LeagueTreasury__JoinDeadlinePassed(
        uint256 leagueId,
        uint64 joinDeadline
    );
    error LeagueTreasury__InvalidTeamId(uint32 teamId);
    error LeagueTreasury__TeamAlreadyTaken(uint256 leagueId, uint32 teamId);
    error LeagueTreasury__IncorrectBuyIn(uint256 sent, uint256 required);
    error LeagueTreasury__MemberAlreadyJoined(uint256 leagueId, address member);

    function joinLeague(
        uint256 leagueId,
        uint32 teamId
    ) external payable leagueExists(leagueId) {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.OPEN) {
            revert LeagueTreasury__LeagueNotOpen(leagueId, league.state);
        }
        if (block.timestamp >= league.joinDeadline) {
            revert LeagueTreasury__JoinDeadlinePassed(
                leagueId,
                league.joinDeadline
            );
        }
        if (teamId == 0) {
            revert LeagueTreasury__InvalidTeamId(teamId);
        }
        if (teamOwners[leagueId][teamId] != address(0)) {
            revert LeagueTreasury__TeamAlreadyTaken(leagueId, teamId);
        }
        if (msg.value != league.buyIn) {
            revert LeagueTreasury__IncorrectBuyIn(msg.value, league.buyIn);
        }
        Member storage member = members[leagueId][msg.sender];
        if (member.joined) {
            revert LeagueTreasury__MemberAlreadyJoined(leagueId, msg.sender);
        }

        member.teamId = teamId;
        member.joined = true;
        teamOwners[leagueId][teamId] = msg.sender;
        league.memberCount++;

        if (league.memberCount == league.teamCount) {
            league.state = LeagueState.ACTIVE;
            emit LeagueActivated(leagueId);
        }

        emit MemberJoined(leagueId, msg.sender, teamId);
    }

    function getPayoutBps(
        uint256 leagueId
    ) external view leagueExists(leagueId) returns (uint16[] memory) {
        return payoutBps[leagueId];
    }
}
