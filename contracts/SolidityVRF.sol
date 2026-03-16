// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title Solidity VRF — Drop-in replacement for the Rust VRF contract
/// @notice Implements the same generateRandom(uint256) interface using
///         the same multi-round mixing algorithm as the Rust version.
contract SolidityVRF {
    function generateRandom(uint256 seed) external pure returns (uint256) {
        bytes32 state = bytes32(seed);
        // 64 rounds of mixing to match the Rust VRF's avalanche effect
        for (uint256 round = 0; round < 64; round++) {
            state = keccak256(abi.encodePacked(state, round));
        }
        return uint256(state);
    }
}
