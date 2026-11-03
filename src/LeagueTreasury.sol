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
}