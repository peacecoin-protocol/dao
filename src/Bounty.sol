// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IGovernance, ProposalState} from "./interfaces/IGovernance.sol";

contract Bounty is Initializable, OwnableUpgradeable {
    struct BountyInfo {
        uint256 bountyAmount;
        uint256 withdrawn;
    }

    event UpdatedBountyAmount(uint256 bountyAmount);
    event AddedContributorBounty(
        address indexed user,
        address indexed contributor,
        uint256 amount
    );
    event AddedProposalBounty(
        address indexed user,
        uint256 indexed proposalId,
        uint256 amount
    );
    event ClaimedBounty(address indexed user, uint256 amount);

    uint256 public bountyAmount;
    ERC20Upgradeable public bountyToken;
    address public governance;

    mapping(uint256 => BountyInfo) public proposalBounties;
    mapping(address => BountyInfo) public contributorBounties;
    mapping(address => bool) public isContributor;

    function initialize(
        ERC20Upgradeable _bountyToken,
        uint256 _bountyAmount,
        address _governance
    ) public initializer {
        __Ownable_init();
        bountyAmount = _bountyAmount;
        bountyToken = _bountyToken;
        governance = _governance;
    }

    function setBountyAmount(uint256 _bountyAmount) external onlyOwner {
        bountyAmount = _bountyAmount;
        emit UpdatedBountyAmount(_bountyAmount);
    }

    function setContributor(
        address _contributor,
        bool status
    ) external onlyOwner {
        require(_contributor != address(0), "Invalid contributor");
        isContributor[_contributor] = status;
    }

    function addProposalBounty(uint256 _proposalId, uint256 _amount) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            IGovernance(governance).state(_proposalId) ==
                ProposalState.Executed,
            "Invalid proposal state"
        );

        BountyInfo storage bounty = proposalBounties[_proposalId];
        bounty.bountyAmount += _amount;

        bountyToken.transferFrom(msg.sender, address(this), _amount);

        emit AddedProposalBounty(msg.sender, _proposalId, _amount);
    }

    function addContributorBounty(
        address _contributor,
        uint256 _amount
    ) external {
        require(_contributor != address(0), "Invalid contributor");

        require(_amount > 0, "Amount must be greater than 0");

        BountyInfo storage bounty = contributorBounties[_contributor];
        bounty.bountyAmount += _amount;

        bountyToken.transferFrom(msg.sender, address(this), _amount);

        emit AddedContributorBounty(msg.sender, _contributor, _amount);
    }

    function claimProposalBounty(uint256 _proposalId) external {
        address proposer = IGovernance(governance).proposer(_proposalId);

        require(proposer == msg.sender, "Invalid claimer");

        BountyInfo storage bounty = proposalBounties[_proposalId];
        uint256 claimable = bounty.bountyAmount +
            bountyAmount -
            bounty.withdrawn;

        require(claimable > 0, "Nothing to withdraw");

        bounty.withdrawn += claimable;

        bountyToken.transfer(msg.sender, claimable);

        emit ClaimedBounty(msg.sender, claimable);
    }

    function claimContributorBounty() external {
        BountyInfo storage bounty = contributorBounties[msg.sender];
        uint256 claimable = bounty.bountyAmount +
            bountyAmount -
            bounty.withdrawn;

        require(claimable > 0, "Nothing to withdraw");
        require(isContributor[msg.sender], "Invalid contributor");

        bounty.withdrawn += claimable;

        bountyToken.transfer(msg.sender, claimable);

        emit ClaimedBounty(msg.sender, claimable);
    }

    function recoverERC20(ERC20Upgradeable token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
