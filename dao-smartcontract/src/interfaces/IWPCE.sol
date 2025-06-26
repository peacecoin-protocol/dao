// SPDX-License-Identifier: MIT

pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWPCE is IERC20 {
    function mint(address account, uint256 amount) external;

    function burn(address from, uint256 amount) external;
}
