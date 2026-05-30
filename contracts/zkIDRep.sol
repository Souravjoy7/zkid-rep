// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./IdentityRegistry.sol";
import "./ReputationOracle.sol";
import "./Groth16Verifier.sol";

/**
 * @title zkIDRep
 * @notice Main entry point for the ZK-Identity Reputation Protocol.
 *         Orchestrates identity registration, reputation attestation,
 *         and ZK proof verification.
 *
 *         Users can:
 *         1. Register their identity (soulbound Merkle root)
 *         2. Receive reputation attestations from the oracle
 *         3. Generate ZK proofs off-chain
 *         4. Submit proofs on-chain for verification
 *         5. Access dApps that check their reputation privately
 */
contract zkIDRep {
    struct ZKProofRequest {
        address prover;
        bytes32 publicInputsHash;
        uint256 timestamp;
        bool verified;
    }

    IdentityRegistry public identityRegistry;
    ReputationOracle public reputationOracle;
    Groth16Verifier public verifier;

    address public owner;
    uint256 public totalProofsVerified;

    mapping(bytes32 => ZKProofRequest) public proofRequests;
    mapping(address => bool) public approvedVerifiers;

    event ProofVerified(
        address indexed prover,
        bytes32 indexed requestId,
        bytes32 publicInputsHash,
        uint256 timestamp
    );
    event VerifierApproved(address indexed verifier, bool approved);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyApprovedVerifier() {
        require(approvedVerifiers[msg.sender], "Not approved verifier");
        _;
    }

    constructor(
        address _identityRegistry,
        address _reputationOracle,
        address _verifier
    ) {
        identityRegistry = IdentityRegistry(_identityRegistry);
        reputationOracle = ReputationOracle(_reputationOracle);
        verifier = Groth16Verifier(_verifier);
        owner = msg.sender;
    }

    /**
     * @notice Register a new identity
     */
    function registerIdentity(bytes32 merkleRoot) external {
        identityRegistry.registerIdentity(msg.sender, merkleRoot);
    }

    /**
     * @notice Update identity with new Merkle root
     */
    function updateIdentity(bytes32 newMerkleRoot) external {
        identityRegistry.updateIdentity(newMerkleRoot);
    }

    /**
     * @notice Request a ZK proof verification
     * @param publicInputsHash Hash of the public inputs
     * @param proofHash Hash of the ZK proof
     */
    function requestVerification(
        bytes32 publicInputsHash,
        bytes32 proofHash
    ) external returns (bytes32 requestId) {
        (, , , bool exists) = identityRegistry.identities(msg.sender);
        require(exists, "Identity not registered");

        requestId = keccak256(abi.encodePacked(
            msg.sender,
            publicInputsHash,
            proofHash,
            block.timestamp
        ));

        bool verified = verifier.verifyProofSimple(
            proofHash,
            publicInputsHash,
            msg.sender
        );

        proofRequests[requestId] = ZKProofRequest({
            prover: msg.sender,
            publicInputsHash: publicInputsHash,
            timestamp: block.timestamp,
            verified: verified
        });

        if (verified) {
            totalProofsVerified++;
            emit ProofVerified(msg.sender, requestId, publicInputsHash, block.timestamp);
        }
    }

    /**
     * @notice Verify a user has minimum reputation (without revealing score)
     * @param user Address to check
     * @param minimumScore Minimum required score
     * @return True if user meets the threshold
     */
    function hasMinimumReputation(address user, uint256 minimumScore) external view returns (bool) {
        (uint256 totalScore, ) = reputationOracle.getReputationScore(user);
        return totalScore >= minimumScore;
    }

    /**
     * @notice Check if a proof request was verified
     */
    function isProofVerified(bytes32 requestId) external view returns (bool) {
        return proofRequests[requestId].verified;
    }

    /**
     * @notice Approve a verifier contract
     */
    function approveVerifier(address verifier_addr, bool approved) external onlyOwner {
        approvedVerifiers[verifier_addr] = approved;
        emit VerifierApproved(verifier_addr, approved);
    }

    /**
     * @notice Get user's reputation profile
     */
    function getUserReputation(address user) external view returns (
        uint256 totalScore,
        uint256 attestationCount,
        bool identityExists
    ) {
        (totalScore, attestationCount) = reputationOracle.getReputationScore(user);
        (, , , bool exists) = identityRegistry.identities(user);
        identityExists = exists;
    }

    /**
     * @notice Get total proofs verified
     */
    function getTotalProofsVerified() external view returns (uint256) {
        return totalProofsVerified;
    }

    receive() external payable {}
}
