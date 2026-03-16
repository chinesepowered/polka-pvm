#!/usr/bin/env node
// ==============================================================
// PVM Lottery — Deploy to Polkadot Hub Testnet (Node.js / ethers.js)
// ==============================================================
//
// Usage:
//   PRIVATE_KEY=0x... pnpm run deploy
//
// Or with env file:
//   echo 'PRIVATE_KEY=0x...' > .env   (already in .gitignore)
//   pnpm run deploy
//
// Options (env vars):
//   PRIVATE_KEY    - Required. Your deployer private key (0x-prefixed)
//   RPC_URL        - RPC endpoint (default: Polkadot Hub Testnet)
//   TICKET_PRICE   - In wei (default: 10000000000000000 = 0.01 WND)
// ==============================================================

const { ethers } = require("ethers");
const fs = require("fs");
const path = require("path");

// --- Config ---
const RPC_URL =
  process.env.RPC_URL ||
  "https://services.polkadothub-rpc.com/testnet";
const TICKET_PRICE = process.env.TICKET_PRICE || "10000000000000000"; // 0.01 WND

// --- Load .env if present (simple, no dotenv dependency) ---
function loadEnv() {
  const envPath = path.join(__dirname, "..", ".env");
  if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const eq = trimmed.indexOf("=");
      if (eq === -1) continue;
      const key = trimmed.slice(0, eq).trim();
      const val = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, "");
      if (!process.env[key]) process.env[key] = val;
    }
  }
}

// --- Lottery ABI (just what we need for testing after deploy) ---
const LOTTERY_ABI = [
  "constructor(address _rustVrf, uint256 _ticketPrice)",
  "function buyTicket() external payable",
  "function drawWinner() external",
  "function getCurrentRound() external view returns (uint256, uint256, uint256, bool)",
  "function generateRandomRust(uint256 seed) external view returns (uint256)",
  "function generateRandomSolidity(uint256 seed) external pure returns (uint256)",
  "event TicketPurchased(uint256 indexed roundId, address indexed player, uint256 ticketIndex)",
  "event WinnerDrawn(uint256 indexed roundId, address indexed winner, uint256 prize, uint256 randomValue)",
];

