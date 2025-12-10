// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IErrors} from "../interfaces/IErrors.sol";

contract PEACECOINDAO_NFT is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, IErrors {
    using Checkpoints for Checkpoints.Trace224;
    using EnumerableSet for EnumerableSet.UintSet;

    bytes32 public constant DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    // Packed storage for gas optimization
    string public uri_;
    string public name;
    string public symbol;
    address public daoFactory;
    uint256 public numberOfTokens;

    mapping(uint256 => string) public tokenURIs;
    mapping(address => bool) public minters;
    mapping(uint256 => bool) public isRevoked;
    mapping(uint256 => address) public creators;
    mapping(uint256 => bytes32) public daoIds;

    function initialize(
        string memory _name,
        string memory _symbol,
        string memory _uri,
        address _daoFactory
    ) external initializer {
        require(bytes(_name).length > 0, InvalidName());
        require(bytes(_symbol).length > 0, InvalidSymbol());

        name = _name;
        symbol = _symbol;
        uri_ = _uri;
        daoFactory = _daoFactory;

        __ERC1155_init(_uri);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Voting weight per token ID
    mapping(uint256 => uint256) public votingPowerPerId;

    // Balances per user
    mapping(address => mapping(uint256 => uint256)) private _balances;

    // Delegation and voting history
    mapping(address => address) private _delegates;
    mapping(address => Checkpoints.Trace224) private _checkpoints;

    event Revoked(uint256 indexed tokenId, bool isRevoked);
    event CreatedToken(
        uint256 indexed tokenId,
        bytes32 indexed daoId,
        string tokenURI,
        uint256 votingPower,
        address creator
    );
    event Delegated(address indexed delegator, address indexed delegatee, uint256 votes);
    event VotesMoved(address indexed from, address indexed to, uint256 amount);
    event SetTokenURI(uint256 indexed tokenId, string uri, uint256 weight);

    modifier onlyDefaultAdmin() {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert PermissionDenied();
        _;
    }

    modifier onlyDAOManager() {
        require(
            IAccessControl(daoFactory).hasRole(DAO_MANAGER_ROLE, msg.sender),
            PermissionDenied()
        );
        _;
    }

    modifier validTokenId(uint256 id) {
        require(id > 0 && id <= numberOfTokens, InvalidTokenId());
        _;
    }

    modifier onlyMinter() {
        require(minters[msg.sender], InvalidMinter());
        _;
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(uri_, tokenURIs[_id]));
    }

    // ========== Admin ==========
    function createToken(
        string memory _tokenURI,
        uint256 _votingPower,
        bytes32 _daoId
    ) external onlyDAOManager {
        if (IFactory(daoFactory).daoCreators(_daoId) != msg.sender) revert InvalidCreator();

        numberOfTokens++;

        uint256 id = numberOfTokens;

        tokenURIs[id] = _tokenURI;
        votingPowerPerId[id] = _votingPower;
        creators[id] = msg.sender;
        daoIds[id] = _daoId;

        emit CreatedToken(id, _daoId, _tokenURI, _votingPower, msg.sender);
    }

    function setTokenURI(
        uint256 id,
        string memory _tokenURI,
        uint256 _votingPower
    ) external onlyDefaultAdmin validTokenId(id) {
        tokenURIs[id] = _tokenURI;
        votingPowerPerId[id] = _votingPower;
        emit SetTokenURI(id, _tokenURI, _votingPower);
    }

    function mint(address to, uint256 id, uint256 amount) external onlyMinter validTokenId(id) {
        require(amount > 0, InvalidAmount());
        require(to != address(0), InvalidAddress());
        require(id <= numberOfTokens, InvalidTokenId());

        _mint(to, id, amount, "");
        _balances[to][id] += amount;

        address delegatee = _delegates[to];
        if (delegatee != address(0) && votingPowerPerId[id] > 0) {
            uint256 voteAmount = amount * votingPowerPerId[id];
            _moveVotes(address(0), delegatee, voteAmount);
        }
    }

    function setMinter(address minter) external onlyDefaultAdmin {
        minters[minter] = true;
    }

    function revoke(uint256 id, bool isRevoked_) external onlyDAOManager validTokenId(id) {
        isRevoked[id] = isRevoked_;
        emit Revoked(id, isRevoked_);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyMinter validTokenId(id) {
        require(_balances[from][id] >= amount, InvalidBalance());
        require(amount > 0, InvalidAmount());

        _burn(from, id, amount);
        _balances[from][id] -= amount;

        address delegatee = _delegates[from];
        if (delegatee != address(0) && votingPowerPerId[id] > 0) {
            uint256 voteAmount = amount * votingPowerPerId[id];
            _moveVotes(delegatee, address(0), voteAmount);
        }
    }

    // ========== Delegation ==========
    function delegate(address to) external {
        address prev = _delegates[msg.sender];
        require(prev != to, AlreadyDelegated());

        _delegates[msg.sender] = to;

        uint256 totalVotes = _calculateTotalVotes(msg.sender);

        if (totalVotes > 0) {
            if (prev != address(0)) _moveVotes(prev, address(0), totalVotes);
            _moveVotes(address(0), to, totalVotes);
        }

        emit Delegated(msg.sender, to, totalVotes);
    }

    function _calculateTotalVotes(address account) internal view returns (uint256) {
        uint256 totalVotes = 0;

        // Cache storage reads for gas optimization
        for (uint256 i = 1; i <= numberOfTokens; i++) {
            uint256 balance = _balances[account][i];

            if (balance > 0) {
                uint256 weight = votingPowerPerId[i];
                if (weight > 0) {
                    totalVotes += balance * weight;
                }
            }
        }

        return totalVotes;
    }

    function delegateOf(address who) external view returns (address) {
        return _delegates[who];
    }

    // ========== Voting Power Queries ==========
    function getVotes(address who) external view returns (uint256) {
        return _checkpoints[who].latest();
    }

    function getPastVotes(address who, uint256 blockNumber) external view returns (uint256) {
        // Fix: Checkpoints.Trace224 expects uint32 for key
        require(blockNumber <= type(uint32).max, "blockNumber too large");
        return _checkpoints[who].upperLookup(uint32(blockNumber));
    }

    function getTokenWeight(uint256 id) external view returns (uint256) {
        return votingPowerPerId[id];
    }

    function isTokenRevoked(uint256 id) external view returns (bool) {
        return isRevoked[id];
    }

    function getTotalVotingPower(address account) external view returns (uint256) {
        return _calculateTotalVotes(account);
    }

    function batchMint(
        address[] calldata to,
        uint256[] calldata ids,
        uint256[] calldata amounts
    ) external onlyMinter {
        require(to.length == ids.length && ids.length == amounts.length, InvalidArrayLength());
        require(to.length > 0, InvalidArrayLength());

        for (uint256 i = 0; i < to.length; i++) {
            require(ids[i] > 0 && ids[i] <= numberOfTokens, InvalidTokenId());
            require(amounts[i] > 0, InvalidAmount());
            require(to[i] != address(0), InvalidAddress());

            _mint(to[i], ids[i], amounts[i], "");
            _balances[to[i]][ids[i]] += amounts[i];

            address delegatee = _delegates[to[i]];
            if (delegatee != address(0) && votingPowerPerId[ids[i]] > 0) {
                uint256 voteAmount = amounts[i] * votingPowerPerId[ids[i]];
                _moveVotes(address(0), delegatee, voteAmount);
            }
        }
    }

    // ========== Internal ==========
    function _moveVotes(address from, address to, uint256 amount) internal {
        if (amount == 0) return;

        uint32 currentBlock = uint32(block.number);

        if (from != address(0)) {
            uint256 oldFrom = _checkpoints[from].latest();
            _checkpoints[from].push(currentBlock, uint224(oldFrom - amount));
        }

        if (to != address(0)) {
            uint256 oldTo = _checkpoints[to].latest();
            _checkpoints[to].push(currentBlock, uint224(oldTo + amount));
        }

        emit VotesMoved(from, to, amount);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}

interface IFactory {
    function daoCreators(bytes32 _daoId) external view returns (address);
}
