// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract LeagueTreasury {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error LeagueTreasury__InvalidName(uint256 length);
    error LeagueTreasury__InvalidTeamCount(uint8 teamCount);
    error LeagueTreasury__PayoutLengthMismatch(uint8 teamCount, uint256 payoutLength);
    error LeagueTreasury__InvalidBuyIn(uint256 buyIn);
    error LeagueTreasury__InvalidReporter(address reporter);
    error LeagueTreasury__InvalidJoinDeadline(uint64 joinDeadline);
    error LeagueTreasury__InvalidStandingsDeadline(uint64 standingsDeadline, uint64 joinDeadline);
    error LeagueTreasury__InvalidPayoutTotal(uint256 total);
    error LeagueTreasury__LeagueNotFound(uint256 leagueId);
    error LeagueTreasury__LeagueNotOpen(uint256 leagueId, LeagueState state);
    error LeagueTreasury__JoinDeadlinePassed(uint256 leagueId, uint64 joinDeadline);
    error LeagueTreasury__InvalidTeamId(uint32 teamId);
    error LeagueTreasury__TeamAlreadyTaken(uint256 leagueId, uint32 teamId);
    error LeagueTreasury__IncorrectBuyIn(uint256 sent, uint256 required);
    error LeagueTreasury__MemberAlreadyJoined(uint256 leagueId, address member);
    error LeagueTreasury__InvalidState(uint256 leagueId, LeagueState expected, LeagueState actual);
    error LeagueTreasury__NotReporter(address caller);
    error LeagueTreasury__StandingsDeadlinePassed(uint256 leagueId, uint64 deadline);
    error LeagueTreasury__RankingLengthMismatch(uint8 teamCount, uint256 rankingLength);
    error LeagueTreasury__DuplicateTeam(uint32 teamId);
    error LeagueTreasury__NotCommissioner(address caller);
    error LeagueTreasury__NotMember(uint256 leagueId, address caller);
    error LeagueTreasury__ChallengeWindowClosed(uint256 leagueId, uint256 closedAt);
    error LeagueTreasury__ChallengeWindowOpen(uint256 leagueId, uint256 closesAt);
    error LeagueTreasury__AlreadyClaimed(uint256 leagueId, address member);
    error LeagueTreasury__TransferFailed(address recipient, uint256 amount);
    error LeagueTreasury__NotRefundable(uint256 leagueId, LeagueState state);
    error LeagueTreasury__DisputeResolutionWindowClosed(uint256 leagueId, uint256 closedAt);

    /*//////////////////////////////////////////////////////////////
                           TYPE DECLARATIONS
    //////////////////////////////////////////////////////////////*/

    enum LeagueState {
        OPEN,
        ACTIVE,
        STANDINGS_SUBMITTED,
        DISPUTED,
        FINALIZED,
        CANCELLED
    }

    // fields ordered to pack into 4 storage slots
    struct League {
        address commissioner;
        uint64 joinDeadline;
        uint8 teamCount;
        uint8 memberCount;
        LeagueState state;
        address reporter;
        uint64 standingsDeadline;
        uint256 buyIn;
        uint64 standingsSubmittedAt;
        uint64 disputedAt;
    }

    struct Member {
        uint32 teamId;
        bool joined;
        bool claimed;
        uint8 finalPlace;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 public constant TOTAL_BPS = 10000; // 100% in basis points
    uint256 public constant CHALLENGE_WINDOW = 48 hours;
    uint256 public constant DISPUTE_RESOLUTION_WINDOW = 7 days;
    uint256 public constant MAX_NAME_LENGTH = 64; // bytes

    uint256 public nextLeagueId;
    mapping(uint256 => League) public leagues;
    mapping(uint256 => uint16[]) public payoutBps;
    mapping(uint256 => mapping(address => Member)) public members;
    mapping(uint256 => mapping(uint32 => address)) public teamOwners;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /// @dev `name` and `espnLeagueId` are only emitted, never stored: the frontend
    /// reads them from this event, which costs far less gas than storage.
    event LeagueCreated(
        uint256 indexed leagueId,
        address indexed commissioner,
        address indexed reporter,
        uint8 teamCount,
        uint256 buyIn,
        string name,
        uint64 espnLeagueId
    );
    event MemberJoined(uint256 indexed leagueId, address indexed member, uint32 indexed teamId);
    event LeagueActivated(uint256 indexed leagueId);
    event StandingsSubmitted(uint256 indexed leagueId, uint64 submittedAt);
    event StandingsDisputed(uint256 indexed leagueId, address indexed member);
    event StandingsFinalized(uint256 indexed leagueId);
    event DisputeResolved(uint256 indexed leagueId);
    event PayoutClaimed(uint256 indexed leagueId, address indexed member, uint256 amount);
    event LeagueCancelled(uint256 indexed leagueId);
    event RefundWithdrawn(uint256 indexed leagueId, address indexed member, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier leagueExists(uint256 leagueId) {
        if (leagueId >= nextLeagueId) {
            revert LeagueTreasury__LeagueNotFound(leagueId);
        }
        _;
    }

    modifier onlyReporter(uint256 leagueId) {
        if (msg.sender != leagues[leagueId].reporter) {
            revert LeagueTreasury__NotReporter(msg.sender);
        }
        _;
    }

    modifier onlyCommissioner(uint256 leagueId) {
        if (msg.sender != leagues[leagueId].commissioner) {
            revert LeagueTreasury__NotCommissioner(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function createLeague(
        string calldata name,
        uint64 espnLeagueId,
        address reporter,
        uint256 buyIn,
        uint8 teamCount,
        uint64 joinDeadline,
        uint64 standingsDeadline,
        uint16[] calldata payout
    ) external returns (uint256 leagueId) {
        // Validation, storage and the event live in internal helpers. Doing it all
        // inline needs more variables than the EVM's stack allows ("stack too deep").
        _validateLeague(name, reporter, buyIn, teamCount, joinDeadline, standingsDeadline, payout);
        leagueId = _storeLeague(reporter, buyIn, teamCount, joinDeadline, standingsDeadline, payout);
        _emitLeagueCreated(leagueId, name, espnLeagueId);
    }

    function _emitLeagueCreated(uint256 leagueId, string calldata name, uint64 espnLeagueId) internal {
        League storage league = leagues[leagueId];
        emit LeagueCreated(
            leagueId, league.commissioner, league.reporter, league.teamCount, league.buyIn, name, espnLeagueId
        );
    }

    function _validateLeague(
        string calldata name,
        address reporter,
        uint256 buyIn,
        uint8 teamCount,
        uint64 joinDeadline,
        uint64 standingsDeadline,
        uint16[] calldata payout
    ) internal view {
        if (bytes(name).length == 0 || bytes(name).length > MAX_NAME_LENGTH) {
            revert LeagueTreasury__InvalidName(bytes(name).length);
        }
        if (teamCount < 2) {
            revert LeagueTreasury__InvalidTeamCount(teamCount);
        }
        if (payout.length != teamCount) {
            revert LeagueTreasury__PayoutLengthMismatch(teamCount, payout.length);
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
            revert LeagueTreasury__InvalidStandingsDeadline(standingsDeadline, joinDeadline);
        }

        uint256 total = 0;
        for (uint256 i = 0; i < payout.length; i++) {
            total += payout[i];
        }
        if (total != TOTAL_BPS) {
            revert LeagueTreasury__InvalidPayoutTotal(total);
        }
    }

    function _storeLeague(
        address reporter,
        uint256 buyIn,
        uint8 teamCount,
        uint64 joinDeadline,
        uint64 standingsDeadline,
        uint16[] calldata payout
    ) internal returns (uint256 leagueId) {
        leagueId = nextLeagueId++;
        leagues[leagueId] = League({
            commissioner: msg.sender,
            joinDeadline: joinDeadline,
            teamCount: teamCount,
            memberCount: 0,
            state: LeagueState.OPEN,
            reporter: reporter,
            standingsDeadline: standingsDeadline,
            buyIn: buyIn,
            standingsSubmittedAt: 0,
            disputedAt: 0
        });
        payoutBps[leagueId] = payout;
    }

    function joinLeague(uint256 leagueId, uint32 teamId) external payable leagueExists(leagueId) {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.OPEN) {
            revert LeagueTreasury__LeagueNotOpen(leagueId, league.state);
        }
        if (block.timestamp >= league.joinDeadline) {
            revert LeagueTreasury__JoinDeadlinePassed(leagueId, league.joinDeadline);
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

    function _recordStandings(uint256 leagueId, uint32[] calldata rankedTeamIds) internal {
        League storage league = leagues[leagueId];

        if (rankedTeamIds.length != league.teamCount) {
            revert LeagueTreasury__RankingLengthMismatch(league.teamCount, rankedTeamIds.length);
        }
        // reset to 0 before setting finalPlace to avoid duplicate team errors on re-submission
        for (uint32 i = 0; i < rankedTeamIds.length; i++) {
            address owner = teamOwners[leagueId][rankedTeamIds[i]];
            members[leagueId][owner].finalPlace = 0;
        }

        for (uint32 i = 0; i < rankedTeamIds.length; i++) {
            uint32 teamId = rankedTeamIds[i];
            address owner = teamOwners[leagueId][teamId];
            if (teamId == 0 || owner == address(0)) {
                revert LeagueTreasury__InvalidTeamId(teamId);
            }

            Member storage member = members[leagueId][owner];
            if (member.finalPlace != 0) {
                revert LeagueTreasury__DuplicateTeam(teamId);
            }
            // casting to 'uint8' is safe because i < teamCount, which is a uint8
            // forge-lint: disable-next-line(unsafe-typecast)
            member.finalPlace = uint8(i + 1);
        }
    }

    function submitStandings(uint256 leagueId, uint32[] calldata rankedTeamIds)
        external
        leagueExists(leagueId)
        onlyReporter(leagueId)
    {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.ACTIVE) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.ACTIVE, league.state);
        }

        if (block.timestamp >= league.standingsDeadline) {
            revert LeagueTreasury__StandingsDeadlinePassed(leagueId, league.standingsDeadline);
        }

        _recordStandings(leagueId, rankedTeamIds);

        // casting to 'uint64' is safe because timestamps fit until year ~584 billion
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 submittedAt = uint64(block.timestamp);
        league.state = LeagueState.STANDINGS_SUBMITTED;
        league.standingsSubmittedAt = submittedAt;

        emit StandingsSubmitted(leagueId, submittedAt);
    }

    function dispute(uint256 leagueId) external leagueExists(leagueId) {
        Member storage member = members[leagueId][msg.sender];
        if (!member.joined) {
            revert LeagueTreasury__NotMember(leagueId, msg.sender);
        }

        League storage league = leagues[leagueId];
        if (league.state != LeagueState.STANDINGS_SUBMITTED) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.STANDINGS_SUBMITTED, league.state);
        }

        uint256 windowEnd = league.standingsSubmittedAt + CHALLENGE_WINDOW;
        if (block.timestamp >= windowEnd) {
            revert LeagueTreasury__ChallengeWindowClosed(leagueId, windowEnd);
        }

        league.state = LeagueState.DISPUTED;
        // casting to 'uint64' is safe because timestamps fit until year ~584 billion
        // forge-lint: disable-next-line(unsafe-typecast)
        league.disputedAt = uint64(block.timestamp);
        emit StandingsDisputed(leagueId, msg.sender);
    }

    function finalize(uint256 leagueId) external leagueExists(leagueId) {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.STANDINGS_SUBMITTED) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.STANDINGS_SUBMITTED, league.state);
        }

        uint256 windowEnd = league.standingsSubmittedAt + CHALLENGE_WINDOW;
        if (block.timestamp < windowEnd) {
            revert LeagueTreasury__ChallengeWindowOpen(leagueId, windowEnd);
        }

        league.state = LeagueState.FINALIZED;
        emit StandingsFinalized(leagueId);
    }

    function resolveDispute(uint256 leagueId, uint32[] calldata correctedRanking)
        external
        leagueExists(leagueId)
        onlyCommissioner(leagueId)
    {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.DISPUTED) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.DISPUTED, league.state);
        }

        uint256 windowEnd = league.disputedAt + DISPUTE_RESOLUTION_WINDOW;
        if (block.timestamp >= windowEnd) {
            revert LeagueTreasury__DisputeResolutionWindowClosed(leagueId, windowEnd);
        }

        _recordStandings(leagueId, correctedRanking);
        league.state = LeagueState.FINALIZED;
        emit DisputeResolved(leagueId);
    }

    function claim(uint256 leagueId) external leagueExists(leagueId) {
        League storage league = leagues[leagueId];
        Member storage member = members[leagueId][msg.sender];

        if (!member.joined) {
            revert LeagueTreasury__NotMember(leagueId, msg.sender);
        }
        if (league.state != LeagueState.FINALIZED) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.FINALIZED, league.state);
        }
        if (member.claimed) {
            revert LeagueTreasury__AlreadyClaimed(leagueId, msg.sender);
        }

        uint256 payout = getPayout(leagueId, msg.sender);
        member.claimed = true;
        emit PayoutClaimed(leagueId, msg.sender, payout);

        if (payout > 0) {
            (bool success,) = payable(msg.sender).call{value: payout}("");
            if (!success) {
                revert LeagueTreasury__TransferFailed(msg.sender, payout);
            }
        }
    }

    function cancelLeague(uint256 leagueId) external leagueExists(leagueId) onlyCommissioner(leagueId) {
        League storage league = leagues[leagueId];
        if (league.state != LeagueState.OPEN) {
            revert LeagueTreasury__InvalidState(leagueId, LeagueState.OPEN, league.state);
        }

        league.state = LeagueState.CANCELLED;
        emit LeagueCancelled(leagueId);
    }

    function withdrawRefund(uint256 leagueId) external leagueExists(leagueId) {
        League storage league = leagues[leagueId];
        Member storage member = members[leagueId][msg.sender];

        if (!member.joined) {
            revert LeagueTreasury__NotMember(leagueId, msg.sender);
        }
        if (member.claimed) {
            revert LeagueTreasury__AlreadyClaimed(leagueId, msg.sender);
        }
        if (!isRefundable(leagueId)) {
            revert LeagueTreasury__NotRefundable(leagueId, league.state);
        }

        if (league.state != LeagueState.CANCELLED) {
            league.state = LeagueState.CANCELLED;
            emit LeagueCancelled(leagueId);
        }
        member.claimed = true;

        uint256 amount = league.buyIn;
        emit RefundWithdrawn(leagueId, msg.sender, amount);

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) {
            revert LeagueTreasury__TransferFailed(msg.sender, amount);
        }
    }

    /*//////////////////////////////////////////////////////////////
                             VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPayoutBps(uint256 leagueId) external view leagueExists(leagueId) returns (uint16[] memory) {
        return payoutBps[leagueId];
    }

    function getPayout(uint256 leagueId, address member) public view returns (uint256) {
        League storage league = leagues[leagueId];
        Member storage m = members[leagueId][member];

        if (!m.joined || league.state != LeagueState.FINALIZED) {
            return 0;
        }

        uint256 pot = league.buyIn * league.memberCount;
        uint16[] storage bps = payoutBps[leagueId];

        if (m.finalPlace > 1) {
            return (pot * bps[m.finalPlace - 1]) / TOTAL_BPS;
        }

        if (m.finalPlace == 1) {
            uint256 othersTotal = 0;
            for (uint256 i = 1; i < bps.length; i++) {
                othersTotal += (pot * bps[i]) / TOTAL_BPS;
            }
            return pot - othersTotal;
        }
        return 0;
    }

    function isRefundable(uint256 leagueId) public view leagueExists(leagueId) returns (bool) {
        League storage league = leagues[leagueId];
        LeagueState state = league.state;

        if (state == LeagueState.CANCELLED) {
            return true;
        }
        if (state == LeagueState.OPEN) {
            return block.timestamp >= league.joinDeadline;
        }
        if (state == LeagueState.ACTIVE) {
            return block.timestamp >= league.standingsDeadline;
        }
        if (state == LeagueState.DISPUTED) {
            return block.timestamp >= league.disputedAt + DISPUTE_RESOLUTION_WINDOW;
        }
        return false;
    }
}
