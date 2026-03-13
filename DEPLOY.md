# Deploy & Demo Guide

Step-by-step instructions to deploy PVM Lottery and run the demo. Works on **Windows, macOS, and Linux**.

Pre-built contract binaries are included in `build/` so you do **not** need Rust, cargo, or polkatool.

---

## Prerequisites

1. **Node.js** (v18+) — you probably already have it
2. **A private key** with testnet WND tokens
3. **Testnet WND tokens** — [faucet.polkadot.io/westend](https://faucet.polkadot.io/westend)

### Install dependencies

```bash
npm install
```

This installs `ethers.js` (for deployment) and the Revive compiler (only needed if rebuilding Solidity).

---

## Step 1: Set Up Your Wallet

You need a private key with testnet funds. If you don't have one:

```bash
# Generate a new wallet (using Node.js)
node -e "const w = require('ethers').Wallet.createRandom(); console.log('Address:', w.address); console.log('Private key:', w.privateKey)"
```

### Fund it with testnet WND

1. Go to [faucet.polkadot.io/westend](https://faucet.polkadot.io/westend)
2. Paste your `0x...` address
3. Wait ~30 seconds for tokens to arrive

### Save your key

Create a `.env` file (already in `.gitignore`):

```bash
echo "PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE" > .env
```

---

## Step 2: Deploy

### One command

```bash
npm run deploy
```

Or without `.env`:

```bash
PRIVATE_KEY=0x... npm run deploy
```

This will:
1. Deploy the Rust VRF contract (`build/vrf.polkavm`)
2. Deploy the Solidity Lottery contract (`build/PVMLottery.polkavm`)
3. Run a gas comparison smoke test
4. Save addresses to `.deploy-addresses.json`

### Example output

```
============================================
  PVM Lottery Deployment (Node.js)
  Network:  https://westend-asset-hub-eth-rpc.polkadot.io
  Deployer: 0x1234...
  Ticket:   10000000000000000 wei (0.01 WND)
============================================

[1/2] Deploying Rust VRF contract...
  -> Rust VRF deployed at: 0xABC...

[2/2] Deploying Lottery contract...
  -> Lottery deployed at: 0xDEF...

[test] Running gas comparison...
  Rust VRF gas:     12345
  Solidity gas:     67890
  Rust saves:       81.8% gas
```

---

## Step 3: Test via CLI

After deploying, you can interact using Node.js:

```bash
node -e "
const { ethers } = require('ethers');
const provider = new ethers.JsonRpcProvider('https://westend-asset-hub-eth-rpc.polkadot.io');
const addrs = require('./.deploy-addresses.json');
const abi = ['function getCurrentRound() view returns (uint256, uint256, uint256, bool)'];
const lottery = new ethers.Contract(addrs.lotteryAddress, abi, provider);
lottery.getCurrentRound().then(r => console.log('Round:', r.toString()));
"
```

Or if you have Foundry installed:

```bash
export ETH_RPC_URL="https://westend-asset-hub-eth-rpc.polkadot.io"
LOTTERY=<YOUR_LOTTERY_ADDRESS>

# Buy a ticket
cast send --account dev-account --value 10000000000000000 $LOTTERY "buyTicket()"

# Check current round
cast call $LOTTERY "getCurrentRound() returns (uint256, uint256, uint256, bool)"

# Draw the winner (owner only)
cast send --account dev-account $LOTTERY "drawWinner()"

# Gas comparison
cast estimate $LOTTERY "generateRandomRust(uint256)" 42
cast estimate $LOTTERY "generateRandomSolidity(uint256)" 42
```

---

## Step 4: Frontend Demo

1. Open `frontend/index.html` in any browser
2. Click **Connect MetaMask**
   - MetaMask will prompt you to add the Westend Asset Hub network (chain ID 420420421)
   - Accept and switch to it
3. Paste your deployed addresses into the address fields:
   - **Lottery Contract**: your Lottery address
   - **Rust VRF Contract**: your VRF address
4. Click **Load Contracts**

### Demo walkthrough

| Step | Action | What to show |
|------|--------|-------------|
| 1 | Click **Buy Ticket** | TX submits, player count increases |
| 2 | Buy a few more tickets (from different accounts if possible) | Prize pool grows |
| 3 | Click **Draw Winner** (must be the owner account) | Rust VRF is called on-chain, winner selected |
| 4 | Click **Run Gas Comparison** | Shows Rust vs Solidity gas side-by-side |

### What to highlight for judges

- The **Gas Comparison** panel is the key demo: it proves Rust/RISC-V is more efficient than Solidity for compute-heavy operations
- The draw uses a **cross-contract call** from Solidity into Rust — seamless PolkaVM interop
- The Rust VRF contract is only **1 KB** compiled (vs 44 KB for the Solidity contract)
- Check the Event Log at the bottom for real-time transaction details

---

## Alternative: Deploy with Foundry

If you prefer Foundry (`cast`) over Node.js:

### Install Foundry

```bash
# macOS / Linux
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Windows PowerShell
irm https://foundry.paradigm.xyz | iex
foundryup
```

### Deploy

```bash
cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>
./scripts/deploy.sh
```

---

## Rebuilding from Source (optional)

Only needed if you want to modify the contracts.

### Rust VRF contract

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-src
cargo install polkatool

cd rust-vrf && make
# Output: rust-vrf/contract.polkavm
```

### Solidity Lottery contract

```bash
npm install
npm run build:sol
# Output: contracts_PVMLottery_sol_PVMLottery.polkavm
```

---

## Troubleshooting

**"PRIVATE_KEY environment variable is required"**
Create a `.env` file: `echo "PRIVATE_KEY=0x..." > .env`

**"insufficient funds" / balance is 0**
Get WND from the [faucet](https://faucet.polkadot.io/westend). Each request gives enough for many deployments.

**"Only owner" when drawing winner**
The `drawWinner()` function can only be called by the account that deployed the Lottery contract.

**MetaMask doesn't connect**
Make sure you're on the Westend Asset Hub network (chain ID 420420421). The frontend will try to add it automatically.
