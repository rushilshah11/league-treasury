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

    function createLeague(
        address reporter,
        uint256 buyIn,
        uint8 teamCount,
        uint64 joinDeadline,
        uint64 standingsDeadline,
        uint16[] calldata payout
    ) external returns (uint256 leagueId) {
        require(teamCount >= 2, "teamCount must be > 2");
        require(
            payout.length == teamCount,
            "payout length must match teamCount"
        );
        require(buyIn > 0, "buyIn must be > 0");
        require(reporter != address(0), "reporter cannot be zero address");

        require(
            block.timestamp < joinDeadline,
            "joinDeadline must be in the future"
        );
        require(
            standingsDeadline > joinDeadline,
            "standingsDeadline must be after joinDeadline"
        );
        uint256 total = 0;
        for (uint256 i = 0; i < payout.length; i++) {
            total += payout[i];
        }
        require(total == 10000, "payout bps must sum to 10000");

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

        emit LeagueCreated(
            leagueId,
            msg.sender,
            reporter,
            teamCount,
            buyIn
        );
    }
}
