// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract Campagins is Initializable, OwnableUpgradeable {
    using ECDSA for bytes32;
    using Strings for uint256;

    struct Campagin {
        string title;
        string description;
        uint256 amount;
        uint256 startDate;
        uint256 endDate;
        bool validateSignatures;
    }

    enum Status {
        Pending,
        Active,
        Ended
    }

    uint256 public campaginId;
    ERC20Upgradeable public token;

    mapping(uint256 => address[]) public campWinners;
    mapping(uint256 => Campagin) public campagins;
    mapping(uint256 => mapping(address => bool)) public champWinnersClaimed;
    mapping(address => uint256) public totalClaimed;

    event CampWinnersAdded(uint256 indexed campaginId, address[] winners);
    event CampWinnersClaimed(uint256 indexed campaginId, address indexed winner);
    event CampaginCreated(uint256 indexed campaginId, string title, string description, uint256 amount, uint256 startDate, uint256 endDate, bool validateSignatures);

    function initialize(ERC20Upgradeable _token) public initializer {
        token = _token;
        __Ownable_init(msg.sender);
    }

    function createCampagin(Campagin memory _campagin) external onlyOwner {
        require(_campagin.startDate < _campagin.endDate, "Start date must be before end date");
        require(_campagin.amount > 0, "Amount must be greater than 0");
        require(_campagin.startDate > block.timestamp, "Start date must be in the future");

        campagins[campaginId] = _campagin;
        
        emit CampaginCreated(campaginId, _campagin.title, _campagin.description, _campagin.amount, _campagin.startDate, _campagin.endDate, _campagin.validateSignatures);
        campaginId++;
    }

    function addCampWinners(uint256 _campaginId, address[] memory _winners) external onlyOwner {
        require(campagins[_campaginId].endDate > block.timestamp, "Campagin has ended");

        for (uint256 i = 0; i < _winners.length; i++) {
            campWinners[_campaginId].push(_winners[i]);
        }

        emit CampWinnersAdded(_campaginId, _winners);
    }

    function claimCampagin(uint256 _campaginId, string memory _message, bytes memory _signature) external {
        require(campagins[_campaginId].endDate > block.timestamp, "Campagin has ended");
        require(campWinners[_campaginId].length > 0, "Campagin has no winners");
        require(!champWinnersClaimed[_campaginId][msg.sender], "You have already claimed your prize");

        if (campagins[_campaginId].validateSignatures) {
            require(verify(msg.sender, _message, _signature), "Invalid signature");
        }

        bool isWinner = false;
        for (uint256 i = 0; i < campWinners[_campaginId].length; i++) {
            if (campWinners[_campaginId][i] == msg.sender) {
                isWinner = true;
                break;
            }
        }
        require(isWinner, "You are not a winner");

        champWinnersClaimed[_campaginId][msg.sender] = true;
        totalClaimed[msg.sender] += campagins[_campaginId].amount;
        token.transfer(msg.sender, campagins[_campaginId].amount);

        emit CampWinnersClaimed(_campaginId, msg.sender);
    }

    function verify(address _signer,string memory _message,bytes memory _sig) public pure returns (bool){
        bytes32 ethSignedMessageHash = getEthSignedMessageHash(_message);
        return recoverSigner(ethSignedMessageHash,_sig) ==_signer;
    }

    function getEthSignedMessageHash(string memory message) internal pure returns(bytes32){

        bytes memory messageBytes = bytes(message);
        uint256 messageLength = messageBytes.length;

        return keccak256(
                abi.encodePacked("\x19Ethereum Signed Message:\n", messageLength.toString(), message)
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

        // EIP-155 support
        if (v < 27) {
            v += 27;
        }

        require(v == 27 || v == 28, "invalid v value");
    }

    function recoverERC20(ERC20Upgradeable token) external onlyOwner {
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    function getStatus(uint256 _campaginId) external view returns (Status) {
        if (campagins[_campaginId].endDate > block.timestamp) {
            return Status.Active;
        }
        return Status.Ended;
    }

    function isWinner(uint256 _campaginId, address _winner) external view returns (bool) {
        for (uint256 i = 0; i < campWinners[_campaginId].length; i++) {
            if (campWinners[_campaginId][i] == _winner) {
                return true;
            }
        }
        return false;
    }
}
