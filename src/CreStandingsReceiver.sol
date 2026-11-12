// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {LeagueTreasury} from "./LeagueTreasury.sol";

/// What Chainlink's forwarder calls to hand a signed report to a contract.
interface IReceiver is IERC165 {
    function onReport(bytes calldata metadata, bytes calldata report) external;
}

/// Lets Chainlink CRE post a league's final standings in place of the standings bot.
///
/// A league names one reporter address when it is created. Name this contract as
/// the reporter and the treasury needs no changes: this contract forwards the
/// standings it receives to `LeagueTreasury.submitStandings`, which is the only
/// thing a reporter can do. The 48-hour dispute window and member vote still apply
/// to whatever it posts.
///
/// Who can make it post standings:
///  - Only the Chainlink forwarder can call `onReport`. The forwarder checks that a
///    majority of the oracle network signed the report.
///  - The forwarder delivers reports from ANY workflow aimed at this address, so the
///    forwarder check alone is not enough. Once deployed, set the expected workflow
///    owner and/or workflow ID so only our workflow's reports are accepted.
///  - In `cre workflow simulate` the mock forwarder sends no workflow details, so
///    leave both expected values unset while simulating.
contract CreStandingsReceiver is IReceiver, Ownable {
    error CreStandingsReceiver__ZeroAddress();
    error CreStandingsReceiver__InvalidSender(address sender, address expected);
    error CreStandingsReceiver__MetadataTooShort(uint256 length);
    error CreStandingsReceiver__InvalidWorkflowOwner(address got, address expected);
    error CreStandingsReceiver__InvalidWorkflowId(bytes32 got, bytes32 expected);

    // The forwarder's metadata starts with: workflow ID (32 bytes), workflow name
    // (10 bytes), workflow owner (20 bytes). Production adds a 2-byte report ID after
    // these, so only the first 62 bytes are read and a longer value is fine.
    uint256 private constant METADATA_MIN_LENGTH = 62;

    LeagueTreasury public immutable treasury;

    /// The Chainlink forwarder allowed to call `onReport`. The owner can change it,
    /// because simulation and production use different forwarders.
    address public forwarder;
    /// If set, reports must come from a workflow owned by this address.
    address public expectedWorkflowOwner;
    /// If set, reports must come from this exact workflow.
    bytes32 public expectedWorkflowId;

    event ForwarderSet(address indexed forwarder);
    event ExpectedWorkflowOwnerSet(address indexed workflowOwner);
    event ExpectedWorkflowIdSet(bytes32 indexed workflowId);
    event StandingsForwarded(uint256 indexed leagueId);

    constructor(LeagueTreasury leagueTreasury, address initialForwarder, address initialOwner) Ownable(initialOwner) {
        if (address(leagueTreasury) == address(0) || initialForwarder == address(0)) {
            revert CreStandingsReceiver__ZeroAddress();
        }
        treasury = leagueTreasury;
        forwarder = initialForwarder;
        emit ForwarderSet(initialForwarder);
    }

    /*//////////////////////////////////////////////////////////////
                               THE REPORT
    //////////////////////////////////////////////////////////////*/

    /// The report is `abi.encode(uint256 leagueId, uint32[] rankedTeamIds)`:
    /// the league and its ESPN team IDs from first place to last.
    function onReport(bytes calldata metadata, bytes calldata report) external override {
        if (msg.sender != forwarder) {
            revert CreStandingsReceiver__InvalidSender(msg.sender, forwarder);
        }
        _checkWorkflow(metadata);

        (uint256 leagueId, uint32[] memory rankedTeamIds) = abi.decode(report, (uint256, uint32[]));
        // Emit before the call. If the treasury rejects the standings, the whole transaction
        // reverts and the event goes with it, so nothing is logged for a failed report.
        emit StandingsForwarded(leagueId);
        treasury.submitStandings(leagueId, rankedTeamIds);
    }

    function _checkWorkflow(bytes calldata metadata) internal view {
        address ownerWanted = expectedWorkflowOwner;
        bytes32 idWanted = expectedWorkflowId;
        if (ownerWanted == address(0) && idWanted == bytes32(0)) return;

        if (metadata.length < METADATA_MIN_LENGTH) {
            revert CreStandingsReceiver__MetadataTooShort(metadata.length);
        }
        if (idWanted != bytes32(0)) {
            bytes32 id = bytes32(metadata[0:32]);
            if (id != idWanted) revert CreStandingsReceiver__InvalidWorkflowId(id, idWanted);
        }
        if (ownerWanted != address(0)) {
            address workflowOwner = address(bytes20(metadata[42:62]));
            if (workflowOwner != ownerWanted) {
                revert CreStandingsReceiver__InvalidWorkflowOwner(workflowOwner, ownerWanted);
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 SETTINGS
    //////////////////////////////////////////////////////////////*/

    function setForwarder(address newForwarder) external onlyOwner {
        if (newForwarder == address(0)) revert CreStandingsReceiver__ZeroAddress();
        forwarder = newForwarder;
        emit ForwarderSet(newForwarder);
    }

    /// Pass address(0) to turn the check off (simulation only).
    // Zero is meant here: it is how the check is switched off. Slither flags the missing zero-check.
    // slither-disable-next-line missing-zero-check
    function setExpectedWorkflowOwner(address workflowOwner) external onlyOwner {
        expectedWorkflowOwner = workflowOwner;
        emit ExpectedWorkflowOwnerSet(workflowOwner);
    }

    /// Pass bytes32(0) to turn the check off (simulation only).
    function setExpectedWorkflowId(bytes32 workflowId) external onlyOwner {
        expectedWorkflowId = workflowId;
        emit ExpectedWorkflowIdSet(workflowId);
    }

    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IReceiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
