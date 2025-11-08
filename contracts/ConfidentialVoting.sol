// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Import Zama's FHE libraries for confidential types and operations
import "@zama-ai/fhevm/lib/TFHE.sol"; 

contract ConfidentialVoting {
    // --- STATE VARIABLES ---
    address public immutable owner; // The Trusted Authority (TA) for decryption

    // 1. Tracks the final, clear, publicly verifiable result (Total Yes Votes)
    mapping(bytes32 => uint256) public finalResult; 
    
    // 2. Tracks which addresses have voted per election (single-vote check)
    mapping(bytes32 => mapping(address => bool)) private hasVoted;
    
    // 3. Stores the running total of 'Yes' votes (Encrypted FHE Type)
    mapping(bytes32 => TFHE.euint8) public encryptedTally;

    // --- ENUMS & EVENTS ---
    enum Status { Open, Closed, Finalized }
    mapping(bytes32 => Status) public electionStatus;

    event ResultFinalized(bytes32 indexed electionId, uint256 totalYesVotes);

    constructor() {
        owner = msg.sender;
    }

    // --- 🗳️ CORE FUNCTIONALITY ---

    function startElection(bytes32 _electionId) public {
        require(msg.sender == owner, "Only the owner can start elections.");
        // Initialize the encrypted tally to 0 (encrypted)
        encryptedTally[_electionId] = TFHE.euint8.getZero();
        electionStatus[_electionId] = Status.Open;
    }

    // This is the FHE-enabled function
    function submitVote(bytes32 _electionId, TFHE.euint8 _encryptedVote) public {
        // 1. CHECK: Election status and single-vote
        require(electionStatus[_electionId] == Status.Open, "Voting is closed or finalized.");
        require(hasVoted[_electionId][msg.sender] == false, "You have already voted.");

        // 2. FHE ADDITION: The core confidential operation
        // The FHEVM performs the addition on the encrypted data.
        encryptedTally[_electionId] = encryptedTally[_electionId] + _encryptedVote; 
        
        // 3. RECORD: Mark the user as having voted
        hasVoted[_electionId][msg.sender] = true;
    }

    function closeVoting(bytes32 _electionId) public {
        require(msg.sender == owner, "Only the owner can close voting.");
        require(electionStatus[_electionId] == Status.Open, "Election is not open.");
        electionStatus[_electionId] = Status.Closed;
    }
    
    // Function for the Admin to publish the result after *off-chain decryption*
    function setFinalResult(bytes32 _electionId, uint256 _totalYesVotes) public {
        require(msg.sender == owner, "Only the owner can finalize results.");
        require(electionStatus[_electionId] == Status.Closed, "Must be closed before finalizing.");
        
        finalResult[_electionId] = _totalYesVotes;
        electionStatus[_electionId] = Status.Finalized;
        emit ResultFinalized(_electionId, _totalYesVotes);
    }
}
