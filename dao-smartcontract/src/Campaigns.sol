// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {
    ERC1155HolderUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import {PeaceCoinDaoSbt} from "./Governance/PEACECOINDAO_SBT.sol";
import {PeaceCoinDaoNft} from "./Governance/PEACECOINDAO_NFT.sol";
import {IDAOFactory} from "./interfaces/IDAOFactory.sol";
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
        bytes32 daoId; // DAO ID associated with the campaign
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

    bytes32 public constant DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

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
        bytes32 indexed daoId,
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

    modifier onlyDaoManager() {
        _onlyDaoManager();
        _;
    }

    function _onlyDaoManager() internal view {
        bytes32 _daoManagerRole = IDAOFactory(daoFactory).daoManagerRole();
        if (!IAccessControl(daoFactory).hasRole(_daoManagerRole, msg.sender))
            revert PermissionDenied();
    }

    /**
     * @notice Initialize the Campaigns contract
     * @dev Initializes parent contracts
     * @param daoFactoryAddress Address of the DAO factory contract
     */
    function initialize(address daoFactoryAddress) public initializer {
        if (daoFactoryAddress == address(0)) revert IErrors.InvalidAddress();
        daoFactory = daoFactoryAddress;

        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
    }

    /**
     * @notice Create a new campaign
     * @dev Only callable by the contract owner
     * @param campaign Campaign configuration struct
     */
    function createCampaign(Campaign memory campaign) external onlyDaoManager {
        (, , , address _nft, , , , address _creator) = IDAOFactory(daoFactory).daoConfigs(
            campaign.daoId
        );
        if (_creator != msg.sender) revert IErrors.InvalidCreator();

        PeaceCoinDaoNft nft = PeaceCoinDaoNft(_nft);

        if (campaign.startDate >= campaign.endDate) revert IErrors.InvalidStartDate();
        if (campaign.totalAmount == 0) revert IErrors.InvalidAmount();
        if (campaign.claimAmount > campaign.totalAmount) revert IErrors.InvalidClaimAmount();

        // Increment campaign ID (unchecked for gas optimization)
        unchecked {
            campaignId++;
        }
        campaign.creator = msg.sender;
        campaigns[campaignId] = campaign;

        if (campaign.tokenType == TokenType.NFT) {
            nft.mint(address(this), campaign.sbtId, campaign.totalAmount);
        } else if (campaign.tokenType == TokenType.ERC20) {
            bool success = ERC20Upgradeable(campaign.token).transferFrom(
                msg.sender,
                address(this),
                campaign.totalAmount
            );
            require(success, "ERC20: transferFrom failed");
        }

        emit CampaignCreated(
            campaignId,
            campaign.daoId,
            campaign.sbtId,
            campaign.title,
            campaign.description,
            campaign.claimAmount,
            campaign.totalAmount,
            campaign.startDate,
            campaign.endDate,
            campaign.validateSignatures,
            campaign.tokenType,
            campaign.token,
            msg.sender
        );
    }

    /**
     * @notice Add winners to a campaign
     * @dev Only callable by the contract owner
     * @param campaignId ID of the campaign
     * @param winners Array of winner addresses (for non-signature campaigns)
     * @param gists Array of gist hashes (for signature campaigns)
     */
    function addCampWinners(
        uint256 campaignId,
        address[] memory winners,
        bytes32[] memory gists
    ) external {
        if (msg.sender != getCreator(campaignId)) revert IErrors.PermissionDenied();

        Campaign memory campaign = campaigns[campaignId];
        if (campaign.validateSignatures) {
            if (gists.length == 0) revert IErrors.InvalidGistsLength();
            uint256 gistsLength = gists.length;
            for (uint256 i; i < gistsLength; ) {
                campGists[campaignId].push(gists[i]);
                unchecked {
                    ++i;
                }
            }
        } else {
            if (winners.length == 0) revert IErrors.InvalidAddressesLength();
            uint256 addressesLength = winners.length;
            for (uint256 i; i < addressesLength; ) {
                campWinners[campaignId].push(winners[i]);
                unchecked {
                    ++i;
                }
            }
        }

        emit CampWinnersAdded(campaignId, winners);
    }

    /**
     * @notice Claim campaign rewards
     * @dev Claims rewards for eligible users with reentrancy protection
     * @param campaignId ID of the campaign
     * @param gist Gist hash for signature validation
     * @param message Message for signature verification
     * @param signature Signature for verification
     */
    function claimCampaign(
        uint256 campaignId,
        bytes32 gist,
        string memory message,
        bytes memory signature
    ) external nonReentrant {
        Campaign memory campaign = campaigns[campaignId];

        (, , address sbtAddress, address nftAddress, , , , ) = IDAOFactory(daoFactory).daoConfigs(
            campaign.daoId
        );

        PeaceCoinDaoNft nft = PeaceCoinDaoNft(nftAddress);
        PeaceCoinDaoSbt sbt = PeaceCoinDaoSbt(sbtAddress);

        if (campaign.startDate > block.timestamp) revert IErrors.CampaignNotStarted();
        if (campaign.endDate <= block.timestamp) revert IErrors.CampaignEnded();
        if (campaign.totalAmount < totalClaimed[campaignId] + campaign.claimAmount) {
            revert IErrors.CampaignFullyClaimed();
        }
        if (campWinnersClaimed[campaignId][msg.sender]) revert IErrors.AlreadyClaimed();

        if (campaign.validateSignatures) {
            if (!verify(msg.sender, message, signature)) revert IErrors.InvalidSignature();
            if (campGistsClaimed[campaignId][gist]) revert IErrors.AlreadyClaimed();

            // Check if gist is whitelisted
            bool isWhitelisted = false;
            uint256 gistsLength = campGists[campaignId].length;

            for (uint256 i; i < gistsLength; ) {
                if (campGists[campaignId][i] == gist) {
                    isWhitelisted = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (!isWhitelisted) revert IErrors.NotWhitelisted();

            campGistsClaimed[campaignId][gist] = true;
            campWinnersClaimed[campaignId][msg.sender] = true;
        } else {
            if (campWinners[campaignId].length == 0) revert IErrors.NoWinners();

            // Check if user is a winner
            bool isWinner = false;
            uint256 winnersLength = campWinners[campaignId].length;
            for (uint256 i; i < winnersLength; ) {
                if (campWinners[campaignId][i] == msg.sender) {
                    isWinner = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }
            if (!isWinner) revert IErrors.NotWhitelisted();
            campWinnersClaimed[campaignId][msg.sender] = true;
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
            bool success = ERC20Upgradeable(campaign.token).transfer(
                msg.sender,
                campaign.claimAmount
            );
            require(success, "ERC20: transfer failed");
        }

        // Update total claimed (unchecked for gas optimization)
        unchecked {
            totalClaimed[campaignId] += campaign.claimAmount;
        }

        emit CampWinnersClaimed(campaignId, msg.sender);
    }

    /**
     * @notice Verify a signature
     * @dev Verifies that the signature was created by the signer for the given message
     * @param signer Address of the expected signer
     * @param message Message that was signed
     * @param signature Signature to verify
     * @return True if signature is valid, false otherwise
     */
    function verify(
        address signer,
        string memory message,
        bytes memory signature
    ) public pure returns (bool) {
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(message);
        return recoverSigner(ethSignedMessageHash, signature) == signer;
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
     * @param ethSignedMessageHash Hash of the message
     * @param signature Signature to recover from
     * @return Address of the signer
     */
    function recoverSigner(
        bytes32 ethSignedMessageHash,
        bytes memory signature
    ) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
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
     * @param token Token contract to recover
     */
    function recoverERC20(ERC20Upgradeable token) external onlyOwner {
        bool success = token.transfer(msg.sender, token.balanceOf(address(this)));
        require(success, "ERC20: transfer failed");
    }

    /**
     * @notice Get the status of a campaign
     * @dev Returns the current status based on timestamps
     * @param campaignId ID of the campaign
     * @return Current status of the campaign
     */
    function getStatus(uint256 campaignId) external view returns (Status) {
        Campaign memory campaign = campaigns[campaignId];
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
     * @param campaignId ID of the campaign
     * @param winner Address to check
     * @return True if address is a winner, false otherwise
     */
    function isWinner(uint256 campaignId, address winner) external view returns (bool) {
        uint256 winnersLength = campWinners[campaignId].length;
        for (uint256 i; i < winnersLength; ) {
            if (campWinners[campaignId][i] == winner) {
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
     * @param campaignId ID of the campaign
     * @return Creator of the campaign
     */
    function getCreator(uint256 campaignId) public view returns (address) {
        return campaigns[campaignId].creator;
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
