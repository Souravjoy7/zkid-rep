// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ReputationOracle
 * @notice Attests reputation from on-chain history.
 *         The oracle scans a user's transaction history, DeFi activity,
 *         governance participation, etc. and issues attestations.
 */
contract ReputationOracle {
    struct Attestation {
        address user;
        string category;      // "defi", "governance", "nft", "bridge"
        uint256 score;        // 0-1000 normalized score
        uint256 dataHash;     // hash of the raw data used for scoring
        uint256 issuedAt;
        uint256 expiresAt;
        bool valid;
    }

    struct ReputationProfile {
        uint256 totalScore;
        uint256 attestationCount;
        uint256 lastUpdate;
    }

    mapping(address => Attestation[]) public attestations;
    mapping(address => ReputationProfile) public profiles;

    address public oracle;
    uint256 public constant ATTESTATION_TTL = 365 days;

    event AttestationIssued(
        address indexed user,
        string category,
        uint256 score,
        uint256 dataHash,
        uint256 timestamp
    );
    event AttestationRevoked(address indexed user, uint256 index);

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle");
        _;
    }

    constructor() {
        oracle = msg.sender;
    }

    /**
     * @notice Issue a reputation attestation for a user
     * @param user Address to attest
     * @param category Category of reputation (defi, governance, etc.)
     * @param score Normalized score 0-1000
     * @param dataHash Hash of the raw data used for scoring
     */
    function attest(
        address user,
        string calldata category,
        uint256 score,
        uint256 dataHash
    ) external onlyOracle {
        require(score <= 1000, "Score must be 0-1000");
        require(bytes(category).length > 0, "Category required");

        Attestation memory att = Attestation({
            user: user,
            category: category,
            score: score,
            dataHash: dataHash,
            issuedAt: block.timestamp,
            expiresAt: block.timestamp + ATTESTATION_TTL,
            valid: true
        });

        attestations[user].push(att);

        profiles[user].totalScore += score;
        profiles[user].attestationCount += 1;
        profiles[user].lastUpdate = block.timestamp;

        emit AttestationIssued(user, category, score, dataHash, block.timestamp);
    }

    /**
     * @notice Revoke an attestation
     */
    function revokeAttestation(address user, uint256 index) external onlyOracle {
        require(index < attestations[user].length, "Invalid index");
        attestations[user][index].valid = false;
        emit AttestationRevoked(user, index);
    }

    /**
     * @notice Get a user's aggregate reputation score
     */
    function getReputationScore(address user) external view returns (uint256 totalScore, uint256 count) {
        ReputationProfile storage profile = profiles[user];
        return (profile.totalScore, profile.attestationCount);
    }

    /**
     * @notice Check if a specific attestation is valid and not expired
     */
    function isAttestationValid(address user, uint256 index) external view returns (bool) {
        if (index >= attestations[user].length) return false;
        Attestation storage att = attestations[user][index];
        return att.valid && block.timestamp <= att.expiresAt;
    }

    /**
     * @notice Get all valid attestations for a user
     */
    function getValidAttestations(address user) external view returns (uint256[] memory scores, string[] memory categories) {
        Attestation[] storage atts = attestations[user];
        uint256 validCount = 0;

        for (uint256 i = 0; i < atts.length; i++) {
            if (atts[i].valid && block.timestamp <= atts[i].expiresAt) {
                validCount++;
            }
        }

        scores = new uint256[](validCount);
        categories = new string[](validCount);
        uint256 idx = 0;

        for (uint256 i = 0; i < atts.length; i++) {
            if (atts[i].valid && block.timestamp <= atts[i].expiresAt) {
                scores[idx] = atts[i].score;
                categories[idx] = atts[i].category;
                idx++;
            }
        }
    }

    function setOracle(address newOracle) external {
        require(msg.sender == oracle, "Only oracle");
        oracle = newOracle;
    }
}
