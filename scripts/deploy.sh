#!/bin/bash
set -e

# ==============================================================
# PVM Lottery — Deploy to Westend Asset Hub Testnet
# ==============================================================
#
# Prerequisites:
#   - Foundry (cast): https://getfoundry.sh
#   - polkatool: cargo install polkatool
#   - revive compiler: npm install (run from repo root)
#   - xxd (usually pre-installed)
#
# Setup:
#   cast wallet import dev-account --private-key <YOUR_PRIVATE_KEY>
#   Get testnet WND from: https://faucet.polkadot.io/westend
#
# ==============================================================

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

# Step 1: Build Rust VRF contract
echo "[1/4] Building Rust VRF contract..."
cd rust-vrf
make
cd ..
echo "  -> contract.polkavm built"
echo ""

# Step 2: Deploy Rust VRF contract
echo "[2/4] Deploying Rust VRF contract..."
RUST_VRF_ADDRESS=$(cast send \
    --account "$ACCOUNT" \
    --create "$(xxd -p -c 99999 rust-vrf/contract.polkavm)" \
    --json | jq -r .contractAddress)
echo "  -> Rust VRF deployed at: $RUST_VRF_ADDRESS"
echo ""

# Step 3: Compile Solidity Lottery contract
echo "[3/4] Compiling Lottery contract with revive (resolc)..."
npx @parity/revive --bin contracts/PVMLottery.sol
echo "  -> contracts_PVMLottery_sol_PVMLottery.polkavm built"
echo ""

# Step 4: Deploy Solidity Lottery contract
echo "[4/4] Deploying Lottery contract..."
CONSTRUCTOR_ARGS=$(cast abi-encode "constructor(address,uint256)" "$RUST_VRF_ADDRESS" "$TICKET_PRICE")
LOTTERY_ADDRESS=$(cast send \
    --account "$ACCOUNT" \
    --create "$(xxd -p -c 99999 contracts_PVMLottery_sol_PVMLottery.polkavm)${CONSTRUCTOR_ARGS:2}" \
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
