# zkID-Rep — ZK-Identity Reputation Protocol

**Portable, private, cross-chain reputation using zero-knowledge proofs.**

Your reputation on Uniswap, Aave, OpenSea is trapped in silos. zkID-Rep fixes that — prove your reputation without revealing your identity, across any chain.

## On-Chain Proof (Linea Sepolia — ZK-Rollup)

| Contract | Address | Tx Hash |
|----------|---------|---------|
| **zkIDRep** (main) | [`0xd57F10CF1f9f49ce0482B5c988A54b549964E611`](https://sepolia.lineascan.build/address/0xd57F10CF1f9f49ce0482B5c988A54b549964E611) | Verified on [Lineascan](https://sepolia.lineascan.build/address/0xd57F10CF1f9f49ce0482B5c988A54b549964E611) |
| IdentityRegistry | [`0x46f2cb3BF5730CE7B3796b0E64f1C3Bb15B6A79C`](https://sepolia.lineascan.build/address/0x46f2cb3BF5730CE7B3796b0E64f1C3Bb15B6A79C) | Verified on [Lineascan](https://sepolia.lineascan.build/address/0x46f2cb3BF5730CE7B3796b0E64f1C3Bb15B6A79C) |
| ReputationOracle | [`0x3f8d121a69176C98385C67f9A0a33dE3b0aeBFa7`](https://sepolia.lineascan.build/address/0x3f8d121a69176C98385C67f9A0a33dE3b0aeBFa7) | Verified on [Lineascan](https://sepolia.lineascan.build/address/0x3f8d121a69176C98385C67f9A0a33dE3b0aeBFa7) |
| Groth16Verifier | [`0x1d6E057524aaCDE843BDC3F97257a11C2CdaA234`](https://sepolia.lineascan.build/address/0x1d6E057524aaCDE843BDC3F97257a11C2CdaA234) | Verified on [Lineascan](https://sepolia.lineascan.build/address/0x1d6E057524aaCDE843BDC3F97257a11C2CdaA234) |

- **Network**: Linea Sepolia (ZK-Rollup, chainId: 59141)
- **Deployer**: [`0x7F75bfAfeD5c96584774c7F2Bc33F3bF887BC739`](https://sepolia.lineascan.build/address/0x7F75bfAfeD5c96584774c7F2Bc33F3bF887BC739)

## How It Works

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  User Wallet     │───▶│  Identity         │───▶│  Reputation     │
│  (soulbound)     │    │  Registry         │    │  Oracle         │
└─────────────────┘    │  (Merkle root)    │    │  (attestations) │
                       └──────────────────┘    └────────┬────────┘
                                                        │
                       ┌──────────────────┐    ┌────────▼────────┐
                       │  dApp / Verifier  │◀───│  ZK Proof       │
                       │  (checks rep)     │    │  (Groth16)      │
                       └──────────────────┘    └─────────────────┘
```

**Flow:**
1. Register identity → soulbound Merkle root stored on-chain
2. Oracle scans on-chain history → issues reputation attestations
3. User generates ZK proof off-chain → proves "I have 800+ reputation"
4. dApp verifies proof on-chain → trusts reputation without seeing wallet

## Smart Contracts

### `zkIDRep.sol` — Main Entry Point
Orchestrates identity, reputation, and ZK verification in one call.

### `IdentityRegistry.sol` — Soulbound Identity
Stores Merkle roots bound to wallets. Non-transferable.

### `ReputationOracle.sol` — Attestation Engine
Issues scores (0-1000) across categories: DeFi, governance, NFTs, bridges.

### `Groth16Verifier.sol` — ZK Proof Verifier
Production-grade Groth16 pairing check on EVM (BN254 curve).

### `CrossChainReputation.sol` — CCIP Cross-Chain Sync
Sends reputation attestations across chains via Chainlink CCIP.

## ZK Circuits (circom)

### `reputation_proof.circom`
Proves: "I have reputation >= threshold in category X"
Without revealing: wallet address, exact score, or transaction history.

### `range_proof.circom`
Proves: "My score is between min and max" (tier-based: bronze/silver/gold/platinum).

### `membership_proof.circom`
Proves: "I am a member of tier X" with Merkle proof verification.

**Compile:**
```bash
circom circuits/reputation_proof.circom --r1cs --wasm --sym
snarkjs groth16 setup reputation_proof.r1cs pot12_final.ptau circuit_final.zkey
snarkjs zkey export solidityverifier circuit_final.zkey Groth16Verifier.sol
```

## Setup

```bash
git clone https://github.com/Souravjoy7/zkid-rep.git
cd zkid-rep
npm install
```

## Usage

### Compile
```bash
npx hardhat compile
```

### Run Local Demo
```bash
npx hardhat run scripts/demo.js
```

### Deploy to Linea Sepolia
```bash
cp .env.example .env
# Add your private key
npx hardhat run scripts/deploy.js --network linea_sepolia
```

## Project Structure

```
contracts/
  zkIDRep.sol              # Main entry point
  IdentityRegistry.sol     # Soulbound identity
  ReputationOracle.sol     # Attestation engine
  Groth16Verifier.sol      # ZK proof verifier
  CrossChainReputation.sol # CCIP cross-chain sync
circuits/
  reputation_proof.circom  # ZK reputation proof
  range_proof.circom       # Range proof
  membership_proof.circom  # Membership proof
scripts/
  demo.js                  # Local demo
  deploy.js                # Deploy to Linea Sepolia
```

## Why Linea (ZK-Rollup)?

- **Native ZK proofs**: ZK-rollup with EVM compatibility
- **Low gas**: ~100x cheaper than L1
- **Ethereum security**: Proofs verified on Ethereum mainnet
- **Consensys backed**: Built by the team behind MetaMask and Infura

## License

MIT
