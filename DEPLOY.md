# Deploy & Demo Guide

Step-by-step instructions to deploy PVM Lottery and run the demo. Works on **Windows, macOS, and Linux**.

Pre-built contract binaries are included in `build/` so you do **not** need Rust, cargo, or polkatool.

---

## Prerequisites

You only need two things:

1. **Foundry** (for `cast` CLI) - [getfoundry.sh](https://getfoundry.sh)
2. **Testnet WND tokens** - [faucet.polkadot.io/westend](https://faucet.polkadot.io/westend)

### Install Foundry

**macOS / Linux:**
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

**Windows (PowerShell):**
```powershell
# Option A: Use the installer
irm https://foundry.paradigm.xyz | iex
foundryup

# Option B: Use WSL (recommended — the deploy script is bash)
wsl --install
# Then inside WSL, follow the macOS/Linux instructions
```

> **Windows note:** The `deploy.sh` script is a bash script. On Windows, either use **WSL** (recommended), **Git Bash**, or deploy manually using the commands in the "Manual Deploy" section below.

### Verify Foundry is installed

```bash
cast --version
# Should print: cast 0.x.x
```

---

## Step 1: Set Up Your Wallet

Generate or import a private key into Foundry's keystore:

```bash
# Import an existing private key
cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>
```

Or generate a fresh one:
```bash
cast wallet new
# Save the private key and address it outputs
cast wallet import dev-account --private-key <PRIVATE_KEY_FROM_ABOVE>
```

### Fund it with testnet WND

1. Go to [faucet.polkadot.io/westend](https://faucet.polkadot.io/westend)
2. Paste your address (the `0x...` Ethereum-style address)
3. Wait for the tokens to arrive (~30 seconds)

Verify:
```bash
export ETH_RPC_URL="https://westend-asset-hub-eth-rpc.polkadot.io"
cast balance <YOUR_ADDRESS>
```

---

## Step 2: Deploy

### Option A: One-command deploy (macOS/Linux/WSL)

```bash
./scripts/deploy.sh
```

This will:
1. Deploy the Rust VRF contract (from `build/vrf.polkavm`)
2. Deploy the Solidity Lottery contract (from `build/PVMLottery.polkavm`)
3. Print both contract addresses

### Option B: Manual deploy (any OS, including Windows PowerShell)

```bash
# Set the RPC endpoint
export ETH_RPC_URL="https://westend-asset-hub-eth-rpc.polkadot.io"

# 1. Deploy the Rust VRF contract
cast send --account dev-account --create "$(xxd -p -c 99999 build/vrf.polkavm)" --json
# Note the "contractAddress" from the output. Example: 0xABC123...
```

```bash
# 2. Deploy the Solidity Lottery contract
# Replace <VRF_ADDRESS> with the address from step 1
TICKET_PRICE="10000000000000000"
ARGS=$(cast abi-encode "constructor(address,uint256)" <VRF_ADDRESS> $TICKET_PRICE)
cast send --account dev-account --create "$(xxd -p -c 99999 build/PVMLottery.polkavm)${ARGS:2}" --json
# Note the "contractAddress". Example: 0xDEF456...
```

**Windows PowerShell (no xxd):**

If you don't have `xxd`, use Python instead:
```powershell
# Convert binary to hex
$vrfHex = (python -c "print(open('build/vrf.polkavm','rb').read().hex())")
cast send --account dev-account --create $vrfHex --json

# Then for the Lottery:
$lotteryHex = (python -c "print(open('build/PVMLottery.polkavm','rb').read().hex())")
$args = cast abi-encode "constructor(address,uint256)" <VRF_ADDRESS> 10000000000000000
$argsNoPrefix = $args.Substring(2)
cast send --account dev-account --create "$lotteryHex$argsNoPrefix" --json
```

### Save your addresses

Write down both addresses. You'll need them for the frontend:
```
Rust VRF:  0x________________
Lottery:   0x________________
```

---

## Step 3: Test via CLI

```bash
export ETH_RPC_URL="https://westend-asset-hub-eth-rpc.polkadot.io"
LOTTERY=<YOUR_LOTTERY_ADDRESS>

# Buy a ticket (costs 0.01 WND)
cast send --account dev-account --value 10000000000000000 $LOTTERY "buyTicket()"

# Check current round info
cast call $LOTTERY "getCurrentRound() returns (uint256, uint256, uint256, bool)"

# Draw the winner (owner only)
cast send --account dev-account $LOTTERY "drawWinner()"

# Gas comparison: this is the money shot for the demo!
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

## Rebuilding from Source (optional)

Only needed if you want to modify the contracts.

### Rust VRF contract

```bash
# Install Rust + polkatool
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-src
cargo install polkatool

# Build
cd rust-vrf && make
# Output: rust-vrf/contract.polkavm
```

### Solidity Lottery contract

```bash
# Install Node.js dependencies (pins compatible solc version)
npm install

# Build
npm run build:sol
# Output: contracts_PVMLottery_sol_PVMLottery.polkavm
```

---

## Troubleshooting

**"cast: command not found"**
Run `foundryup` to install Foundry, then restart your terminal.

**"insufficient funds"**
Get WND from the [faucet](https://faucet.polkadot.io/westend). Each request gives enough for many deployments.

**"Only owner" when drawing winner**
The `drawWinner()` function can only be called by the account that deployed the Lottery contract.

**MetaMask doesn't connect**
Make sure you're on the Westend Asset Hub network (chain ID 420420421). The frontend will try to add it automatically.

**xxd not available (Windows)**
Use the Python one-liner shown in the manual deploy section, or install xxd via `choco install vim` (xxd comes with vim).
