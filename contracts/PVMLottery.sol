// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice Interface for the Rust PVM VRF contract
interface IRustVRF {
    function generateRandom(uint256 seed) external view returns (uint256);
}

/// @title PVM Lottery — Rust-Powered Random Number Generation on Polkadot
/// @notice A lottery dApp that demonstrates calling a Rust PVM contract from Solidity.
///         The heavy-lifting random number generation runs in Rust compiled to RISC-V,
///         showcasing PolkaVM's cross-language interop capabilities.
contract PVMLottery {
    address public owner;
    IRustVRF public rustVrf;
    uint256 public ticketPrice;
    uint256 public currentRound;

    struct Round {
        uint256 prizePool;
        uint256 playerCount;
        address winner;
        bool drawn;
        mapping(uint256 => address) players;
    }

    mapping(uint256 => Round) internal rounds;

    event TicketPurchased(uint256 indexed roundId, address indexed player, uint256 ticketIndex);
    event WinnerDrawn(uint256 indexed roundId, address indexed winner, uint256 prize, uint256 randomValue);
    event RoundStarted(uint256 indexed roundId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(address _rustVrf, uint256 _ticketPrice) {
        owner = msg.sender;
        rustVrf = IRustVRF(_rustVrf);
        ticketPrice = _ticketPrice;
        currentRound = 1;
        emit RoundStarted(1);
    }

    /// @notice Buy a ticket for the current lottery round
    function buyTicket() external payable {
        require(msg.value >= ticketPrice, "Insufficient payment");
        require(!rounds[currentRound].drawn, "Round already drawn");

        Round storage round = rounds[currentRound];
        uint256 ticketIndex = round.playerCount;
        round.players[ticketIndex] = msg.sender;
        round.playerCount++;
        round.prizePool += msg.value;

        emit TicketPurchased(currentRound, msg.sender, ticketIndex);
    }

    /// @notice Draw the winner using the Rust VRF contract for random number generation
    function drawWinner() external onlyOwner {
        Round storage round = rounds[currentRound];
        require(!round.drawn, "Already drawn");
        require(round.playerCount > 0, "No players");

        // Build entropy seed from on-chain sources
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.number,
            block.prevrandao,
            msg.sender,
            round.playerCount,
            currentRound
        )));

        // Call Rust VRF for additional mixing (the core PVM demo!)
        uint256 random;
        try rustVrf.generateRandom(seed) returns (uint256 result) {
            random = result;
        } catch {
            // Fallback: use seed directly if Rust call fails
            random = seed;
        }

        // Select winner
        uint256 winnerIndex = random % round.playerCount;
        address winner = round.players[winnerIndex];

        round.winner = winner;
        round.drawn = true;

        // Transfer prize
        uint256 prize = round.prizePool;
        (bool sent, ) = payable(winner).call{value: prize}("");
        require(sent, "Prize transfer failed");

        emit WinnerDrawn(currentRound, winner, prize, random);

        // Start next round
        currentRound++;
        emit RoundStarted(currentRound);
    }

    /// @notice Get info about the current round
    function getCurrentRound() external view returns (
        uint256 roundId,
        uint256 playerCount,
        uint256 prizePool,
        bool drawn
    ) {
        Round storage round = rounds[currentRound];
        return (currentRound, round.playerCount, round.prizePool, round.drawn);
    }

    /// @notice Get a player's address by index in a given round
    function getPlayer(uint256 roundId, uint256 index) external view returns (address) {
        return rounds[roundId].players[index];
    }

    /// @notice Get the winner of a completed round
    function getWinner(uint256 roundId) external view returns (address) {
        require(rounds[roundId].drawn, "Not drawn yet");
        return rounds[roundId].winner;
    }

    /// @notice Get round details
    function getRound(uint256 roundId) external view returns (
        uint256 playerCount,
        uint256 prizePool,
        address winner,
        bool drawn
    ) {
        Round storage round = rounds[roundId];
        return (round.playerCount, round.prizePool, round.winner, round.drawn);
    }

    /// @notice Compare gas: pure Solidity random (no Rust)
    function generateRandomSolidity(uint256 seed) external pure returns (uint256) {
        // Equivalent mixing in Solidity for gas comparison demo
        bytes32 state = bytes32(seed);
        for (uint256 round = 0; round < 64; round++) {
            state = keccak256(abi.encodePacked(state, round));
        }
        return uint256(state);
    }

    /// @notice Compare gas: call Rust VRF
    function generateRandomRust(uint256 seed) external view returns (uint256) {
        return rustVrf.generateRandom(seed);
    }
}
