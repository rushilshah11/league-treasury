// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {LeagueTreasury} from "../src/LeagueTreasury.sol";
import {CreStandingsReceiver, IReceiver} from "../src/CreStandingsReceiver.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

contract CreStandingsReceiverTest is Test {
    LeagueTreasury public treasury;
    CreStandingsReceiver public receiver;
    MockUSDC public usdc;

    address public admin = makeAddr("admin");
    address public forwarder = makeAddr("forwarder");
    address public commissioner = makeAddr("commissioner");
    address public workflowOwner = makeAddr("workflowOwner");

    uint256 constant BUY_IN = 20e6;
    uint8 constant TEAM_COUNT = 14;
    bytes32 constant WORKFLOW_ID = keccak256("standings-workflow");
    bytes10 constant WORKFLOW_NAME = bytes10("standings1");

    function setUp() public {
        usdc = new MockUSDC();
        treasury = new LeagueTreasury(usdc);
        receiver = new CreStandingsReceiver(treasury, forwarder, admin);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _payout() internal pure returns (uint16[] memory payout) {
        // 1st place gets 40%, 2nd 25%, 3rd 15%, 4th 10%, the rest split 10% evenly (10 teams, 100 bps each).
        payout = new uint16[](TEAM_COUNT);
        payout[0] = 4000;
        payout[1] = 2500;
        payout[2] = 1500;
        payout[3] = 1000;
        for (uint256 i = 4; i < TEAM_COUNT; i++) {
            payout[i] = 100;
        }
    }

    /// An ACTIVE league whose reporter is the receiver, not a wallet.
    function _activeLeague() internal returns (uint256 leagueId) {
        usdc.mint(commissioner, 1_000e6);
        vm.startPrank(commissioner);
        usdc.approve(address(treasury), type(uint256).max);
        leagueId = treasury.createLeague(
            "Shah Family League",
            LeagueTreasury.EspnLink(12345678, 2027, LeagueTreasury.Sport.BASKETBALL),
            address(receiver),
            BUY_IN,
            TEAM_COUNT,
            uint64(block.timestamp + 1 days),
            uint64(block.timestamp + 2 days),
            _payout(),
            1
        );
        vm.stopPrank();

        for (uint32 i = 2; i <= TEAM_COUNT; i++) {
            address member = makeAddr(string.concat("member", vm.toString(i)));
            usdc.mint(member, 1_000e6);
            vm.startPrank(member);
            usdc.approve(address(treasury), type(uint256).max);
            treasury.joinLeague(leagueId, i);
            vm.stopPrank();
        }
    }

    /// Team i finishes in place i.
    function _ranking() internal pure returns (uint32[] memory ranking) {
        ranking = new uint32[](TEAM_COUNT);
        for (uint32 i = 0; i < TEAM_COUNT; i++) {
            ranking[i] = i + 1;
        }
    }

    function _report(uint256 leagueId, uint32[] memory ranking) internal pure returns (bytes memory) {
        return abi.encode(leagueId, ranking);
    }

    /// What the production forwarder sends: workflow ID, name, owner, then a 2-byte report ID.
    function _metadata(bytes32 id, address owner_) internal pure returns (bytes memory) {
        return abi.encodePacked(id, WORKFLOW_NAME, owner_, bytes2(0x0001));
    }

    function _state(uint256 leagueId) internal view returns (LeagueTreasury.LeagueState state) {
        (,,,, state,,,,,) = treasury.leagues(leagueId);
    }

    function _placeOf(uint256 leagueId, address who) internal view returns (uint8 place) {
        (,,, place) = treasury.members(leagueId, who);
    }

    /*//////////////////////////////////////////////////////////////
                              HAPPY PATH
    //////////////////////////////////////////////////////////////*/

    function test_forwarderReportPostsStandings() public {
        uint256 leagueId = _activeLeague();

        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));

        assertEq(uint256(_state(leagueId)), uint256(LeagueTreasury.LeagueState.STANDINGS_SUBMITTED));
        assertEq(_placeOf(leagueId, commissioner), 1); // team 1 finished first
        assertEq(_placeOf(leagueId, makeAddr("member14")), 14);
    }

    function test_emitsStandingsForwarded() public {
        uint256 leagueId = _activeLeague();

        vm.expectEmit(true, false, false, false, address(receiver));
        emit CreStandingsReceiver.StandingsForwarded(leagueId);
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));
    }

    /// The challenge window still protects members when the oracle posts the standings.
    function test_memberCanDisputeOracleStandings() public {
        uint256 leagueId = _activeLeague();
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));

        vm.prank(commissioner);
        treasury.dispute(leagueId);

        assertEq(uint256(_state(leagueId)), uint256(LeagueTreasury.LeagueState.DISPUTED));
    }

    /*//////////////////////////////////////////////////////////////
                              WHO CAN CALL
    //////////////////////////////////////////////////////////////*/

    function test_revertsWhenNotForwarder() public {
        uint256 leagueId = _activeLeague();
        address attacker = makeAddr("attacker");

        vm.expectRevert(
            abi.encodeWithSelector(CreStandingsReceiver.CreStandingsReceiver__InvalidSender.selector, attacker, forwarder)
        );
        vm.prank(attacker);
        receiver.onReport("", _report(leagueId, _ranking()));
    }

    /// Even the owner can't post standings directly; only the forwarder can.
    function test_ownerCannotPostDirectly() public {
        uint256 leagueId = _activeLeague();

        vm.expectRevert(
            abi.encodeWithSelector(CreStandingsReceiver.CreStandingsReceiver__InvalidSender.selector, admin, forwarder)
        );
        vm.prank(admin);
        receiver.onReport("", _report(leagueId, _ranking()));
    }

    function test_walletCannotPostToLeagueThatNamesReceiver() public {
        uint256 leagueId = _activeLeague();

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__NotReporter.selector, admin));
        vm.prank(admin);
        treasury.submitStandings(leagueId, _ranking());
    }

    /*//////////////////////////////////////////////////////////////
                          WORKFLOW IDENTITY CHECKS
    //////////////////////////////////////////////////////////////*/

    function test_acceptsExpectedWorkflowOwnerAndId() public {
        uint256 leagueId = _activeLeague();
        vm.startPrank(admin);
        receiver.setExpectedWorkflowOwner(workflowOwner);
        receiver.setExpectedWorkflowId(WORKFLOW_ID);
        vm.stopPrank();

        vm.prank(forwarder);
        receiver.onReport(_metadata(WORKFLOW_ID, workflowOwner), _report(leagueId, _ranking()));

        assertEq(uint256(_state(leagueId)), uint256(LeagueTreasury.LeagueState.STANDINGS_SUBMITTED));
    }

    function test_rejectsOtherWorkflowOwner() public {
        uint256 leagueId = _activeLeague();
        address stranger = makeAddr("stranger");
        vm.prank(admin);
        receiver.setExpectedWorkflowOwner(workflowOwner);

        vm.expectRevert(
            abi.encodeWithSelector(
                CreStandingsReceiver.CreStandingsReceiver__InvalidWorkflowOwner.selector, stranger, workflowOwner
            )
        );
        vm.prank(forwarder);
        receiver.onReport(_metadata(WORKFLOW_ID, stranger), _report(leagueId, _ranking()));
    }

    function test_rejectsOtherWorkflowId() public {
        uint256 leagueId = _activeLeague();
        bytes32 otherId = keccak256("someone-elses-workflow");
        vm.prank(admin);
        receiver.setExpectedWorkflowId(WORKFLOW_ID);

        vm.expectRevert(
            abi.encodeWithSelector(
                CreStandingsReceiver.CreStandingsReceiver__InvalidWorkflowId.selector, otherId, WORKFLOW_ID
            )
        );
        vm.prank(forwarder);
        receiver.onReport(_metadata(otherId, workflowOwner), _report(leagueId, _ranking()));
    }

    function test_rejectsShortMetadataWhenChecksOn() public {
        uint256 leagueId = _activeLeague();
        vm.prank(admin);
        receiver.setExpectedWorkflowOwner(workflowOwner);

        vm.expectRevert(abi.encodeWithSelector(CreStandingsReceiver.CreStandingsReceiver__MetadataTooShort.selector, 0));
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));
    }

    /*//////////////////////////////////////////////////////////////
                         BAD REPORTS AND REPLAYS
    //////////////////////////////////////////////////////////////*/

    function test_wrongLengthRankingReverts() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory shortRanking = new uint32[](TEAM_COUNT - 1);
        for (uint32 i = 0; i < shortRanking.length; i++) {
            shortRanking[i] = i + 1;
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__RankingLengthMismatch.selector, TEAM_COUNT, shortRanking.length
            )
        );
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, shortRanking));
    }

    function test_duplicateTeamReverts() public {
        uint256 leagueId = _activeLeague();
        uint32[] memory ranking = _ranking();
        ranking[1] = 1; // team 1 twice

        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__DuplicateTeam.selector, 1));
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, ranking));
    }

    /// A second report can't overwrite the first: the league has left ACTIVE.
    function test_secondReportReverts() public {
        uint256 leagueId = _activeLeague();
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));

        vm.expectRevert(
            abi.encodeWithSelector(
                LeagueTreasury.LeagueTreasury__InvalidState.selector,
                leagueId,
                LeagueTreasury.LeagueState.ACTIVE,
                LeagueTreasury.LeagueState.STANDINGS_SUBMITTED
            )
        );
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));
    }

    function test_unknownLeagueReverts() public {
        vm.expectRevert(abi.encodeWithSelector(LeagueTreasury.LeagueTreasury__LeagueNotFound.selector, 99));
        vm.prank(forwarder);
        receiver.onReport("", _report(99, _ranking()));
    }

    function test_malformedReportReverts() public {
        vm.expectRevert();
        vm.prank(forwarder);
        receiver.onReport("", hex"1234");
    }

    /*//////////////////////////////////////////////////////////////
                                SETTINGS
    //////////////////////////////////////////////////////////////*/

    function test_onlyOwnerCanChangeSettings() public {
        address attacker = makeAddr("attacker");
        vm.startPrank(attacker);

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        receiver.setForwarder(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        receiver.setExpectedWorkflowOwner(attacker);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, attacker));
        receiver.setExpectedWorkflowId(WORKFLOW_ID);

        vm.stopPrank();
    }

    function test_ownerCanSwitchForwarder() public {
        uint256 leagueId = _activeLeague();
        address productionForwarder = makeAddr("productionForwarder");
        vm.prank(admin);
        receiver.setForwarder(productionForwarder);

        // The old forwarder is shut out; the new one works.
        vm.expectRevert(
            abi.encodeWithSelector(
                CreStandingsReceiver.CreStandingsReceiver__InvalidSender.selector, forwarder, productionForwarder
            )
        );
        vm.prank(forwarder);
        receiver.onReport("", _report(leagueId, _ranking()));

        vm.prank(productionForwarder);
        receiver.onReport("", _report(leagueId, _ranking()));
        assertEq(uint256(_state(leagueId)), uint256(LeagueTreasury.LeagueState.STANDINGS_SUBMITTED));
    }

    function test_constructorRejectsZeroAddresses() public {
        vm.expectRevert(CreStandingsReceiver.CreStandingsReceiver__ZeroAddress.selector);
        new CreStandingsReceiver(treasury, address(0), admin);

        vm.expectRevert(CreStandingsReceiver.CreStandingsReceiver__ZeroAddress.selector);
        new CreStandingsReceiver(LeagueTreasury(address(0)), forwarder, admin);
    }

    function test_setForwarderRejectsZero() public {
        vm.expectRevert(CreStandingsReceiver.CreStandingsReceiver__ZeroAddress.selector);
        vm.prank(admin);
        receiver.setForwarder(address(0));
    }

    function test_supportsInterface() public view {
        assertTrue(receiver.supportsInterface(type(IReceiver).interfaceId));
        assertTrue(receiver.supportsInterface(type(IERC165).interfaceId));
        assertFalse(receiver.supportsInterface(0xdeadbeef));
    }
}
