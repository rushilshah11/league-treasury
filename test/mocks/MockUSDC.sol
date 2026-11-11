// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// Test stand-in for USDC: 6 decimals, anyone can mint, and a blocklist like
/// the one Circle uses to freeze addresses.
contract MockUSDC is ERC20 {
    error MockUSDC__Blocked(address account);

    mapping(address => bool) public isBlocked;

    constructor() ERC20("USD Coin", "USDC") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// Freezes or unfreezes an address. Real USDC restricts this to Circle.
    function setBlocked(address account, bool blocked) external {
        isBlocked[account] = blocked;
    }

    /// Every transfer, mint and burn in OpenZeppelin's ERC20 goes through _update,
    /// so checking here blocks a frozen address from sending or receiving.
    function _update(address from, address to, uint256 value) internal override {
        if (isBlocked[from]) revert MockUSDC__Blocked(from);
        if (isBlocked[to]) revert MockUSDC__Blocked(to);
        super._update(from, to, value);
    }
}
