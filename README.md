# Decentralised Bingo Game (Solidity + Foundry)

A decentralised, provably fair **Bingo** game built in Solidity using **Foundry**.

Key features:

- 5x5 Bingo board (middle cell is free)
- Multiple players per game
- Multiple concurrent games
- Each player pays an ERC20 entry fee
- Winner gets the full pot of entry fees
- Minimum join duration before game start
- Minimum turn duration between number draws
- Admin can update entry fee, join duration and turn duration
- Randomness based on `blockhash(block.number - 1)`
- Designed with events & public getters to support a frontend

---

## Bingo Rules (Implemented)

- Board: 5x5 grid of numbers; the **center cell is a free space**, pre-marked.
- Numbers: Each cell holds a `uint8` in `[0, 255]`.
- Win condition: Any **full row, column, or diagonal** where all cells are marked.
- Duplicates:
  - Boards may contain duplicate numbers.
  - A drawn number marks *all* matching cells.
  - The same number may be drawn again; additional draws have no effect.

---

## 🧱 Contracts Overview

### `BingoToken.sol`

- ERC20 token used as the **entry fee currency**.
- Owner-mintable, used to fund players in tests/demo.

Key points:

- Inherits `ERC20` and `Ownable`.
- Constructor mints an initial supply to the deployer.
- `mint(address to, uint256 amount)` for owner to distribute tokens.

---

### `BingoBoard.sol`

Manages the **5x5 boards** and checking winners.

#### `struct Board`

```solidity
struct Board {
    uint8[5][5] numbers; // board numbers
    bool[5][5] marked;   // mark state
    bool isBoard;        // whether board exists
}
```
### Storage

- boards[gameId][player] → Board

- drawnNumbers[gameId][number] → bool (has this number been drawn?)

```generateBoard(uint256 gameID, address player)```

- Creates/initializes a board for player in given gameID.

- For each cell ```(i, j)```:

  - If center cell ```(2, 2)``` → ```marked = true ```(free space).

  - Else → assigns a pseudo-random ```uint8``` using ```blockhash(block.number - 1) % 256```.

- Emits ```BoardGenerated(gameID, player)```.

Assumes boards are generated close to game creation; for production, randomness would be upgraded.

```markNumbers(uint256 gameID, address player, uint8 number)```

- If drawnNumbers[gameID][number] already true, returns early.

- Marks drawnNumbers[gameID][number] = true.

- For each cell on the player’s board:

  - If board.numbers[i][j] == number → sets marked[i][j] = true and emits NumberMarked.

```check(uint256 gameID, address player) returns (bool)```

- Scans the player’s board for a winning line:

1. All cells in any row marked

2. All cells in any column marked

3. All cells in main or anti-diagonal marked

- Emits BoardChecked(gameID, player, isWinner).

- Returns true if any winning line exists.

---

### `BingoGame.sol`

Orchestrates games, players, draws, and payouts.

#### State
```solidity
BingoToken public token;
BingoBoard public board;

uint8 public entryFee = 100;
uint8 public joinDuration = 2 minutes;
uint8 public turnDuration = 20 seconds;
uint8 public gameCounter = 0;

struct Game {
    uint8 gameId;
    uint256 startTime;
    uint256 lastDraw;
    uint256 pot;
    address winner;
    bool isActive;
    address[] players;
}

mapping(uint256 => Game) public games;
```

- ```entryFee```: Fixed ERC20 amount each player must pay to join.

- ```joinDuration```: Time window after game creation during which players can join.

- ```turnDuration```: Minimum time between draws.

- ```gameCounter```: Auto-incrementing game ID.

- ```games[gameId]```: Stores each game’s state and players.

#### Events

- ```GameCreated(gameId, startTime)```

- ```PlayerJoined(gameId, player, pot)```

- ```NumberDrawn(gameId, number)```

- ```WinnerDeclared(gameId, winner, pot)```

- ```GameReset(gameId)```

- ```AdminSettingsUpdated(entryFee, joinDuration, turnDuration)```

These allow a frontend to render current and historical game state.

--- 

###  Game Flow

#### 1. Admin creates a game
```solidity
function createGame() external onlyOwner;
```

