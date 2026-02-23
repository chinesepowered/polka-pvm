# PVM Lottery — Rust-Powered Random Number Generation on Polkadot

**Polkadot Solidity Hackathon 2026 — PVM Track (PVM-experiments)**

A lottery dApp demonstrating cross-language smart contract interop on PolkaVM. A Rust contract compiled to RISC-V handles random number generation, called seamlessly from a Solidity lottery contract — showcasing the unique power of Polkadot's dual-VM architecture.

## Architecture

```
┌──────────────────────────┐         call         ┌─────────────────────────┐
│  PVMLottery.sol          │ ────────────────────> │  Rust VRF (contract.    │
│                          │                       │        polkavm)         │
│  - buyTicket()           │                       │                         │
│  - drawWinner()          │  <──────────────────  │  - generateRandom()     │
│  - generateRandomRust()  │      uint256 result   │    64-round mixing      │
│  - generateRandomSol()   │                       │    xorshift128+ lanes   │
└──────────────────────────┘                       └─────────────────────────┘
         │                                                    │
         │  Solidity (resolc -> PVM)                          │  Rust (cargo -> polkatool -> PVM)
         │                                                    │
         └─────────────── Both run on PolkaVM (RISC-V) ──────┘
```

**Why Rust for randomness?** Bitwise operations, multi-round mixing, and 64-bit lane processing are significantly more efficient in Rust/RISC-V than in Solidity. The demo includes a gas comparison feature to prove it.

## Project Structure

```
polka-pvm/
├── rust-vrf/                     # Rust PVM contract
│   ├── .cargo/config.toml        # RISC-V target config
│   ├── Cargo.toml                # Dependencies (pallet-revive-uapi)
│   ├── Makefile                  # Build + link to .polkavm
│   ├── riscv64emac-unknown-none-polkavm.json  # Custom target
│   └── src/main.rs               # VRF implementation
├── contracts/
│   └── PVMLottery.sol            # Solidity lottery contract
├── scripts/
│   └── deploy.sh                 # One-click deployment script
├── frontend/
│   └── index.html                # Simple dApp (MetaMask + ethers.js)
└── README.md
```

## Quick Start

### Prerequisites

- **Rust** (nightly): `rustup install nightly`
- **polkatool**: `cargo install polkatool`
- **Foundry** (cast): [getfoundry.sh](https://getfoundry.sh)
- **Revive compiler**: `npm install -g @parity/revive`
- **Testnet WND tokens**: [Westend Faucet](https://faucet.polkadot.io/westend)

### 1. Set Up Wallet

```bash
# Import your dev account into Foundry
cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>

# Verify balance
export ETH_RPC_URL="https://westend-asset-hub-eth-rpc.polkadot.io"
cast balance <YOUR_ADDRESS>
```

### 2. Build the Rust VRF Contract

```bash
cd rust-vrf
make
# -> produces contract.polkavm
```

### 3. Deploy to Westend Asset Hub

```bash
# Deploy Rust VRF
RUST_VRF=$(cast send --account dev-account --create \
  "$(xxd -p -c 99999 rust-vrf/contract.polkavm)" \
  --json | jq -r .contractAddress)

echo "Rust VRF: $RUST_VRF"

# Compile and deploy Solidity Lottery
npx @parity/revive@latest --bin contracts/PVMLottery.sol

TICKET_PRICE="10000000000000000"  # 0.01 WND
ARGS=$(cast abi-encode "constructor(address,uint256)" $RUST_VRF $TICKET_PRICE)

LOTTERY=$(cast send --account dev-account --create \
  "$(xxd -p -c 99999 PVMLottery_sol_PVMLottery.polkavm)${ARGS:2}" \
  --json | jq -r .contractAddress)

echo "Lottery: $LOTTERY"
```

Or use the all-in-one script:
```bash
./scripts/deploy.sh
```

### 4. Interact

```bash
# Buy a ticket
cast send --account dev-account --value 10000000000000000 $LOTTERY "buyTicket()"

# Check current round
cast call $LOTTERY "getCurrentRound() returns (uint256, uint256, uint256, bool)"

# Draw winner (owner only)
cast send --account dev-account $LOTTERY "drawWinner()"

# Gas comparison: Rust vs Solidity
cast estimate $LOTTERY "generateRandomRust(uint256)" 42
cast estimate $LOTTERY "generateRandomSolidity(uint256)" 42
```

### 5. Frontend Demo

1. Open `frontend/index.html` in a browser
2. Connect MetaMask (switch to Westend Asset Hub network)
3. Enter the deployed contract addresses
4. Buy tickets, draw winners, and compare gas costs

## How It Works

### Rust VRF Contract (`rust-vrf/src/main.rs`)

The Rust contract implements a 64-round non-linear mixing function:

1. **Byte-level mixing**: Each byte is combined with offset neighbors using multiply-XOR-shift operations
2. **Lane-level mixing**: The 32-byte state is split into four 64-bit lanes and mixed using xorshift128+ inspired operations
3. **Cross-lane diffusion**: Lanes feed into each other for full avalanche effect

This is compiled to RISC-V via `polkatool` and runs natively on PolkaVM.

### Solidity Lottery Contract (`contracts/PVMLottery.sol`)

1. Users buy tickets by sending WND
2. Owner triggers a draw, which:
   - Combines on-chain entropy (timestamp, block number, prevrandao, player count)
   - Calls the **Rust VRF** for additional mixing via cross-contract call
   - Selects winner using `random % playerCount`
   - Transfers the prize pool to the winner

### Cross-VM Interop

The Solidity contract calls the Rust contract using a standard `interface` — the contracts don't know or care that they're running on different VMs. PolkaVM handles the seamless interop.

## Hackathon Track

**Track 2: PVM Smart Contracts — PVM-experiments**

This project demonstrates:
- Calling a Rust library from Solidity (the core PVM-experiments category)
- Real performance benefits of Rust on RISC-V vs. Solidity
- Practical use case (on-chain randomness for gaming/DeFi)
- Cross-VM interoperability on Polkadot Hub

## Network Details

| Property | Value |
|----------|-------|
| Network | Westend Asset Hub (Testnet) |
| RPC | `https://westend-asset-hub-eth-rpc.polkadot.io` |
| Chain ID | `420420421` |
| Currency | WND |
| Faucet | [faucet.polkadot.io/westend](https://faucet.polkadot.io/westend) |

## License

MIT
