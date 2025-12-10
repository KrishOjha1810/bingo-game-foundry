// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

contract BingoBoard {
    /// @notice Represents the board with numbers and marked cells
    struct Board {
        uint8[5][5] numbers;    // Stores the numbers on the board (5x5 grid)
        bool[5][5] marked;      // Tracks marked numbers on the board
        bool isBoard;           // Indicates if the board is active
    }

    /// @notice Maps game ID and player address to their board
    mapping(uint256 => mapping(address => Board)) public boards;

    /// @notice Tracks whether a number has been drawn for a specific game
    /// @dev Mapping: gameID -> bingo number -> drawn or not
    mapping(uint256 => mapping(uint8 => bool)) public drawnNumbers;

    /// @notice Emitted when a board is generated for a player
    /// @param gameID The ID of the game
    /// @param player The address of the player
    event BoardGenerated(uint256 gameID, address player);

    /// @notice Emitted when a number is marked on the board
    /// @param gameID The ID of the game
    /// @param player The address of the player
    /// @param number The number that was marked
    event NumberMarked(uint256 gameID, address player, uint8 number);

    /// @notice Emitted when a board is checked for a winner
    /// @param gameID The ID of the game
    /// @param player The address of the player
    /// @param isWinner Whether the player is a winner or not
    event BoardChecked(uint256 gameID, address player, bool isWinner);

    /// @notice Generates a Bingo board for a player in a given game
    /// @dev Initializes the board with random numbers except the center cell
    /// @param gameID The ID of the game
    /// @param player The address of the player
    function generateBoard(uint256 gameID, address player) external {
        Board storage board = boards[gameID][player];
        board.isBoard = true; // Activate the board

        for (uint8 i = 0; i < 5; i++) {
            for (uint8 j = 0; j < 5; j++) {
                if (j == 2 && i == 2) {
                    // Center cell is a free space (marked by default)
                    board.marked[i][j] = true;
                } else {
                    // Assign random numbers to the board
                    board.numbers[i][j] = uint8(uint256(blockhash(block.number - 1)) % 256);
                }
            }
        }

        emit BoardGenerated(gameID, player);
    }

    /// @notice Marks a number on the player's board
    /// @dev Prevents marking the same number multiple times
    /// @param gameID The ID of the game
    /// @param player The address of the player
    /// @param number The number to mark
    function markNumbers(uint256 gameID, address player, uint8 number) external {
        if (drawnNumbers[gameID][number]) return; // Skip marking if already drawn
        drawnNumbers[gameID][number] = true;       // Mark the number as drawn

        Board storage board = boards[gameID][player];

        for (uint8 i = 0; i < 5; i++) {
            for (uint8 j = 0; j < 5; j++) {
                if (board.numbers[i][j] == number) {
                    board.marked[i][j] = true;
                    emit NumberMarked(gameID, player, number);
                }
            }
        }
    }

    /// @notice Checks if the player has won the game by forming a row, column, or diagonal
    /// @param gameID The ID of the game
    /// @param player The address of the player
    /// @return Whether the player is a winner or not
    function check(uint256 gameID, address player) external returns (bool) {
        Board storage board = boards[gameID][player];

        // Check rows for a winning combination
        for (uint256 i = 0; i < 5; i++) {
            bool winner = true;
            for (uint8 j = 0; j < 5; j++) {
                if (!board.marked[i][j]) {
                    winner = false;
                    break;
                }
            }
            if (winner) {
                emit BoardChecked(gameID, player, true);
                return true;
            }
        }

        // Check columns for a winning combination
        for (uint8 j = 0; j < 5; j++) {
            bool winner = true;
            for (uint8 i = 0; i < 5; i++) {
                if (!board.marked[i][j]) {
                    winner = false;
                    break;
                }
            }
            if (winner) {
                emit BoardChecked(gameID, player, true);
                return true;
            }
        }

        // Check diagonals
        bool diagonal1 = true;
        bool diagonal2 = true;
        for (uint8 i = 0; i < 5; i++) {
            if (!board.marked[i][i]) diagonal1 = false;
            if (!board.marked[i][4 - i]) diagonal2 = false;
        }

        bool isWinner = diagonal1 || diagonal2;
        emit BoardChecked(gameID, player, isWinner);
        return isWinner;
    }
}
