// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "forge-std/console.sol";

contract PEACECOINDAO_SBT is Initializable, OwnableUpgradeable, ERC1155Upgradeable {
    using Checkpoints for Checkpoints.Trace224;
    using EnumerableSet for EnumerableSet.UintSet;

    string public uri_;
    string public name;
    string public symbol;

    uint256 public currentTokenId = 1;
    mapping(uint256 => string) public tokenURIs;
    mapping(address => bool) public minters;
    mapping(uint256 => bool) public isRevoked;

    function initialize(
        string memory _uri,
        string memory _name,
        string memory _symbol
    ) external initializer {
        uri_ = _uri;
        name = _name;
        symbol = _symbol;
        minters[msg.sender] = true;
        __ERC1155_init(_uri);
        __Ownable_init(msg.sender);
    }

    // Voting weight per token ID
    mapping(uint256 => uint256) public votingPowerPerId;

    // Track all token IDs with assigned weights
    EnumerableSet.UintSet private _allTokenIds;

    // Balances per user
    mapping(address => mapping(uint256 => uint256)) private _balances;

    // Delegation and voting history
    mapping(address => address) private _delegates;
    mapping(address => Checkpoints.Trace224) private _checkpoints;

    event SetTokenURI(uint256 indexed id, string uri);
    event Revoked(uint256 indexed id, bool isRevoked);

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked(uri_, tokenURIs[_id]));
    }

    // ========== Admin ==========
    function setTokenURI(uint256 id, string memory _tokenURI, uint256 weight) external {
        // require(minters[msg.sender], "PEACECOINDAO_SBT: not a minter");

        tokenURIs[id] = _tokenURI;
        votingPowerPerId[id] = weight;
        _allTokenIds.add(id);

        emit SetTokenURI(id, _tokenURI);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        // require(minters[msg.sender], "PEACECOINDAO_SBT: not a minter");

        require(id <= currentTokenId, "Invalid token ID");

        uint256 _tokenId;
        if (id != 0) {
            _tokenId = id;
        } else {
            _tokenId = currentTokenId;
        }

        _mint(to, _tokenId, amount, "");
        _balances[to][_tokenId] += amount;

        address delegatee = _delegates[to];
        if (delegatee != address(0) && votingPowerPerId[_tokenId] > 0) {
            _moveVotes(address(0), delegatee, amount * votingPowerPerId[_tokenId]);
        }

        if (id == 0 || id == currentTokenId) {
            currentTokenId++;
        }
    }

    function revoke(uint256 id, bool isRevoked_) external {
        isRevoked[id] = isRevoked_;
        emit Revoked(id, isRevoked_);
    }

    function setMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }

    function burn(address from, uint256 id, uint256 amount) external {
        require(_balances[from][id] >= amount, "PEACECOINDAO_SBT: not enough balance");

        _burn(from, id, amount);
        _balances[from][id] -= amount;

        address delegatee = _delegates[from];
        if (delegatee != address(0) && votingPowerPerId[id] > 0) {
            _moveVotes(delegatee, address(0), amount * votingPowerPerId[id]);
        }
    }

    // ========== Delegation ==========
    function delegate(address to) external {
        address prev = _delegates[msg.sender];
        require(prev != to, "Already delegated");

        _delegates[msg.sender] = to;

        uint256 totalVotes = 0;
        uint256 len = _allTokenIds.length();
        for (uint256 i = 0; i < len; i++) {
            uint256 id = _allTokenIds.at(i);
            uint256 bal = _balances[msg.sender][id];
            uint256 w = votingPowerPerId[id];

            if (bal > 0 && w > 0) {
                totalVotes += bal * w;
            }
        }

        if (totalVotes > 0) {
            if (prev != address(0)) _moveVotes(prev, address(0), totalVotes);
            _moveVotes(address(0), to, totalVotes);
        }
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

    function getAllTokenIds() external view returns (uint256[] memory) {
        uint256 len = _allTokenIds.length();
        uint256[] memory ids = new uint256[](len);
        for (uint256 i = 0; i < len; i++) {
            ids[i] = _allTokenIds.at(i);
        }
        return ids;
    }

    function getAllTokenLength() external view returns (uint256) {
        return _allTokenIds.length();
    }

    // ========== Internal ==========
    function _moveVotes(address from, address to, uint256 amount) internal {
        if (amount == 0) return;

        if (from != address(0)) {
            uint256 old = _checkpoints[from].latest();
            // Fix: block.number must be cast to uint32
            _checkpoints[from].push(uint32(block.number), uint224(old - amount));
        }
        if (to != address(0)) {
            uint256 old = _checkpoints[to].latest();
            // Fix: block.number must be cast to uint32
            _checkpoints[to].push(uint32(block.number), uint224(old + amount));
        }
    }
}
