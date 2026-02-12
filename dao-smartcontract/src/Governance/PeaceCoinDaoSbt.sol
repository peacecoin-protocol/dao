// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {PeaceCoinDaoNft} from "./PeaceCoinDaoNft.sol";

contract PeaceCoinDaoSbt is PeaceCoinDaoNft {
    /**
     * @dev Override to prevent transfers - SBTs are non-transferable
     * @notice This function always reverts as SBTs cannot be transferred
     */
    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert NonTransferable();
    }

    /**
     * @dev Override to prevent batch transfers - SBTs are non-transferable
     * @notice This function always reverts as SBTs cannot be transferred
     */
    function safeBatchTransferFrom(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public pure override {
        revert NonTransferable();
    }
}
