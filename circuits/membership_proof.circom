// membership_proof.circom
// ZK Circuit for proving membership in a reputation tier
//
// Proves: "I am a member of tier X" (e.g., "Gold DeFi User")
// without revealing: which specific address, exact score, or history
//
// Tier definitions:
//   0-199:  Bronze
//   200-499: Silver
//   500-799: Gold
//   800-1000: Platinum

pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/mimcsponge.circom";

template MembershipProof(depth) {
    signal input merkleRoot;      // public: identity root
    signal input tierHash;        // public: hash of tier name
    signal input minScore;        // public: tier minimum score
    signal input maxScore;        // public: tier maximum score

    signal input score;           // private: actual score
    signal input pathElements[depth]; // private: Merkle proof
    signal input pathIndices[depth];  // private: Merkle proof indices
    signal input leaf;            // private: leaf hash

    // 1. Verify Merkle proof
    component hashers[depth];
    signal hashes[depth + 1];
    hashes[0] <== leaf;

    for (var i = 0; i < depth; i++) {
        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].ins[0] <== hashes[i];
        hashers[i].ins[1] <== pathElements[i];
        hashers[i].k <== 0;
        hashes[i + 1] <== hashers[i].outs[0];
    }

    merkleRoot === hashes[depth];

    // 2. Verify score is within tier range
    component gte = GreaterEqThan(32);
    gte.in[0] <== score;
    gte.in[1] <== minScore;
    gte.out === 1;

    component lte = LessEqThan(32);
    lte.in[0] <== score;
    lte.in[1] <== maxScore;
    lte.out === 1;

    // 3. Bind leaf to score and tier
    component leafHash = MiMCSponge(2, 220, 1);
    leafHash.ins[0] <== score;
    leafHash.ins[1] <== tierHash;
    leafHash.k <== 0;
    leafHash.outs[0] === leaf;
}

component main {public [merkleRoot, tierHash, minScore, maxScore]} = MembershipProof(16);
