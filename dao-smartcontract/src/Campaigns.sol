// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {PEACECOINDAO_SBT} from "./Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "./Governance/PEACECOINDAO_NFT.sol";

contract Campaigns is Initializable, OwnableUpgradeable, ERC1155HolderUpgradeable {
    using ECDSA for bytes32;
    using Strings for uint256;

    enum TokenType {
        PCE,
        SBT,
        NFT
    }

    struct Campaign {
        uint256 sbtId;
        string title;
        string description;
        uint256 claimAmount;
        uint256 totalAmount;
        uint256 startDate;
        uint256 endDate;
        bool validateSignatures;
        TokenType tokenType;
    }

    enum Status {
        Pending,
        Active,
        Ended
    }

    uint256 public campaignId;
    ERC20Upgradeable public token;
    PEACECOINDAO_SBT public sbt;
    PEACECOINDAO_NFT public nft;

    mapping(uint256 => address[]) public campWinners;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => bool)) public champWinnersClaimed;
    mapping(uint256 => mapping(bytes32 => bool)) public champGistsClaimed;
    mapping(uint256 => bytes32[]) public campGists;
    mapping(uint256 => uint256) public totalClaimed;

    event CampWinnersAdded(uint256 indexed campaignId, address[] winners);
    event CampWinnersClaimed(uint256 indexed campaignId, address indexed winner);
    event CampaignCreated(
        uint256 indexed campaignId,
        uint256 indexed sbtId,
        string title,
        string description,
        uint256 claimAmount,
        uint256 totalAmount,
        uint256 startDate,
        uint256 endDate,
        bool validateSignatures,
        TokenType tokenType
    );

    function initialize(
        ERC20Upgradeable _token,
        PEACECOINDAO_SBT _sbt,
        PEACECOINDAO_NFT _nft
    ) public initializer {
        token = _token;
        nft = _nft;
        sbt = _sbt;
        __Ownable_init(msg.sender);
    }

    function createCampaign(Campaign memory _campaign) external {
        //Should onlyOwner modifier
        require(_campaign.startDate < _campaign.endDate, "Start date must be before end date");
        require(_campaign.totalAmount > 0, "Amount must be greater than 0");
        require(
            _campaign.claimAmount <= _campaign.totalAmount,
            "Claim amount must be less than total amount"
        );

        campaignId++;
        campaigns[campaignId] = _campaign;

        if (_campaign.tokenType == TokenType.NFT) {
            nft.mint(address(this), _campaign.sbtId, _campaign.totalAmount);
        } else if (_campaign.tokenType == TokenType.PCE) {
            token.transfer(address(this), _campaign.totalAmount);
        }

        emit CampaignCreated(
            campaignId,
            _campaign.sbtId,
            _campaign.title,
            _campaign.description,
            _campaign.claimAmount,
            _campaign.totalAmount,
            _campaign.startDate,
            _campaign.endDate,
            _campaign.validateSignatures,
            _campaign.tokenType
        );
    }

    function addCampWinners(
        uint256 _campaignId,
        address[] memory _addresses,
        bytes32[] memory _gists
    ) external {
        //Should onlyOwner modifier
        require(_campaignId > 0, "Campaign id must be greater than 0");

        Campaign memory campaign = campaigns[_campaignId];
        if (campaign.validateSignatures) {
            require(_gists.length > 0, "Gists length must be greater than 0");
            for (uint256 i = 0; i < _gists.length; i++) {
                campGists[_campaignId].push(_gists[i]);
            }
        } else {
            require(_addresses.length > 0, "Addresses length must be greater than 0");
            for (uint256 i = 0; i < _addresses.length; i++) {
                campWinners[_campaignId].push(_addresses[i]);
            }
        }

        emit CampWinnersAdded(_campaignId, _addresses);
    }

    function claimCampaign(
        uint256 _campaignId,
        bytes32 _gist,
        string memory _message,
        bytes memory _signature
    ) external {
        Campaign memory campaign = campaigns[_campaignId];
        require(campaign.startDate < block.timestamp, "Campaign is not started");
        require(campaign.endDate > block.timestamp, "Campaign is ended");

        require(
            !champWinnersClaimed[_campaignId][msg.sender],
            "You have already claimed your prize"
        );

        if (campaign.validateSignatures) {
            require(verify(msg.sender, _message, _signature), "Invalid signature");
            require(!champGistsClaimed[_campaignId][_gist], "You have already claimed your prize");

            bool isWhitelisted = false;
            for (uint256 i = 0; i < campGists[_campaignId].length; i++) {
                if (campGists[_campaignId][i] == _gist) {
                    isWhitelisted = true;
                    break;
                }
            }
            require(isWhitelisted, "You are not whitelisted");
            champGistsClaimed[_campaignId][_gist] = true;
            champWinnersClaimed[_campaignId][msg.sender] = true;
        } else {
            require(campWinners[_campaignId].length > 0, "Campaign has no winners");

            bool _isWinner = false;
            for (uint256 i = 0; i < campWinners[_campaignId].length; i++) {
                if (campWinners[_campaignId][i] == msg.sender) {
                    _isWinner = true;
                    break;
                }
            }
            require(_isWinner, "You are not a winner");
            champWinnersClaimed[_campaignId][msg.sender] = true;
        }

        if (campaign.tokenType == TokenType.NFT) {
            nft.safeTransferFrom(
                address(this),
                msg.sender,
                campaign.sbtId,
                campaign.claimAmount,
                ""
            );
        } else if (campaign.tokenType == TokenType.SBT) {
            sbt.mint(msg.sender, campaign.sbtId, campaign.claimAmount);
        } else if (campaign.tokenType == TokenType.PCE) {
            token.transfer(msg.sender, campaign.claimAmount);
        }

        totalClaimed[_campaignId] += campaign.claimAmount;

        emit CampWinnersClaimed(_campaignId, msg.sender);
    }

    function verify(
        address _signer,
        string memory _message,
        bytes memory _sig
    ) public pure returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_message);
        return recoverSigner(ethSignedMessageHash, _sig) == _signer;
    }

    function getEthSignedMessageHash(string memory message) internal pure returns (bytes32) {
        bytes memory messageBytes = bytes(message);
        uint256 messageLength = messageBytes.length;

        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n",
                    messageLength.toString(),
                    message
                )
            );
    }
    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);

        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            // second 32 bytes
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // EIP-155 support
        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "invalid v value");
    }

    function recoverERC20(ERC20Upgradeable _token) external onlyOwner {
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

    function getStatus(uint256 _campaignId) external view returns (Status) {
        if (campaigns[_campaignId].endDate < block.timestamp) {
            return Status.Ended;
        } else if (campaigns[_campaignId].startDate < block.timestamp) {
            return Status.Pending;
        }
        return Status.Active;
    }

    function isWinner(uint256 _campaignId, address _winner) external view returns (bool) {
        for (uint256 i = 0; i < campWinners[_campaignId].length; i++) {
            if (campWinners[_campaignId][i] == _winner) {
                return true;
            }
        }
        return false;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }
}
