// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155HolderUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {PEACECOINDAO_SBT} from "./Governance/PEACECOINDAO_SBT.sol";
import {PEACECOINDAO_NFT} from "./Governance/PEACECOINDAO_NFT.sol";
import {IDAOFactory} from "./interfaces/IDAOFactory.sol";
import {ITokens} from "./interfaces/ITokens.sol";
import {IErrors} from "./interfaces/IErrors.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title Campaigns
 * @dev Contract for managing campaigns with token rewards (ERC20, SBT, NFT)
 * @notice This contract allows creation and management of campaigns with different token types
 * @author Your Name
 */
contract Campaigns is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    ERC1155HolderUpgradeable,
    IErrors
{
    using ECDSA for bytes32;
    using Strings for uint256;

    enum TokenType {
        ERC20,
        SBT,
        NFT
    }

    struct Campaign {
        uint256 sbtId; // SBT token ID associated with the campaign
        string title; // Campaign title
        string description; // Campaign description
        address token; // Address of the reward token (ERC20/SBT/NFT)
        TokenType tokenType; // Type of token used for rewards
        uint256 claimAmount; // Amount claimable per winner
        uint256 totalAmount; // Total amount allocated for the campaign
        uint256 startDate; // Campaign start timestamp (unix)
        uint256 endDate; // Campaign end timestamp (unix)
        bool validateSignatures; // Whether claims require signature validation
        address creator; // Creator of the campaign
    }

    enum Status {
        Pending,
        Active,
        Ended
    }

    uint256 public campaignId;
    address public daoFactory;
    PEACECOINDAO_SBT public sbt;
    PEACECOINDAO_NFT public nft;

    bytes32 public DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    mapping(uint256 => address[]) public campWinners;
    mapping(uint256 => Campaign) public campaigns;
    mapping(uint256 => mapping(address => bool)) public campWinnersClaimed;
    mapping(uint256 => mapping(bytes32 => bool)) public campGistsClaimed;
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
        TokenType tokenType,
        address token,
        address creator
    );

    modifier onlyDAOManager() {
        if (!IAccessControl(daoFactory).hasRole(DAO_MANAGER_ROLE, msg.sender))
            revert PermissionDenied();
        _;
    }

    /**
     * @notice Initialize the Campaigns contract
     * @dev Sets up the SBT and NFT contracts and initializes parent contracts
     * @param _sbt Address of the SBT contract
     * @param _nft Address of the NFT contract
     */
    function initialize(
        address _daoFactory,
        PEACECOINDAO_SBT _sbt,
        PEACECOINDAO_NFT _nft
    ) public initializer {
        if (address(_sbt) == address(0)) revert InvalidAddress();
        if (address(_nft) == address(0)) revert InvalidAddress();

        daoFactory = _daoFactory;
        nft = _nft;
        sbt = _sbt;

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    /**
     * @notice Create a new campaign
     * @dev Only callable by the contract owner
     * @param _campaign Campaign configuration struct
     */
    function createCampaign(Campaign memory _campaign) external onlyDAOManager {
        if (_campaign.tokenType == TokenType.ERC20) {
            require(ITokens(address(_campaign.token)).owner() == msg.sender, PermissionDenied());
        } else if (_campaign.tokenType == TokenType.NFT) {
            require(
                ITokens(address(nft)).creators(_campaign.sbtId) == msg.sender,
                PermissionDenied()
            );
        } else {
            require(
                ITokens(address(sbt)).creators(_campaign.sbtId) == msg.sender,
                PermissionDenied()
            );
        }

        if (_campaign.startDate >= _campaign.endDate) revert IErrors.InvalidStartDate();
        if (_campaign.totalAmount == 0) revert IErrors.InvalidAmount();
        if (_campaign.claimAmount > _campaign.totalAmount) revert IErrors.InvalidClaimAmount();

        // Increment campaign ID (unchecked for gas optimization)
        unchecked {
            campaignId++;
        }
        _campaign.creator = msg.sender;
        campaigns[campaignId] = _campaign;

        if (_campaign.tokenType == TokenType.NFT) {
            nft.mint(address(this), _campaign.sbtId, _campaign.totalAmount);
        } else if (_campaign.tokenType == TokenType.ERC20) {
            ERC20Upgradeable(_campaign.token).transferFrom(
                msg.sender,
                address(this),
                _campaign.totalAmount
            );
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
            _campaign.tokenType,
            _campaign.token,
            msg.sender
        );
    }

    /**
     * @notice Add winners to a campaign
     * @dev Only callable by the contract owner
     * @param _campaignId ID of the campaign
     * @param _addresses Array of winner addresses (for non-signature campaigns)
     * @param _gists Array of gist hashes (for signature campaigns)
     */
    function addCampWinners(
        uint256 _campaignId,
        address[] memory _addresses,
        bytes32[] memory _gists
    ) external {
        if (msg.sender != getCreator(_campaignId)) revert IErrors.PermissionDenied();

        Campaign memory campaign = campaigns[_campaignId];
        if (campaign.validateSignatures) {
            if (_gists.length == 0) revert IErrors.InvalidGistsLength();
            uint256 gistsLength = _gists.length;
            for (uint256 i; i < gistsLength; ) {
                campGists[_campaignId].push(_gists[i]);
                unchecked {
                    ++i;
                }
            }
        } else {
            if (_addresses.length == 0) revert IErrors.InvalidAddressesLength();
            uint256 addressesLength = _addresses.length;
            for (uint256 i; i < addressesLength; ) {
                campWinners[_campaignId].push(_addresses[i]);
                unchecked {
                    ++i;
                }
            }
        }

        emit CampWinnersAdded(_campaignId, _addresses);
    }

    /**
     * @notice Claim campaign rewards
     * @dev Claims rewards for eligible users with reentrancy protection
     * @param _campaignId ID of the campaign
     * @param _gist Gist hash for signature validation
     * @param _message Message for signature verification
     * @param _signature Signature for verification
     */
    function claimCampaign(
        uint256 _campaignId,
        bytes32 _gist,
        string memory _message,
        bytes memory _signature
    ) external nonReentrant {
        Campaign memory campaign = campaigns[_campaignId];

        if (campaign.startDate >= block.timestamp) revert IErrors.CampaignNotStarted();
        if (campaign.endDate <= block.timestamp) revert IErrors.CampaignEnded();
        if (campaign.totalAmount <= totalClaimed[_campaignId] + campaign.claimAmount) {
            revert IErrors.CampaignFullyClaimed();
        }
        if (campWinnersClaimed[_campaignId][msg.sender]) revert IErrors.AlreadyClaimed();

        if (campaign.validateSignatures) {
            if (!verify(msg.sender, _message, _signature)) revert IErrors.InvalidSignature();
            if (campGistsClaimed[_campaignId][_gist]) revert IErrors.AlreadyClaimed();

            // Check if gist is whitelisted
            bool isWhitelisted = false;
            uint256 gistsLength = campGists[_campaignId].length;
            for (uint256 i; i < gistsLength; ) {
                if (campGists[_campaignId][i] == _gist) {
                    isWhitelisted = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (!isWhitelisted) revert IErrors.NotWhitelisted();

            campGistsClaimed[_campaignId][_gist] = true;
            campWinnersClaimed[_campaignId][msg.sender] = true;
        } else {
            if (campWinners[_campaignId].length == 0) revert IErrors.NoWinners();

            // Check if user is a winner
            bool _isWinner = false;
            uint256 winnersLength = campWinners[_campaignId].length;
            for (uint256 i; i < winnersLength; ) {
                if (campWinners[_campaignId][i] == msg.sender) {
                    _isWinner = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (!_isWinner) revert IErrors.NotWhitelisted();
            campWinnersClaimed[_campaignId][msg.sender] = true;
        }

        // Transfer rewards
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
        } else if (campaign.tokenType == TokenType.ERC20) {
            ERC20Upgradeable(campaign.token).transfer(msg.sender, campaign.claimAmount);
        }

        // Update total claimed (unchecked for gas optimization)
        unchecked {
            totalClaimed[_campaignId] += campaign.claimAmount;
        }

        emit CampWinnersClaimed(_campaignId, msg.sender);
    }

    /**
     * @notice Verify a signature
     * @dev Verifies that the signature was created by the signer for the given message
     * @param _signer Address of the expected signer
     * @param _message Message that was signed
     * @param _sig Signature to verify
     * @return True if signature is valid, false otherwise
     */
    function verify(
        address _signer,
        string memory _message,
        bytes memory _sig
    ) public pure returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_message);
        return recoverSigner(ethSignedMessageHash, _sig) == _signer;
    }

    /**
     * @notice Get Ethereum signed message hash
     * @dev Creates the hash that should be signed according to EIP-191
     * @param message Original message
     * @return Hash of the message with Ethereum prefix
     */
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

    /**
     * @notice Recover signer from signature
     * @dev Recovers the address that created the signature
     * @param _ethSignedMessageHash Hash of the message
     * @param _signature Signature to recover from
     * @return Address of the signer
     */
    function recoverSigner(
        bytes32 _ethSignedMessageHash,
        bytes memory _signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    /**
     * @notice Split signature into components
     * @dev Splits a 65-byte signature into r, s, v components
     * @param sig 65-byte signature
     * @return r First 32 bytes of signature
     * @return s Second 32 bytes of signature
     * @return v Final byte of signature
     */
    function splitSignature(
        bytes memory sig
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (sig.length != 65) revert IErrors.InvalidSignatureLength();

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        // EIP-155 support
        if (v < 27) {
            v += 27;
        }

        if (v != 27 && v != 28) revert IErrors.InvalidSignature();
    }

    /**
     * @notice Recover ERC20 tokens from the contract
     * @dev Only callable by the contract owner
     * @param _token Token contract to recover
     */
    function recoverERC20(ERC20Upgradeable _token) external onlyOwner {
        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }

    /**
     * @notice Get the status of a campaign
     * @dev Returns the current status based on timestamps
     * @param _campaignId ID of the campaign
     * @return Current status of the campaign
     */
    function getStatus(uint256 _campaignId) external view returns (Status) {
        Campaign memory campaign = campaigns[_campaignId];
        if (campaign.endDate <= block.timestamp) {
            return Status.Ended;
        } else if (campaign.startDate <= block.timestamp) {
            return Status.Active;
        }
        return Status.Pending;
    }

    /**
     * @notice Check if an address is a winner of a campaign
     * @dev Only works for non-signature campaigns
     * @param _campaignId ID of the campaign
     * @param _winner Address to check
     * @return True if address is a winner, false otherwise
     */
    function isWinner(uint256 _campaignId, address _winner) external view returns (bool) {
        uint256 winnersLength = campWinners[_campaignId].length;
        for (uint256 i; i < winnersLength; ) {
            if (campWinners[_campaignId][i] == _winner) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    /**
     * @notice Get the creator of a campaign
     * @dev Returns the creator of a campaign
     * @param _campaignId ID of the campaign
     * @return Creator of the campaign
     */
    function getCreator(uint256 _campaignId) public view returns (address) {
        return campaigns[_campaignId].creator;
    }

    /**
     * @notice Handle ERC1155 token transfers
     * @dev Required for receiving ERC1155 tokens
     * @return Function selector for ERC1155 receiver
     */
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
