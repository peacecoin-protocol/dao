// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SBT is ERC1155, Ownable {
    uint256 private currentTokenId = 0;
    string public uri_;
    string public name;
    string public symbol;
    mapping(uint256 => string) public tokenURIs;
    mapping(address => bool) public minters;

    event SetTokenURI(uint256 indexed id, string uri);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) ERC1155(_uri) Ownable(msg.sender) {
        name = _name;
        symbol = _symbol;
        uri_ = _uri;
        minters[msg.sender] = true;
    }

    function uri(uint256 _id) public view virtual override returns (string memory) {
        return string(abi.encodePacked(uri_, tokenURIs[_id]));
    }

    function setTokenURI(uint256 _id, string memory _tokenURI) external onlyOwner {
        tokenURIs[_id] = _tokenURI;
        emit SetTokenURI(_id, _tokenURI);
    }

    function mint(address to, uint256 id, uint256 amount) external {
        require(minters[msg.sender], "SBT: not a minter");
        currentTokenId++;
        require(id <= currentTokenId, "Invalid token ID");
        _mint(to, id, amount, "");
    }

    function setMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }

    function safeTransferFrom(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public pure override {
        revert("SBT: non-transferable");
    }
}
