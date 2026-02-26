#!/bin/bash
set -e

# ==============================================================
# PVM Lottery — Deploy to Westend Asset Hub Testnet
# ==============================================================
#
# Prerequisites:
#   - Foundry (cast): https://getfoundry.sh
#   - xxd (usually pre-installed)
#
# Pre-built binaries are in build/. To rebuild from source you also need:
#   - Rust + polkatool: cargo install polkatool
#   - Revive compiler: npm install (run from repo root)
#
# Setup:
#   cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>
#   Get testnet WND from: https://faucet.polkadot.io/westend
#
# ==============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export ETH_RPC_URL="${ETH_RPC_URL:-https://westend-asset-hub-eth-rpc.polkadot.io}"
ACCOUNT="${ACCOUNT:-dev-account}"
TICKET_PRICE="${TICKET_PRICE:-10000000000000000}" # 0.01 WND in wei

echo "============================================"
echo "  PVM Lottery Deployment"
echo "  Network: $ETH_RPC_URL"
echo "  Account: $ACCOUNT"
echo "  Ticket Price: $TICKET_PRICE wei"
echo "============================================"
echo ""

# Locate contract binaries (use build/ pre-built, or build from source)
VRF_BIN="$REPO_DIR/build/vrf.polkavm"
LOTTERY_BIN="$REPO_DIR/build/PVMLottery.polkavm"

if [ ! -f "$VRF_BIN" ]; then
    echo "[build] Pre-built VRF not found, building from source..."
    cd "$REPO_DIR/rust-vrf" && make && cd "$REPO_DIR"
    VRF_BIN="$REPO_DIR/rust-vrf/contract.polkavm"
fi

if [ ! -f "$LOTTERY_BIN" ]; then
    echo "[build] Pre-built Lottery not found, building from source..."
    cd "$REPO_DIR" && npx @parity/revive --bin contracts/PVMLottery.sol
    LOTTERY_BIN="$REPO_DIR/contracts_PVMLottery_sol_PVMLottery.polkavm"
fi

echo "[1/2] Deploying Rust VRF contract..."
echo "  Binary: $VRF_BIN ($(wc -c < "$VRF_BIN") bytes)"
RUST_VRF_ADDRESS=$(cast send \
    --account "$ACCOUNT" \
    --create "$(xxd -p -c 99999 "$VRF_BIN")" \
    --json | jq -r .contractAddress)
echo "  -> Rust VRF deployed at: $RUST_VRF_ADDRESS"
echo ""

echo "[2/2] Deploying Lottery contract..."
echo "  Binary: $LOTTERY_BIN ($(wc -c < "$LOTTERY_BIN") bytes)"
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,uint256)" "$RUST_VRF_ADDRESS" "$TICKET_PRICE")
LOTTERY_ADDRESS=$(cast send \
    --account "$ACCOUNT" \
    --create "$(xxd -p -c 99999 "$LOTTERY_BIN")${CONSTRUCTOR_ARGS:2}" \
    --json | jq -r .contractAddress)
echo "  -> Lottery deployed at: $LOTTERY_ADDRESS"
echo ""

# Done!
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
echo ""
echo "  Rust VRF:  $RUST_VRF_ADDRESS"
echo "  Lottery:   $LOTTERY_ADDRESS"
echo ""
echo "  Test it:"
echo "    # Buy a ticket (0.01 WND)"
echo "    cast send --account $ACCOUNT --value $TICKET_PRICE $LOTTERY_ADDRESS \"buyTicket()\""
echo ""
echo "    # Check current round"
echo "    cast call $LOTTERY_ADDRESS \"getCurrentRound() returns (uint256, uint256, uint256, bool)\""
echo ""
echo "    # Draw winner (owner only)"
echo "    cast send --account $ACCOUNT $LOTTERY_ADDRESS \"drawWinner()\""
echo ""
echo "    # Compare gas: Rust VRF vs Solidity"
echo "    cast estimate $LOTTERY_ADDRESS \"generateRandomRust(uint256)\" 42"
echo "    cast estimate $LOTTERY_ADDRESS \"generateRandomSolidity(uint256)\" 42"
echo ""
echo "  Update frontend/index.html with these addresses!"