- Increments ```gameCounter```.

- Initializes a new ```Game``` with:

  - ```gameId = gameCounter```

  - ```startTime = block.timestamp```

  - ```isActive = true```

- Emits ```GameCreated```.

Supports <b> multiple concurrent games</b> because each new call uses a new ```gameId```.

---

#### 2. Players join a game
```solidity
function joinGame(uint8 gameID) external;
```

- Requirements:

  - game.isActive == true

  - block.timestamp <= game.startTime + joinDuration

  - token.balanceOf(msg.sender) >= entryFee

- Effects:

  - token.transferFrom(msg.sender, address(this), entryFee)

  - Increments game.pot by entryFee

  - Adds player to game.players

  - Calls board.generateBoard(gameID, msg.sender) to create board

- Emits PlayerJoined.

Multiple players can join same game; multiple games can each have their own players.

---

### 3. Admin draws numbers
```solidty
function drawNumber(uint8 gameID) external onlyOwner;
```

- Requirements:

  - ```game.isActive == true```

  - ```block.timestamp >= game.lastDraw + turnDuration```

- Draws random number:
    ```solidity
    uint8 random = uint8(uint256(blockhash(block.number - 1)) % 256);
    ```

- For each player in ```game.players```, calls:
    ```solidty
    board.markNumbers(gameID, player, random);
    ```

Updates ```game.lastDraw = block.timestamp```

Emits ```NumberDrawn(gameID, random)```

---

### 4. Admin declares a winner
```solidity
function declareWinner(uint8 gameID) external onlyOwner;
```

- Checks game.isActive == true.

- Loops through game.players:

  - Calls board.check(gameID, player)

  - On first true:

    - game.winner = player

    - Transfers game.pot tokens to winner

    - Sets game.pot = 0

    - Sets game.isActive = false

    - Emits WinnerDeclared(gameId, winner, pot)

Assumes players are online and call is made after enough draws that someone can win.

---

### 5. Reset game
```solidity
function resetGame(uint8 gameID) external onlyOwner;
```

- Requires ```!game.isActive```

- Clears:

  - players array

  - winner

  - pot

  - lastDraw

- Marks isActive = true again and resets startTime.

Enables reusing game IDs while preserving a reset event for frontend/history.

---

### 🌐 Public API & Frontend Integration

Useful read-only functions:

- ```games(gameId)``` → returns game struct fields (id, times, pot, winner, active)

- ```getPlayers(gameId)``` → address[]

- ```entryFee()```, joinDuration()```, turnDuration()```

- ```boards(gameId, player)``` from ```BingoBoard``` → to render board numbers & marked state

- ```drawnNumbers(gameId, number)``` → whether a number has been drawn

Useful events:

- ```GameCreated```

- ```PlayerJoined```

- ```NumberDrawn```

- ```WinnerDeclared```

- ```GameReset```

- ```BoardGenerated```

- ```NumberMarked```

- ```BoardChecked```

A frontend can:

- Subscribe to events to update state live.

- Use ```games(gameId)``` + ```getPlayers``` + ```boards``` mapping to reconstruct full game state.

---

### 🧪 Testing (Foundry)

Tests in ```test/BingoGame.t.sol``` cover:

- ```testCreateGame```

  - Emits ```GameCreated```

  - Asserts game state initialized properly

- ```testJoinGame```

  - Player approves token

  - Joins game

  - Checks players array length and pot balance

- ```testDrawNumber```

  - Requires game & at least one player

  - Advances time using ```vm.warp```

  - Verifies ```lastDraw``` updated after draw

- ```testDeclareWinner```

  - Mocks ```board.check``` to force a win using ```vm.mockCall```

  - Ensures:

    - Winner stored

    - Pot set to 0

    - Game set inactive

- ```testResetGame```

  - Runs through full cycle (create → join → draw → declareWinner → reset)

  - Checks that resetting clears players, pot, winner and reactivates game

Run tests:
```bash
forge test
```

Add ```--gas-report``` for gas stats.

---

### 🛠 Setup & Usage

Prerequisites:

Foundry Install:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Build:
```bash
forge build
```

Test:
```bash
forge test --gas-report
```