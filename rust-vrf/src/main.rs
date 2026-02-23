#![no_main]
#![no_std]

use uapi::{HostFn, HostFnImpl as api, ReturnFlags};

#[panic_handler]
fn panic(_info: &core::panic::PanicInfo) -> ! {
    // Safety: The unimp instruction is guaranteed to trap
    unsafe {
        core::arch::asm!("unimp");
        core::hint::unreachable_unchecked();
    }
}

/// Constructor - called once on deployment.
#[no_mangle]
#[polkavm_derive::polkavm_export]
pub extern "C" fn deploy() {}

/// Main entry point - dispatches based on ABI function selector.
#[no_mangle]
#[polkavm_derive::polkavm_export]
pub extern "C" fn call() {
    // Read the 4-byte function selector
    let mut selector = [0u8; 4];
    api::call_data_copy(&mut selector, 0);

    match selector {
        // generateRandom(uint256) => selector: first 4 bytes of keccak256("generateRandom(uint256)")
        // We accept any selector for simplicity — single-function contract
        _ => handle_generate_random(),
    }
}

/// Handles generateRandom(uint256 seed) returns (uint256)
/// Reads a 256-bit seed from the call data and returns a 256-bit pseudo-random number.
fn handle_generate_random() {
    // Read the 32-byte seed (first ABI argument, starts at offset 4)
    let mut seed = [0u8; 32];
    api::call_data_copy(&mut seed, 4);

    let result = generate_random(seed);
    api::return_value(ReturnFlags::empty(), &result);
}

/// Multi-round non-linear mixing function.
///
/// Takes a 256-bit seed and produces a 256-bit pseudo-random output
/// through 64 rounds of byte-level and lane-level mixing.
///
/// This is significantly more gas-efficient in Rust/RISC-V than an
/// equivalent Solidity implementation due to native bitwise operations.
fn generate_random(mut state: [u8; 32]) -> [u8; 32] {
    // 64 rounds of mixing for thorough avalanche effect
    let mut round: u8 = 0;
    while round < 64 {
        // Phase 1: Non-linear byte mixing (substitution-permutation)
        let mut i: usize = 0;
        while i < 32 {
            let j = (i.wrapping_add(13).wrapping_add(round as usize)) % 32;
            let k = ((i as u8).wrapping_mul(7).wrapping_add(round)) as usize % 32;

            // Mix with neighboring bytes using multiply-xor-shift
            state[i] = state[i]
                .wrapping_add(state[j])
                .wrapping_mul(0x6D);
            state[i] ^= state[k];
            state[i] = state[i] ^ (state[i] >> 3);
            state[i] = state[i].wrapping_add(state[i] << 5);

            i += 1;
        }

        // Phase 2: 64-bit lane mixing (xorshift128+ inspired)
        let mut lanes = [0u64; 4];
        let mut lane_idx: usize = 0;
        while lane_idx < 4 {
            let o = lane_idx * 8;
            lanes[lane_idx] = u64::from_le_bytes([
                state[o],
                state[o + 1],
                state[o + 2],
                state[o + 3],
                state[o + 4],
                state[o + 5],
                state[o + 6],
                state[o + 7],
            ]);
            lane_idx += 1;
        }

        // Cross-lane diffusion
        lanes[0] ^= lanes[0] << 13;
        lanes[0] ^= lanes[0] >> 7;
        lanes[0] ^= lanes[0] << 17;

        lanes[1] = lanes[1].wrapping_add(lanes[0]);
        lanes[2] ^= lanes[1];
        lanes[3] = lanes[3].wrapping_add(lanes[2]);
        lanes[0] ^= lanes[3];

        // Write lanes back to state
        lane_idx = 0;
        while lane_idx < 4 {
            let bytes = lanes[lane_idx].to_le_bytes();
            let o = lane_idx * 8;
            state[o] = bytes[0];
            state[o + 1] = bytes[1];
            state[o + 2] = bytes[2];
            state[o + 3] = bytes[3];
            state[o + 4] = bytes[4];
            state[o + 5] = bytes[5];
            state[o + 6] = bytes[6];
            state[o + 7] = bytes[7];
            lane_idx += 1;
        }

        round += 1;
    }

    state
}