async function main() {
  loadEnv();

  const privateKey = process.env.PRIVATE_KEY;
  if (!privateKey) {
    console.error("Error: PRIVATE_KEY environment variable is required.");
    console.error("");
    console.error("Usage:");
    console.error("  PRIVATE_KEY=0x... pnpm run deploy");
    console.error("");
    console.error("Or create a .env file:");
    console.error('  echo "PRIVATE_KEY=0x..." > .env');
    process.exit(1);
  }

  // Connect
  const provider = new ethers.JsonRpcProvider(RPC_URL);
  const network = await provider.getNetwork();
  const chainId = Number(network.chainId);
  console.log(`  Chain ID: ${chainId}`);
  const wallet = new ethers.Wallet(privateKey, provider);

  console.log("============================================");
  console.log("  PVM Lottery Deployment (Node.js)");
  console.log(`  Network:  ${RPC_URL}`);
  console.log(`  Deployer: ${wallet.address}`);
  console.log(`  Ticket:   ${TICKET_PRICE} wei (${ethers.formatEther(TICKET_PRICE)} WND)`);
  console.log("============================================\n");

  // Check balance
  const balance = await provider.getBalance(wallet.address);
  console.log(`  Balance: ${ethers.formatEther(balance)} WND`);
  if (balance === 0n) {
    console.error("  No funds! Get WND from https://faucet.polkadot.io/westend");
    process.exit(1);
  }

  console.log("");

  // Locate binaries
  const repoDir = path.join(__dirname, "..");
  const vrfBin = path.join(repoDir, "build", "vrf.polkavm");
  const lotteryBin = path.join(repoDir, "build", "PVMLottery.polkavm");

  if (!fs.existsSync(vrfBin)) {
    console.error(`  VRF binary not found: ${vrfBin}`);
    console.error("  Run: cd rust-vrf && make");
    process.exit(1);
  }
  if (!fs.existsSync(lotteryBin)) {
    console.error(`  Lottery binary not found: ${lotteryBin}`);
    console.error("  Run: pnpm run build:sol");
    process.exit(1);
  }

  // --- Deploy VRF ---
  console.log("[1/2] Deploying Rust VRF contract...");
  const vrfBytecode = "0x" + fs.readFileSync(vrfBin).toString("hex");
  console.log(`  Binary: ${vrfBin} (${fs.statSync(vrfBin).size} bytes)`);

  const vrfTx = await wallet.sendTransaction({
    data: vrfBytecode,
    gasLimit: 50000000,
  });
  console.log(`  TX: ${vrfTx.hash}`);
  const vrfReceipt = await vrfTx.wait();
  const vrfAddress = vrfReceipt.contractAddress;
  console.log(`  -> Rust VRF deployed at: ${vrfAddress}\n`);

  // --- Deploy Lottery ---
  console.log("[2/2] Deploying Lottery contract...");
  const lotteryBytecode = fs.readFileSync(lotteryBin).toString("hex");
  console.log(`  Binary: ${lotteryBin} (${fs.statSync(lotteryBin).size} bytes)`);

  // Encode constructor args: (address, uint256)
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  const constructorArgs = abiCoder
    .encode(["address", "uint256"], [vrfAddress, TICKET_PRICE])
    .slice(2); // remove 0x prefix

  const lotteryTx = await wallet.sendTransaction({
    data: "0x" + lotteryBytecode + constructorArgs,
    gasLimit: 50000000,
  });
  console.log(`  TX: ${lotteryTx.hash}`);
  const lotteryReceipt = await lotteryTx.wait();
  const lotteryAddress = lotteryReceipt.contractAddress;
  console.log(`  -> Lottery deployed at: ${lotteryAddress}\n`);

  // --- Summary ---
  console.log("============================================");
  console.log("  Deployment Complete!");
  console.log("============================================\n");
  console.log(`  Rust VRF:  ${vrfAddress}`);
  console.log(`  Lottery:   ${lotteryAddress}\n`);

  // --- Quick smoke test ---
  console.log("[test] Running gas comparison...");
  const lottery = new ethers.Contract(lotteryAddress, LOTTERY_ABI, wallet);

  try {
    const gasRust = await lottery.generateRandomRust.estimateGas(42);
    const gasSolidity = await lottery.generateRandomSolidity.estimateGas(42);
    console.log(`  Rust VRF gas:     ${gasRust.toString()}`);
    console.log(`  Solidity gas:     ${gasSolidity.toString()}`);
    const saving = Number(gasSolidity - gasRust) / Number(gasSolidity) * 100;
    console.log(`  Rust saves:       ${saving.toFixed(1)}% gas\n`);
  } catch (e) {
    console.log(`  Gas estimate skipped: ${e.message}\n`);
  }

  // --- Next steps ---
  console.log("  Next steps:");
  console.log(`    # Buy a ticket (Node.js)`);
  console.log(`    # Update frontend/index.html with your addresses`);
  console.log(`    # Open frontend/index.html in a browser\n`);

  // Write addresses to a file for convenience
  const addressFile = path.join(repoDir, ".deploy-addresses.json");
  fs.writeFileSync(
    addressFile,
    JSON.stringify(
      {
        network: RPC_URL,
        vrfAddress,
        lotteryAddress,
        deployer: wallet.address,
        ticketPrice: TICKET_PRICE,
        deployedAt: new Date().toISOString(),
      },
      null,
      2
    ) + "\n"
  );
  console.log(`  Addresses saved to: ${addressFile}`);
}

main().catch((err) => {
  console.error("Deploy failed:", err.message || err);
  process.exit(1);
});
