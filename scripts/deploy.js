import hre from "hardhat";

async function main() {
  const { ethers } = await hre.network.connect();

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying to Linea Sepolia...`);
  console.log(`Deployer: ${deployer.address}`);
  console.log(`Balance: ${ethers.formatEther(await ethers.provider.getBalance(deployer.address))} ETH`);

  // Deploy IdentityRegistry
  console.log("\nDeploying IdentityRegistry...");
  const IR = await ethers.getContractFactory("IdentityRegistry");
  const irDeploy = await IR.deploy();
  await irDeploy.waitForDeployment();
  const irAddr = await irDeploy.getAddress();
  console.log(`  IdentityRegistry: ${irAddr}`);

  // Deploy ReputationOracle
  console.log("\nDeploying ReputationOracle...");
  const RO = await ethers.getContractFactory("ReputationOracle");
  const roDeploy = await RO.deploy();
  await roDeploy.waitForDeployment();
  const roAddr = await roDeploy.getAddress();
  console.log(`  ReputationOracle: ${roAddr}`);

  // Deploy Groth16Verifier
  console.log("\nDeploying Groth16Verifier...");
  const GV = await ethers.getContractFactory("Groth16Verifier");
  const gvDeploy = await GV.deploy();
  await gvDeploy.waitForDeployment();
  const gvAddr = await gvDeploy.getAddress();
  console.log(`  Groth16Verifier: ${gvAddr}`);

  // Deploy zkIDRep
  console.log("\nDeploying zkIDRep...");
  const ZK = await ethers.getContractFactory("zkIDRep");
  const zkDeploy = await ZK.deploy(irAddr, roAddr, gvAddr);
  await zkDeploy.waitForDeployment();
  const zkidAddr = await zkDeploy.getAddress();
  console.log(`  zkIDRep: ${zkidAddr}`);

  // Read ABIs from artifacts
  const zkArtifact = await hre.artifacts.readArtifact("zkIDRep");
  const roArtifact = await hre.artifacts.readArtifact("ReputationOracle");

  // Create contract instances with full ABI
  const zkid = new ethers.Contract(zkidAddr, zkArtifact.abi, deployer);
  const ro = new ethers.Contract(roAddr, roArtifact.abi, deployer);

  // Run demo transactions
  console.log("\nRunning demo on-chain...");

  // Register identity
  const root = ethers.keccak256(ethers.toUtf8Bytes("deployer_reputation_data"));
  let tx = await zkid.registerIdentity(root);
  await tx.wait();
  console.log("  Identity registered");

  // Issue attestation
  const dataHash = ethers.keccak256(ethers.toUtf8Bytes("deployer_defi_history"));
  tx = await ro.attest(deployer.address, "defi", 900, dataHash);
  await tx.wait();
  console.log("  DeFi attestation issued (900/1000)");

  // ZK proof verification
  const proofHash = ethers.keccak256(ethers.toUtf8Bytes("zk_proof_deployer"));
  const publicInputsHash = ethers.keccak256(ethers.toUtf8Bytes("public_inputs_deployer"));
  tx = await zkid.requestVerification(publicInputsHash, proofHash);
  await tx.wait();
  console.log("  ZK proof verified");

  // Check reputation
  const [score, count] = await ro.getReputationScore(deployer.address);
  console.log(`\n  Reputation: ${score} (${count} attestations)`);
  console.log(`  Total proofs: ${await zkid.getTotalProofsVerified()}`);

  console.log(`\nVerify on Lineascan:`);
  console.log(`  IdentityRegistry: https://sepolia.lineascan.build/address/${irAddr}`);
  console.log(`  ReputationOracle: https://sepolia.lineascan.build/address/${roAddr}`);
  console.log(`  Groth16Verifier:  https://sepolia.lineascan.build/address/${gvAddr}`);
  console.log(`  zkIDRep:          https://sepolia.lineascan.build/address/${zkidAddr}`);

  const deployment = {
    network: "linea_sepolia",
    chainId: 59141,
    deployer: deployer.address,
    contracts: {
      IdentityRegistry: irAddr,
      ReputationOracle: roAddr,
      Groth16Verifier: gvAddr,
      zkIDRep: zkidAddr
    },
    timestamp: new Date().toISOString()
  };

  console.log("\nDeployment JSON:");
  console.log(JSON.stringify(deployment, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
