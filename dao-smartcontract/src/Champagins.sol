// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {console} from "forge-std/console.sol";

contract Champagins is Initializable, OwnableUpgradeable {
    using ECDSA for bytes32;
    
    struct Champagin {
        string title;
        string description;
        uint256 amount;
        uint256 startDate;
        uint256 endDate;
        bool validateSignatures;
    }

    uint256 public champaginId;
    ERC20Upgradeable public token;

    mapping(uint256 => address[]) public champWinners;
    mapping(uint256 => Champagin) public champagins;
    mapping(uint256 => mapping(address => bool)) public champWinnersClaimed;


    event ChampWinnersAdded(uint256 indexed champaginId, address[] winners);
    event ChampWinnersClaimed(uint256 indexed champaginId, address indexed winner);
    event ChampaginCreated(uint256 indexed champaginId);

    function initialize(ERC20Upgradeable _token) public initializer {
        token = _token;
        __Ownable_init(msg.sender);
    }

    function createChampagin(Champagin memory _champagin) external onlyOwner {
        require(_champagin.startDate < _champagin.endDate, "Start date must be before end date");
        require(_champagin.amount > 0, "Amount must be greater than 0");
        require(_champagin.startDate > block.timestamp, "Start date must be in the future");

        champagins[champaginId] = _champagin;
        
        emit ChampaginCreated(champaginId);
        champaginId++;
    }

    function addChampWinners(uint256 _champaginId, address[] memory _winners) external onlyOwner {
        require(champagins[_champaginId].endDate > block.timestamp, "Champagin has ended");

        for (uint256 i = 0; i < _winners.length; i++) {
            champWinners[_champaginId].push(_winners[i]);
        }

        emit ChampWinnersAdded(_champaginId, _winners);
    }

    function claimChampagin(uint256 _champaginId, string memory _message, bytes memory _signature) external {
        require(champagins[_champaginId].endDate > block.timestamp, "Champagin has ended");
        require(champWinners[_champaginId].length > 0, "Champagin has no winners");
        require(!champWinnersClaimed[_champaginId][msg.sender], "You have already claimed your prize");

        if (champagins[_champaginId].validateSignatures) {
            require(verify(msg.sender, _message, _signature), "Invalid signature");
        }

        bool isWinner = false;
        for (uint256 i = 0; i < champWinners[_champaginId].length; i++) {
            if (champWinners[_champaginId][i] == msg.sender) {
                isWinner = true;
                break;
            }
        }
        require(isWinner, "You are not a winner");

        champWinnersClaimed[_champaginId][msg.sender] = true;
        token.transfer(msg.sender, champagins[_champaginId].amount);

        emit ChampWinnersClaimed(_champaginId, msg.sender);
    }

    function verify(address _signer,string memory _message,bytes memory _sig) public pure returns (bool){
        bytes32 messageHash = getMessageHash(_message);
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(messageHash);
        return recoverSigner(ethSignedMessageHash,_sig) ==_signer;
    }
    // can be updated with more data such as to addres and amount later

    function getMessageHash(string memory _message) public pure returns(bytes32){
        return keccak256(abi.encodePacked(_message));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) internal pure returns(bytes32){
        return keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash)
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

    }

    function recoverERC20(ERC20Upgradeable token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}
