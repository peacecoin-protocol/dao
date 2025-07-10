// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SBT (Soulbound Token)
 * @dev A non-transferable ERC1155 token implementation
 * @notice This contract implements a soulbound token that cannot be transferred
 */
contract SBT is ERC1155, Ownable {
    // State variables
    uint256 private _currentTokenId = 0;
    string public baseUri;
    string public tokenName;
    string public tokenSymbol;

    // Mappings
    mapping(uint256 => string) public tokenURIs;
    mapping(address => bool) public minters;

    // Events
    event TokenURISet(uint256 indexed tokenId, string uri);
    event MinterSet(address indexed minter, bool status);
    event TokenMinted(address indexed to, uint256 indexed tokenId, uint256 amount);
    event TokenBurned(address indexed from, uint256 indexed tokenId, uint256 amount);

    /**
     * @dev Constructor to initialize the SBT contract
     * @param _name The name of the token
     * @param _symbol The symbol of the token
     * @param _baseUri The base URI for token metadata
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseUri
    ) ERC1155(_baseUri) Ownable(msg.sender) {
        tokenName = _name;
        tokenSymbol = _symbol;
        baseUri = _baseUri;
        minters[msg.sender] = true;

        emit MinterSet(msg.sender, true);
    }

    /**
     * @dev Returns the URI for a given token ID
     * @param tokenId The token ID to get the URI for
     * @return The complete URI for the token
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(baseUri, tokenURIs[tokenId]));
    }

    /**
     * @dev Sets the URI for a specific token ID
     * @param tokenId The token ID to set the URI for
     * @param tokenURI The URI to set for the token
     */
    function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyOwner {
        require(tokenId > 0, "SBT: invalid token ID");
        tokenURIs[tokenId] = tokenURI;
        emit TokenURISet(tokenId, tokenURI);
    }

    /**
     * @dev Sets the base URI for the token
     * @param _baseUri The base URI to set
     */
    function setBaseURI(string memory _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    /**
     * @dev Mints new tokens to a specified address
     * @param to The address to mint tokens to
     * @param id The token ID to mint (0 for auto-increment)
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 id, uint256 amount) external {
        // require(minters[msg.sender], "SBT: not a minter");
        require(to != address(0), "SBT: cannot mint to zero address");
        require(amount > 0, "SBT: amount must be greater than 0");

        uint256 tokenId;
        if (id == 0) {
            _currentTokenId++;
            tokenId = _currentTokenId;
        } else {
            tokenId = id;
        }

        _mint(to, tokenId, amount, "");
        emit TokenMinted(to, tokenId, amount);
    }

    /**
     * @dev Sets the minter status for an address
     * @param minter The address to set as minter
     */
    function setMinter(address minter) external onlyOwner {
        require(minter != address(0), "SBT: cannot set zero address as minter");
        minters[minter] = true;
        emit MinterSet(minter, true);
    }

    /**
     * @dev Removes minter status from an address
     * @param minter The address to remove minter status from
     */
    function removeMinter(address minter) external onlyOwner {
        require(minter != msg.sender, "SBT: cannot remove self as minter");
        minters[minter] = false;
        emit MinterSet(minter, false);
    }

    /**
     * @dev Burns tokens from a specified address
     * @param from The address to burn tokens from
     * @param id The token ID to burn
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 id, uint256 amount) external {
        require(minters[msg.sender], "SBT: not a minter");
        require(from != address(0), "SBT: cannot burn from zero address");
        require(amount > 0, "SBT: amount must be greater than 0");

        _burn(from, id, amount);
        emit TokenBurned(from, id, amount);
    }

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
        revert("SBT: non-transferable");
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
        revert("SBT: non-transferable");
    }

    /**
     * @dev Returns the current token ID counter
     * @return The current token ID
     */
    function getCurrentTokenId() external view returns (uint256) {
        return _currentTokenId;
    }

    /**
     * @dev Returns the token name
     * @return The name of the token
     */
    function name() external view returns (string memory) {
        return tokenName;
    }

    /**
     * @dev Returns the token symbol
     * @return The symbol of the token
     */
    function symbol() external view returns (string memory) {
        return tokenSymbol;
    }
}
