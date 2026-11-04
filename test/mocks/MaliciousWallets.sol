// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {LeagueTreasury} from "../../src/LeagueTreasury.sol";

/// A member wallet that is a contract with no receive() function,
/// so any ETH sent to it is rejected.
contract RejectingWallet {
    LeagueTreasury public immutable treasury;

    constructor(LeagueTreasury _treasury) {
        treasury = _treasury;
    }

    function join(uint256 leagueId, uint32 teamId) external payable {
        treasury.joinLeague{value: msg.value}(leagueId, teamId);
    }

    function claim(uint256 leagueId) external {
        treasury.claim(leagueId);
    }
}

/// A member wallet that tries to call claim() again while it is being paid
/// (a reentrancy attack). It records whether the re-entry worked.
contract ReentrantWallet {
    LeagueTreasury public immutable treasury;
    uint256 public leagueId;
    uint256 public timesPaid;
    bool public reentryAttempted;
    bool public reentrySucceeded;

    constructor(LeagueTreasury _treasury) {
        treasury = _treasury;
    }

    function join(uint256 _leagueId, uint32 teamId) external payable {
        leagueId = _leagueId;
        treasury.joinLeague{value: msg.value}(_leagueId, teamId);
    }

    function claim() external {
        treasury.claim(leagueId);
    }

    receive() external payable {
        timesPaid++;
        if (!reentryAttempted) {
            reentryAttempted = true;
            // try/catch so a blocked re-entry doesn't make this payment fail
            try treasury.claim(leagueId) {
                reentrySucceeded = true;
            } catch {}
        }
    }
}
