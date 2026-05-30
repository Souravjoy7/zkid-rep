import hre from "hardhat";

async function main() {
  const { ethers } = await hre.network.connect();

  console.log("═".repeat(60));
  console.log("  zkID-Rep — ZK-Identity Reputation Protocol Demo");
  console.log("  Portable, Private, Cross-Chain Reputation");
  console.log("═".repeat(60));

  const [deployer, user1, user2] = await ethers.getSigners();
  console.log(`\nDeployer: ${deployer.address}`);
  console.log(`User1:    ${user1.address}`);
  console.log(`User2:    ${user2.address}`);

  // ═══ Deploy All Contracts ═══
  console.log("\n" + "━".repeat(60));
  console.log("  DEPLOYING CONTRACTS");
  console.log("━".repeat(60));

  const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
  const identityRegistry = await IdentityRegistry.deploy();
  await identityRegistry.waitForDeployment();
  console.log(`  IdentityRegistry: ${await identityRegistry.getAddress()}`);

  const ReputationOracle = await ethers.getContractFactory("ReputationOracle");
  const reputationOracle = await ReputationOracle.deploy();
  await reputationOracle.waitForDeployment();
  console.log(`  ReputationOracle: ${await reputationOracle.getAddress()}`);

  const Groth16Verifier = await ethers.getContractFactory("Groth16Verifier");
  const verifier = await Groth16Verifier.deploy();
  await verifier.waitForDeployment();
  console.log(`  Groth16Verifier:  ${await verifier.getAddress()}`);

  const zkIDRep = await ethers.getContractFactory("zkIDRep");
  const zkid = await zkIDRep.deploy(
    await identityRegistry.getAddress(),
    await reputationOracle.getAddress(),
    await verifier.getAddress()
  );
  await zkid.waitForDeployment();
  console.log(`  zkIDRep:          ${await zkid.getAddress()}`);

  // ═══ 1. Register Identities ═══
  console.log("\n" + "━".repeat(60));
  console.log("  1. REGISTER IDENTITIES");
  console.log("━".repeat(60));

  // Generate fake Merkle roots (in production, these come from Merkle trees)
  const root1 = ethers.keccak256(ethers.toUtf8Bytes("user1_reputation_data"));
  const root2 = ethers.keccak256(ethers.toUtf8Bytes("user2_reputation_data"));

  let tx = await zkid.connect(user1).registerIdentity(root1);
  await tx.wait();
  console.log(`  User1 registered identity: ${root1.slice(0, 18)}...`);

  tx = await zkid.connect(user2).registerIdentity(root2);
  await tx.wait();
  console.log(`  User2 registered identity: ${root2.slice(0, 18)}...`);

  // ═══ 2. Issue Reputation Attestations ═══
  console.log("\n" + "━".repeat(60));
  console.log("  2. ISSUE REPUTATION ATTESTATIONS");
  console.log("━".repeat(60));

  // User1: DeFi expert
  const dataHash1 = ethers.keccak256(ethers.toUtf8Bytes("user1_defi_history"));
  tx = await reputationOracle.attest(user1.address, "defi", 850, dataHash1);
  await tx.wait();
  console.log(`  User1: DeFi score 850/1000`);

  const dataHash2 = ethers.keccak256(ethers.toUtf8Bytes("user1_governance_history"));
  tx = await reputationOracle.attest(user1.address, "governance", 720, dataHash2);
  await tx.wait();
  console.log(`  User1: Governance score 720/1000`);

  // User2: NFT collector
  const dataHash3 = ethers.keccak256(ethers.toUtf8Bytes("user2_nft_history"));
  tx = await reputationOracle.attest(user2.address, "nft", 600, dataHash3);
  await tx.wait();
  console.log(`  User2: NFT score 600/1000`);

  // ═══ 3. Check Reputation Scores ═══
  console.log("\n" + "━".repeat(60));
  console.log("  3. CHECK REPUTATION SCORES");
  console.log("━".repeat(60));

  const [score1, count1] = await reputationOracle.getReputationScore(user1.address);
  console.log(`  User1: Total ${score1} (${count1} attestations)`);

  const [score2, count2] = await reputationOracle.getReputationScore(user2.address);
  console.log(`  User2: Total ${score2} (${count2} attestations)`);

  // ═══ 4. ZK Proof Verification (Simplified) ═══
  console.log("\n" + "━".repeat(60));
  console.log("  4. ZK PROOF VERIFICATION");
  console.log("━".repeat(60));

  // Simulate ZK proof generation (in production, use snarkjs)
  const proofHash = ethers.keccak256(ethers.toUtf8Bytes("zk_proof_user1_deFi"));
  const publicInputsHash = ethers.keccak256(ethers.toUtf8Bytes("public_inputs_deFi_800"));

  tx = await zkid.connect(user1).requestVerification(publicInputsHash, proofHash);
  await tx.wait();

  // Get the request ID (compute from tx events or use a deterministic approach)
  const block = await ethers.provider.getBlock("latest");
  const requestId = ethers.keccak256(
    ethers.solidityPacked(
      ["address", "bytes32", "bytes32", "uint256"],
      [user1.address, publicInputsHash, proofHash, block.timestamp]
    )
  );

  const isVerified = await zkid.isProofVerified(requestId);
  console.log(`  User1 ZK proof verified: ${isVerified}`);
  console.log(`  Request ID: ${requestId.slice(0, 18)}...`);

  // ═══ 5. Minimum Reputation Check ═══
  console.log("\n" + "━".repeat(60));
  console.log("  5. MINIMUM REPUTATION CHECK");
  console.log("━".repeat(60));

  const hasMin1 = await zkid.hasMinimumReputation(user1.address, 1000);
  console.log(`  User1 has 1000+ reputation: ${hasMin1}`);

  const hasMin2 = await zkid.hasMinimumReputation(user1.address, 500);
  console.log(`  User1 has 500+ reputation: ${hasMin2}`);

  const hasMin3 = await zkid.hasMinimumReputation(user2.address, 500);
  console.log(`  User2 has 500+ reputation: ${hasMin3}`);

  // ═══ 6. User Profiles ═══
  console.log("\n" + "━".repeat(60));
  console.log("  6. USER PROFILES");
  console.log("━".repeat(60));

  const [totalScore1, attestCount1, exists1] = await zkid.getUserReputation(user1.address);
  console.log(`  User1: Score ${totalScore1}, ${attestCount1} attestations, identity exists: ${exists1}`);

  const [totalScore2, attestCount2, exists2] = await zkid.getUserReputation(user2.address);
  console.log(`  User2: Score ${totalScore2}, ${attestCount2} attestations, identity exists: ${exists2}`);

  // ═══ Summary ═══
  console.log("\n" + "═".repeat(60));
  console.log("  SUMMARY — zkID-Rep Protocol");
  console.log("═".repeat(60));
  console.log(`  Contracts deployed:     4`);
  console.log(`  Identities registered:  2`);
  console.log(`  Attestations issued:    3`);
  console.log(`  ZK proofs verified:     ${await zkid.getTotalProofsVerified()}`);
  console.log(`  Total users:            ${await identityRegistry.getUserCount()}`);
  console.log("\n  All reputation data stored on-chain — verifiable by anyone");
  console.log("═".repeat(60));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
