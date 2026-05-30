// range_proof.circom
// ZK Circuit for proving a value falls within a range
//
// Proves: "My reputation score is between min and max"
// without revealing the exact score
//
// Useful for tier-based reputation (bronze, silver, gold, platinum)

pragma circom 2.0.0;

include "circomlib/circuits/comparators.circom";

template RangeProof(nBits) {
    signal input value;       // private: the actual value
    signal input min;         // public: minimum bound
    signal input max;         // public: maximum bound

    // Verify value >= min
    component gte = GreaterEqThan(nBits);
    gte.in[0] <== value;
    gte.in[1] <== min;
    gte.out === 1;

    // Verify value <= max
    component lte = LessEqThan(nBits);
    lte.in[0] <== value;
    lte.in[1] <== max;
    lte.out === 1;
}

// 32-bit range proof (supports values up to 4,294,967,295)
component main {public [min, max]} = RangeProof(32);
