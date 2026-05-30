// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CrossChainReputation
 * @notice Syncs reputation across chains using Chainlink CCIP.
 *         Sends reputation attestations from source chain to destination chain.
 *         Supports multiple L1/L2 networks.
 */
interface IRouterClient {
    function routeMessage(
        address receiver,
        bytes calldata data,
        uint64 destinationChainSelector,
        address feeToken
    ) external payable returns (bytes32);
}

contract CrossChainReputation {
    uint64 public constant BASE_SEPOLIA_SELECTOR = 10344971234823188542; // CCIP selector
    uint64 public constant ETHEREUM_SEPOLIA_SELECTOR = 16015286601757825753;

    struct CrossChainAttestation {
        address sourceUser;
        address destUser;
        uint64 sourceChainSelector;
        string category;
        uint256 score;
        uint256 timestamp;
    }

    mapping(bytes32 => CrossChainAttestation) public crossChainAttestations;
    mapping(address => mapping(uint64 => uint256)) public chainReputation;

    IRouterClient public router;
    address public owner;

    event ReputationSent(
        bytes32 indexed messageId,
        address sourceUser,
        address destUser,
        uint64 destChain,
        string category,
        uint256 score
    );
    event ReputationReceived(
        bytes32 indexed messageId,
        address sourceUser,
        address destUser,
        string category,
        uint256 score
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _router) {
        router = IRouterClient(_router);
        owner = msg.sender;
    }

    /**
     * @notice Send reputation attestation to another chain
     * @param destUser User on the destination chain
     * @param destChainSelector CCIP chain selector for destination
     * @param category Reputation category
     * @param score Reputation score
     * @return messageId CCIP message ID
     */
    function sendReputation(
        address destUser,
        uint64 destChainSelector,
        string calldata category,
        uint256 score
    ) external payable returns (bytes32 messageId) {
        require(score <= 1000, "Score must be 0-1000");

        CrossChainAttestation memory att = CrossChainAttestation({
            sourceUser: msg.sender,
            destUser: destUser,
            sourceChainSelector: _getChainSelector(),
            category: category,
            score: score,
            timestamp: block.timestamp
        });

        bytes memory payload = abi.encode(att);

        messageId = router.routeMessage(
            address(this),
            payload,
            destChainSelector,
            msg.value > 0 ? msg.sender : address(0)
        );

        crossChainAttestations[messageId] = att;
        emit ReputationSent(messageId, msg.sender, destUser, destChainSelector, category, score);
    }

    /**
     * @notice Receive reputation attestation from another chain
     *         Called by CCIP router on the destination chain
     */
    function ccipReceive(
        bytes32 messageId,
        uint64 sourceChainSelector,
        address sender,
        bytes calldata data
    ) external {
        require(msg.sender == address(router), "Only CCIP router");

        CrossChainAttestation memory att = abi.decode(data, (CrossChainAttestation));

        crossChainAttestations[messageId] = att;
        chainReputation[att.destUser][sourceChainSelector] += att.score;

        emit ReputationReceived(messageId, att.sourceUser, att.destUser, att.category, att.score);
    }

    /**
     * @notice Get a user's reputation from a specific chain
     */
    function getChainReputation(address user, uint64 chainSelector) external view returns (uint256) {
        return chainReputation[user][chainSelector];
    }

    /**
     * @notice Get aggregate cross-chain reputation for a user
     */
    function getAggregateReputation(address user) external view returns (uint256 totalScore) {
        // In production, iterate over known chain selectors
        totalScore = chainReputation[user][BASE_SEPOLIA_SELECTOR] +
                     chainReputation[user][ETHEREUM_SEPOLIA_SELECTOR];
    }

    function _getChainSelector() internal view returns (uint64) {
        // Simplified: return Base Sepolia selector
        return BASE_SEPOLIA_SELECTOR;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        // CCIPReceiver interface
        return interfaceId == 0x0100baca; // CCIPReceiver.selector
    }

    receive() external payable {}
}
