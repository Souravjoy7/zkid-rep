// reputation_proof.circom
// ZK Circuit for proving reputation without revealing identity
//
// Proves: "I have a reputation score >= threshold in category X"
// without revealing: which wallet, exact score, or transaction history
//
// Compile with: circom reputation_proof.circom --r1cs --wasm --sym
// Generate proving key: snarkjs groth16 setup reputation_proof.r1cs pot12_final.ptau circuit_final.zkey
// Export verifier: snarkjs zkey export solidityverifier circuit_final.zkey Groth16Verifier.sol

pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";
include "circomlib/circuits/mimcsponge.circom";
include "circomlib/circuits/bitify.circom";

// proves knowledge of a leaf in a Merkle tree
template MerkleProof(depth) {
    signal input leaf;
    signal input pathElements[depth];
    signal input pathIndices[depth];
    signal input root;

    signal hashes[depth + 1];
    hashes[0] <== leaf;

    component mux[depth];
    component hashers[depth];

    for (var i = 0; i < depth; i++) {
        mux[i] = DualMux();
        mux[i].in[0] <== hashes[i];
        mux[i].in[1] <== pathElements[i];
        mux[i].s <== pathIndices[i];

        hashers[i] = MiMCSponge(2, 220, 1);
        hashers[i].ins[0] <== mux[i].out[0];
        hashers[i].ins[1] <== mux[i].out[1];
        hashers[i].k <== 0;

        hashes[i + 1] <== hashers[i].outs[0];
    }

    root === hashes[depth];
}

template DualMux() {
    signal input in[2];
    signal input s;
    signal output out[2];

    s * (1 - s) === 0;
    out[0] <== (in[1] - in[0]) * s + in[0];
    out[1] <== (in[0] - in[1]) * s + in[1];
}

// Main circuit: prove reputation score >= threshold
// Public inputs: merkleRoot, threshold, categoryHash
// Private inputs: score, pathElements, pathIndices, leaf
template ReputationProof(depth) {
    signal input merkleRoot;      // public: identity root
    signal input threshold;       // public: minimum score required
    signal input categoryHash;    // public: hash of category string

    signal input score;           // private: actual reputation score
    signal input pathElements[depth]; // private: Merkle proof
    signal input pathIndices[depth];  // private: Merkle proof indices
    signal input leaf;            // private: leaf hash

    // 1. Verify Merkle proof (leaf is in the tree)
    component merkle = MerkleProof(depth);
    merkle.leaf <== leaf;
    for (var i = 0; i < depth; i++) {
        merkle.pathElements[i] <== pathElements[i];
        merkle.pathIndices[i] <== pathIndices[i];
    }
    merkle.root <== merkleRoot;

    // 2. Verify score >= threshold
    component gte = GreaterEqThan(32);
    gte.in[0] <== score;
    gte.in[1] <== threshold;
    gte.out === 1;

    // 3. Bind leaf to score and category
    component leafHash = MiMCSponge(2, 220, 1);
    leafHash.ins[0] <== score;
    leafHash.ins[1] <== categoryHash;
    leafHash.k <== 0;
    leafHash.outs[0] === leaf;
}

// Instantiate with depth 16 (supports 65536 leaves)
component main {public [merkleRoot, threshold, categoryHash]} = ReputationProof(16);
