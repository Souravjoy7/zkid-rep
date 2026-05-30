// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title IdentityRegistry
 * @notice Soulbound identity root registration.
 *         Users register a Merkle root derived from their on-chain history.
 *         The root is bound to their wallet and cannot be transferred.
 */
contract IdentityRegistry {
    struct Identity {
        bytes32 merkleRoot;
        uint256 registeredAt;
        uint256 lastUpdated;
        bool exists;
    }

    mapping(address => Identity) public identities;
    address[] public registeredUsers;

    event IdentityRegistered(address indexed user, bytes32 merkleRoot, uint256 timestamp);
    event IdentityUpdated(address indexed user, bytes32 newMerkleRoot, uint256 timestamp);

    modifier onlyRegistered() {
        require(identities[msg.sender].exists, "Identity not registered");
        _;
    }

    /**
     * @notice Register a new identity with a Merkle root
     * @param user Address to register (can be self or proxy)
     * @param merkleRoot Merkle root of the user's reputation data
     */
    function registerIdentity(address user, bytes32 merkleRoot) external {
        require(!identities[user].exists, "Identity already registered");
        require(merkleRoot != bytes32(0), "Invalid Merkle root");

        identities[user] = Identity({
            merkleRoot: merkleRoot,
            registeredAt: block.timestamp,
            lastUpdated: block.timestamp,
            exists: true
        });

        registeredUsers.push(user);
        emit IdentityRegistered(user, merkleRoot, block.timestamp);
    }

    /**
     * @notice Update identity with a new Merkle root
     * @param newMerkleRoot Updated Merkle root
     */
    function updateIdentity(bytes32 newMerkleRoot) external {
        require(identities[msg.sender].exists, "Identity not registered");
        require(newMerkleRoot != bytes32(0), "Invalid Merkle root");

        identities[msg.sender].merkleRoot = newMerkleRoot;
        identities[msg.sender].lastUpdated = block.timestamp;

        emit IdentityUpdated(msg.sender, newMerkleRoot, block.timestamp);
    }

    /**
     * @notice Verify a user's identity exists and has a specific Merkle root
     */
    function verifyIdentity(address user, bytes32 expectedRoot) external view returns (bool) {
        Identity storage id = identities[user];
        return id.exists && id.merkleRoot == expectedRoot;
    }

    function getUserCount() external view returns (uint256) {
        return registeredUsers.length;
    }

    function getUserAtIndex(uint256 index) external view returns (address) {
        require(index < registeredUsers.length, "Index out of bounds");
        return registeredUsers[index];
    }
}
