# Decentralised Bingo Game

On-chain, multiplayer Bingo settled in an ERC20 token, built with Solidity and Foundry.

![Solidity](https://img.shields.io/badge/Solidity-0.8.x-363636?logo=solidity&logoColor=white)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-000000?logo=foundry&logoColor=white)
![License](https://img.shields.io/badge/License-Unlicense-blue)

## Overview

This project implements a classic 5x5 Bingo game entirely on-chain. Each player pays a fixed ERC20 entry fee to join a game, receives a randomly generated board, and the admin draws numbers turn by turn. The first player to complete a full row, column, or diagonal wins the entire pot of entry fees.

The system is split across three contracts so that token logic, board logic, and game orchestration stay cleanly separated. Every state change emits an event and exposes a public getter, so a frontend can subscribe to live updates and reconstruct full game state at any time.

Key characteristics:

- 5x5 board with a pre-marked free center cell
- Multiple players per game and multiple concurrent games
- ERC20 entry fee, winner-takes-the-pot payout
- Time-gated join window and a minimum delay between draws
- Admin-tunable entry fee, join duration, and turn duration
- Pseudo-randomness sourced from `blockhash(block.number - 1)`

> Note: randomness is derived from the previous block hash, which is suitable for a demo but is not secure against a motivated validator. A production deployment would use a verifiable randomness source (for example, Chainlink VRF).

## Contracts

### `BingoToken.sol`

The ERC20 token (`BingoToken`, symbol `BT`) used as the entry fee and payout currency. It inherits OpenZeppelin's `ERC20` and `Ownable`. The constructor mints an initial supply to the deployer, and an owner-only `mint(address to, uint256 amount)` function distributes tokens to players for testing and demos.

### `BingoBoard.sol`

Owns all board state and the win check. Each player's board is stored per game as a `Board` struct holding a 5x5 grid of numbers, a parallel 5x5 grid of marked flags, and an `isBoard` existence flag.

- `generateBoard(gameID, player)` initializes a board, pre-marks the center cell as a free space, and fills the remaining cells with pseudo-random `uint8` values.
- `markNumbers(gameID, player, number)` records a drawn number once per game and marks every matching cell on the player's board. Repeat draws of the same number are ignored.
- `check(gameID, player)` scans for any fully marked row, column, or diagonal and returns whether the player has won.

### `BingoGame.sol`

The orchestrator. It holds references to the token and board contracts, tracks every game in a `Game` struct (id, timestamps, pot, winner, active flag, and player list), and gates sensitive actions behind `Ownable`. It manages the full lifecycle: create, join, draw, declare a winner, and reset. Admin settings (entry fee, join duration, turn duration) are tunable via `adminSettings`.

## How the game works

1. **Create.** The admin calls `createGame()`. This increments the game counter, records `startTime`, marks the game active, and emits `GameCreated`. Each call uses a fresh game id, so many games can run at once.
2. **Join.** A player calls `joinGame(gameID)` while the game is active and within `startTime + joinDuration`. The contract pulls `entryFee` tokens via `transferFrom`, adds them to the pot, appends the player, and generates their board through `BingoBoard`. Emits `PlayerJoined`.
3. **Draw.** The admin calls `drawNumber(gameID)`, allowed only once `turnDuration` has elapsed since the last draw. A pseudo-random number is derived from the previous block hash and marked on every player's board. Emits `NumberDrawn`.
4. **Declare winner.** The admin calls `declareWinner(gameID)`. It loops through players, and on the first board that passes `check`, it stores the winner, transfers the full pot to them, zeroes the pot, deactivates the game, and emits `WinnerDeclared`.
5. **Reset.** Once a game is inactive, the admin can call `resetGame(gameID)` to clear the player list, winner, pot, and last-draw timestamp, then reactivate the game with a fresh start time. Emits `GameReset`, so history stays observable.

Win condition: a player wins when any full row, any full column, or either diagonal is completely marked. Because the center cell starts marked, it contributes to the center row, center column, and both diagonals for free.

## Tech stack

- **Solidity** (`^0.8.19` to `^0.8.22`) for the contracts
- **Foundry** (`forge`) for building and testing
- **OpenZeppelin Contracts** for `ERC20` and `Ownable`

## Getting started

Install Foundry if you do not have it:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies:

```bash
forge install OpenZeppelin/openzeppelin-contracts
```

Build the contracts:

```bash
forge build
```

Run the test suite:

```bash
forge test
```

## Testing

`test/BingoGame.t.sol` exercises the full game lifecycle. `setUp` deploys the token, board, and game contracts, mints tokens to two players, and approves the game contract to spend their entry fees.

- **`testCreateGame`** asserts `GameCreated` is emitted and the new game is initialized with the right id, an active status, and a zero pot.
- **`testJoinGame`** has a player join, then verifies `PlayerJoined` fires and that the players array and pot update correctly.
- **`testDrawNumber`** creates a game, joins a player, warps past `turnDuration` with `vm.warp`, draws, and confirms `lastDraw` is updated.
- **`testDeclareWinner`** joins two players, draws, then uses `vm.mockCall` to force `board.check` to return true for player 1, and asserts the winner is recorded, the pot is zeroed, and the game is deactivated.
- **`testResetGame`** runs the entire cycle (create, join, draw, declare winner, reset) and confirms the reset clears players, winner, pot, and last-draw timestamp while reactivating the game.

Add `--gas-report` to any test run for gas usage stats:

```bash
forge test --gas-report
```

## License

Unlicense. Authored by Krish Ojha.
