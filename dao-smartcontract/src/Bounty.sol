// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IGovernance, ProposalState} from "./interfaces/IGovernance.sol";
import {IErrors} from "./interfaces/IErrors.sol";

/**
 * @title Bounty
 * @dev Contract for managing bounties and rewards
 * @notice This contract allows users to add and claim bounties for proposals and contributions
 * @author Your Name
 */
contract Bounty is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IErrors {
    // ============ Structs ============
    struct BountyInfo {
        uint256 bountyAmount;
        uint256 withdrawn;
    }

    // ============ Events ============
    event UpdatedBountyAmount(uint256 bountyAmount);
    event AddedContributorBounty(address indexed user, address indexed contributor, uint256 amount);
    event AddedProposalBounty(address indexed user, uint256 indexed proposalId, uint256 amount);
    event ClaimedBounty(address indexed user, uint256 amount);

    uint256 public bountyAmount;
    ERC20Upgradeable public bountyToken;
    address public governance;

    mapping(uint256 => uint256) public proposalBounties;
    mapping(address => uint256) public proposalBountyWithdrawn;
    mapping(address => BountyInfo) public contributorBounties;
    mapping(address => bool) public isContributor;

    /**
     * @notice Initialize the Bounty contract
     * @dev Sets up the bounty token, amount, and governance contract
     * @param token Address of the bounty token contract
     * @param initialBountyAmount Default bounty amount
     * @param governanceAddress Address of the governance contract
     */
    function initialize(
        ERC20Upgradeable token,
        uint256 initialBountyAmount,
        address governanceAddress
    ) public initializer {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();

        if (address(token) == address(0)) revert InvalidAddress();
        if (governanceAddress == address(0)) revert InvalidAddress();

        bountyAmount = initialBountyAmount;
        bountyToken = token;
        governance = governanceAddress;
    }

    function setBountyAmount(uint256 newBountyAmount) external onlyOwner {
        bountyAmount = newBountyAmount;
        emit UpdatedBountyAmount(newBountyAmount);
    }

    /**
     * @notice Set contributor status
     * @dev Only callable by the contract owner
     * @param contributor Address of the contributor
     * @param status Contributor status
     */
    function setContributor(address contributor, bool status) external onlyOwner {
        if (contributor == address(0)) revert InvalidContributor();
        isContributor[contributor] = status;
    }

    /**
     * @notice Add bounty to a proposal
     * @dev Adds bounty tokens to a successful proposal
     * @param proposalId ID of the proposal
     * @param amount Amount of bounty tokens to add
     */
    function addProposalBounty(uint256 proposalId, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();

        ProposalState state = IGovernance(governance).state(proposalId);
        if (state != ProposalState.Executed && state != ProposalState.Succeeded) {
            revert InvalidProposalState();
        }

        // Unchecked addition for gas optimization (safe due to previous checks)
        unchecked {
            proposalBounties[proposalId] += amount;
        }
        bool success = bountyToken.transferFrom(msg.sender, address(this), amount);
        require(success, "ERC20: transferFrom failed");

        emit AddedProposalBounty(msg.sender, proposalId, amount);
    }

    /**
     * @notice Add bounty for a contributor
     * @dev Adds bounty tokens for a specific contributor
     * @param contributor Address of the contributor
     * @param amount Amount of bounty tokens to add
     */
    function addContributorBounty(address contributor, uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (contributor == address(0)) revert InvalidContributor();

        BountyInfo storage bounty = contributorBounties[contributor];
        // Unchecked addition for gas optimization (safe due to previous checks)
        unchecked {
            bounty.bountyAmount += amount;
        }

        bool success = bountyToken.transferFrom(msg.sender, address(this), amount);
        require(success, "ERC20: transferFrom failed");

        emit AddedContributorBounty(msg.sender, contributor, amount);
    }

    /**
     * @notice Claim proposal bounty
     * @dev Claims available proposal bounties for the caller
     */
    function claimProposalBounty() external nonReentrant {
        uint256 claimable = claimableProposalAmount(msg.sender);

        if (claimable == 0) revert NothingToWithdraw();

        // Unchecked addition for gas optimization (safe due to previous checks)
        unchecked {
            proposalBountyWithdrawn[msg.sender] += claimable;
        }
        bool success = bountyToken.transfer(msg.sender, claimable);
        require(success, "ERC20: transfer failed");

        emit ClaimedBounty(msg.sender, claimable);
    }

    /**
     * @notice Claim contributor bounty
     * @dev Claims available contributor bounties for the caller
     */
    function claimContributorBounty() external nonReentrant {
        uint256 claimable = claimableContributorAmount(msg.sender);
        if (claimable == 0) revert NothingToWithdraw();

        BountyInfo storage bounty = contributorBounties[msg.sender];

        unchecked {
            bounty.withdrawn += claimable;
        }
        bool success = bountyToken.transfer(msg.sender, claimable);
        require(success, "ERC20: transfer failed");

        emit ClaimedBounty(msg.sender, claimable);
    }

    /**
     * @notice Get claimable proposal bounty amount for a user
     * @dev Calculates total claimable proposal bounties for a user
     * @param user Address of the user
     * @return Claimable proposal bounty amount
     */
    function claimableProposalAmount(address user) public view returns (uint256) {
        uint256 _totalBounty;
        uint256 proposalCount = IGovernance(governance).proposalCount();

        for (uint256 i = 1; i <= proposalCount; i++) {
            address proposer = IGovernance(governance).proposer(i);

            if (proposer == user) {
                ProposalState state = IGovernance(governance).state(i);
                if (state == ProposalState.Executed || state == ProposalState.Succeeded) {
                    _totalBounty += proposalBounties[i] + bountyAmount;
                }
            }
        }

        uint256 withdrawn = proposalBountyWithdrawn[user];
        if (_totalBounty <= withdrawn) {
            return 0;
        }

        return _totalBounty - withdrawn;
    }

    /**
     * @notice Get claimable contributor bounty amount for a user
     * @dev Calculates total claimable contributor bounties for a user
     * @param user Address of the user
     * @return Claimable contributor bounty amount
     */
    function claimableContributorAmount(address user) public view returns (uint256) {
        uint256 extraAmount = isContributor[user] ? bountyAmount : 0;
        BountyInfo storage bounty = contributorBounties[user];
        uint256 total = bounty.bountyAmount + extraAmount;

        if (total <= bounty.withdrawn) {
            return 0;
        }
        return total - bounty.withdrawn;
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
}
