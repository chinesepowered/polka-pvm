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
├── build/                       # Pre-built binaries (no toolchain needed)
│   ├── vrf.polkavm              # Rust VRF contract (1 KB)
│   └── PVMLottery.polkavm      # Solidity lottery contract (44 KB)
├── scripts/
│   └── deploy.sh                # One-click deployment script
├── frontend/
│   └── index.html               # Simple dApp (MetaMask + ethers.js)
├── package.json                 # Pins solc version for revive compat
├── DEPLOY.md                    # Step-by-step deploy & demo guide
└── README.md
```

## Quick Start

Pre-built contract binaries are included in `build/` — no Rust toolchain needed.

See **[DEPLOY.md](DEPLOY.md)** for the full step-by-step guide (with Windows instructions).

### TL;DR (macOS/Linux)

```bash
# 1. Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup

# 2. Set up wallet & fund it
cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>
# Get WND from https://faucet.polkadot.io/westend

# 3. Deploy (uses pre-built binaries)
./scripts/deploy.sh

# 4. Open the frontend
open frontend/index.html
```

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
