// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    AccessControlUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {IErrors} from "../interfaces/IErrors.sol";
import {IDAOFactory} from "../interfaces/IDAOFactory.sol";

contract PeaceCoinDaoNft is Initializable, ERC1155Upgradeable, AccessControlUpgradeable, IErrors {
    using Checkpoints for Checkpoints.Trace224;
    using EnumerableSet for EnumerableSet.UintSet;

    error BlockNumberTooLarge();
    error InsufficientVotesToMove();
    error VoteCalculationOverflow();
    error VoteOverflow();

    bytes32 public constant DAO_MANAGER_ROLE = keccak256("DAO_MANAGER_ROLE");

    // Packed storage for gas optimization
    string public uri_;
    string public name;
    string public symbol;
    address public daoFactory;
    uint256 public numberOfTokens;

    mapping(uint256 => string) public tokenUrIs;
    mapping(address => bool) public minters;
    mapping(uint256 => bool) public isRevoked;
    mapping(uint256 => address) public creators;

    function initialize(
        string memory baseUri,
        address daoFactoryAddress,
        address owner,
        bool isSbt
    ) external initializer {
        __AccessControl_init();
        __ERC1155_init(baseUri);

        uri_ = baseUri;
        daoFactory = daoFactoryAddress;

        if (isSbt) {
            name = "PEACECOIN DAO SBT";
            symbol = "PCE_SBT";
        } else {
            name = "PEACECOIN DAO NFT";
            symbol = "PCE_NFT";
        }

        minters[owner] = true;
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
    }

    // Voting weight per token ID
    mapping(uint256 => uint256) public votingPowerPerId;

    // Delegation and voting history
    mapping(address => address) private _delegates;
    mapping(address => Checkpoints.Trace224) private _checkpoints;

    event Revoked(uint256 indexed tokenId, bool isRevoked);
    event CreatedToken(uint256 indexed tokenId, string tokenURI, uint256 votingPower);
    event Delegated(address indexed delegator, address indexed delegatee, uint256 votes);
    event VotesMoved(address indexed from, address indexed to, uint256 amount);
    event SetTokenURI(uint256 indexed tokenId, string uri, uint256 weight);

    modifier onlyDefaultAdmin() {
        _onlyDefaultAdmin();
        _;
    }

    function _onlyDefaultAdmin() internal view {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert PermissionDenied();
    }

    modifier validTokenId(uint256 id) {
        _validTokenId(id);
        _;
    }

    function _validTokenId(uint256 id) internal view {
        if (id == 0 || id > numberOfTokens) revert InvalidTokenId();
    }

    modifier onlyMinter() {
        _onlyMinter();
        _;
    }

    function _onlyMinter() internal view {
        if (
            !minters[msg.sender] && address(IDAOFactory(daoFactory).campaignFactory()) != msg.sender
        ) {
            revert InvalidMinter();
        }
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(uri_, tokenUrIs[id]));
    }

    // ========== Admin ==========
    function createToken(string memory tokenUri, uint256 votingPower) external onlyDefaultAdmin {
        numberOfTokens++;
        uint256 id = numberOfTokens;

        tokenUrIs[id] = tokenUri;
        votingPowerPerId[id] = votingPower;
        creators[id] = msg.sender;

        emit CreatedToken(id, tokenUri, votingPower);
    }

    function setTokenURI(
        uint256 id,
        string memory tokenUri,
        uint256 votingPower
    ) external onlyDefaultAdmin validTokenId(id) {
        tokenUrIs[id] = tokenUri;
        votingPowerPerId[id] = votingPower;
        emit SetTokenURI(id, tokenUri, votingPower);
    }

    function mint(address to, uint256 id, uint256 amount) external onlyMinter validTokenId(id) {
        if (amount == 0) revert InvalidAmount();
        if (to == address(0)) revert InvalidAddress();

        _mint(to, id, amount, "");
    }

    function setMinter(address minter) external onlyDefaultAdmin {
        minters[minter] = true;
    }

    function removeMinter(address minter) external onlyDefaultAdmin {
        minters[minter] = false;
    }

    function revoke(uint256 id, bool isRevoked_) external onlyDefaultAdmin validTokenId(id) {
        isRevoked[id] = isRevoked_;
        emit Revoked(id, isRevoked_);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyMinter validTokenId(id) {
        if (balanceOf(from, id) < amount) revert InvalidBalance();
        if (amount == 0) revert InvalidAmount();

        _burn(from, id, amount);
        // Balance and voting power updates are handled in _update
    }

    // ========== Delegation ==========
    function delegate(address to) external {
        if (to == address(0)) revert InvalidAddress();

        address prev = _delegates[msg.sender];

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
            uint256 balance = balanceOf(account, i);

            if (balance > 0) {
                uint256 weight = votingPowerPerId[i];
                if (weight > 0) {
                    // Check for overflow: balance * weight <= type(uint256).max
                    if (balance > type(uint256).max / weight) revert VoteCalculationOverflow();
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
        if (blockNumber > type(uint32).max) revert BlockNumberTooLarge();
        // casting to 'uint32' is safe because blockNumber is checked above to fit
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 blockNumber32 = uint32(blockNumber);
        return _checkpoints[who].upperLookup(blockNumber32);
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
        if (to.length == 0) revert InvalidArrayLength();
        if (to.length != ids.length || ids.length != amounts.length) {
            revert InvalidArrayLength();
        }

        for (uint256 i = 0; i < to.length; i++) {
            if (ids[i] == 0 || ids[i] > numberOfTokens) revert InvalidTokenId();
            if (amounts[i] == 0) revert InvalidAmount();
            if (to[i] == address(0)) revert InvalidAddress();

            _mint(to[i], ids[i], amounts[i], "");
            // Balance and voting power updates are handled in _update
        }
    }

    // ========== Internal ==========
    function _moveVotes(address from, address to, uint256 amount) internal {
        if (amount == 0) return;

        uint256 blockNumber = block.number;
        if (blockNumber > type(uint32).max) revert BlockNumberTooLarge();
        // casting to 'uint32' is safe because blockNumber is checked above to fit
        // forge-lint: disable-next-line(unsafe-typecast)
        uint32 currentBlock = uint32(blockNumber);

        if (from != address(0)) {
            uint256 oldFrom = _checkpoints[from].latest();
            if (oldFrom < amount) revert InsufficientVotesToMove();
            uint256 newFrom = oldFrom - amount;
            if (newFrom > type(uint224).max) revert VoteOverflow();
            // casting to 'uint224' is safe because newFrom is checked above to fit
            // forge-lint: disable-next-line(unsafe-typecast)
            _checkpoints[from].push(currentBlock, uint224(newFrom));
        }

        if (to != address(0)) {
            uint256 oldTo = _checkpoints[to].latest();
            uint256 newTo = oldTo + amount;
            if (newTo > type(uint224).max) revert VoteOverflow();
            // casting to 'uint224' is safe because newTo is checked above to fit
            // forge-lint: disable-next-line(unsafe-typecast)
            _checkpoints[to].push(currentBlock, uint224(newTo));
        }

        emit VotesMoved(from, to, amount);
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override {
        // Call parent to handle base ERC1155 transfer logic
        // This already updates ERC1155's internal balances
        super._update(from, to, ids, values);

        // Calculate and adjust voting power on token transfer
        // Process each token individually to correctly handle vote transfers
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 value = values[i];
            uint256 weight = votingPowerPerId[id];

            if (weight > 0 && value > 0) {
                // Check for overflow: value * weight <= type(uint256).max
                if (value > type(uint256).max / weight) revert VoteCalculationOverflow();
                uint256 votes = value * weight;

                // Get delegates (only if addresses are not zero)
                address fromDelegate = address(0);
                address toDelegate = address(0);

                if (from != address(0)) {
                    fromDelegate = _delegates[from];
                }
                if (to != address(0)) {
                    toDelegate = _delegates[to];
                }

                // Move votes from sender's delegate (if delegated)
                if (fromDelegate != address(0)) {
                    _moveVotes(fromDelegate, address(0), votes);
                }

                // Move votes to recipient's delegate (if delegated)
                if (toDelegate != address(0)) {
                    _moveVotes(address(0), toDelegate, votes);
                }
            }
        }
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
