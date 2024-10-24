// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {PCEToken} from "lib/v1-core/src/PCEToken.sol";
import {ExchangeAllowMethod} from "lib/v1-core/src/lib/Enum.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract PCETokenV2 is PCEToken, ERC20VotesUpgradeable {
    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20VotesUpgradeable, ERC20Upgradeable) {
        super._update(from, to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override(PCEToken, ERC20Upgradeable) returns (bool) {
        return super.transferFrom(from, to, value);
    }

    function transfer(
        address to,
        uint256 value
    ) public virtual override(PCEToken, ERC20Upgradeable) returns (bool) {
        return super.transfer(to, value);
    }

    function approve(
        address spender,
        uint256 balance
    ) public virtual override(PCEToken, ERC20Upgradeable) returns (bool) {
        return super.approve(spender, balance);
    }
}
