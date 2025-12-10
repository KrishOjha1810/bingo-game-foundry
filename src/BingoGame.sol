// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.22;

import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "../src/BingoToken.sol";
import "../src/BingoBoard.sol";

/**
 * @title BingoGame
 * @dev Manages the Bingo game logic, including creating games, joining, drawing numbers, and declaring winners.
 */
contract BingoGame is Ownable {
    BingoToken public token;
    BingoBoard public board;

    uint8 public entryFee = 100;
    uint8 public joinDuration = 2 minutes;
    uint8 public turnDuration = 20 seconds;
    uint8 public gameCounter = 0;

    struct Game {
        uint8 gameId;
        uint256 startTime; // Timestamp when the game starts
        uint256 lastDraw; // Keeps track of the last draw timestamp
        uint256 pot; // Total tokens in the game pot
        address winner; // Winner's address
        bool isActive; // Game status
        address[] players; // List of players
    }

    mapping(uint256 => Game) public games; // Map game ID to Game instance

    event GameCreated(uint256 indexed gameId, uint256 startTime);
    event PlayerJoined(uint256 indexed gameId, address indexed player, uint256 pot);
    event NumberDrawn(uint256 indexed gameId, uint8 number);
    event WinnerDeclared(uint256 indexed gameId, address winner, uint256 pot);
    event GameReset(uint256 indexed gameId);
    event AdminSettingsUpdated(uint256 indexed entryFee, uint256 joinDuration, uint256 turnDuration);

    /**
     * @dev Initializes the contract with BingoToken and BingoBoard addresses.
     * @param _token Address of the BingoToken contract
     * @param _board Address of the BingoBoard contract
     */
    constructor(address _token, address _board) Ownable(msg.sender) {
        token = BingoToken(_token);
        board = BingoBoard(_board);
    }

    /**
     * @dev Updates admin settings.
     * @param _entryFee New entry fee
     * @param _joinDuration New join duration in seconds
     * @param _turnDuration New turn duration in seconds
     */
    function adminSettings(uint8 _entryFee, uint8 _joinDuration, uint8 _turnDuration) external onlyOwner {
        require(_joinDuration > 0 && _turnDuration > 0, "Durations must be positive");

        entryFee = _entryFee;
        joinDuration = _joinDuration;
        turnDuration = _turnDuration;
        emit AdminSettingsUpdated(_entryFee, _joinDuration, _turnDuration);
    }

    /**
     * @dev Creates a new Bingo game.
     */
    function createGame() external onlyOwner {
        gameCounter++;
        
        Game storage game = games[gameCounter];
        game.gameId = gameCounter;
        game.startTime = block.timestamp;
        game.isActive = true;
        emit GameCreated(gameCounter, game.startTime);
    }

    /**
     * @dev Returns the list of players in a game.
     * @param gameID ID of the game
     * @return List of player addresses
     */
    function getPlayers(uint8 gameID) external view returns (address[] memory) {
        return games[gameID].players;
    }

    /**
     * @dev Allows players to join an active game by paying the entry fee.
     * @param gameID ID of the game to join
     */
    function joinGame(uint8 gameID) external {
        Game storage game = games[gameID];
        require(game.isActive, "Game isn't active");
        require(block.timestamp <= game.startTime + joinDuration, "Join period ended");
        require(token.balanceOf(msg.sender) >= entryFee, "Insufficient Balance");
        
        token.transferFrom(msg.sender, address(this), entryFee);
        game.pot += entryFee;
        game.players.push(msg.sender);
        board.generateBoard(gameID, msg.sender);
        emit PlayerJoined(gameID, msg.sender, game.pot);
    }

    /**
     * @dev Draws a random number and marks it on all player boards.
     * @param gameID ID of the game
     */
    function drawNumber(uint8 gameID) external onlyOwner {
        Game storage game = games[gameID];
        require(game.isActive, "Game isn't active");
        require(block.timestamp >= game.lastDraw + turnDuration, "Wait for next turn");
        
        uint8 random = uint8(uint256(blockhash(block.number - 1)) % 256);
        
        for (uint256 i = 0; i < game.players.length; i++) {
            board.markNumbers(gameID, game.players[i], random);
        }
        game.lastDraw = block.timestamp;
        emit NumberDrawn(gameID, random);
    }

    /**
     * @dev Declares the winner by checking all player boards.
     * @param gameID ID of the game
     */
    function declareWinner(uint8 gameID) external onlyOwner {
        Game storage game = games[gameID];
        require(game.isActive, "Game isn't active");

        for (uint256 i = 0; i < game.players.length; i++) {
            if (board.check(gameID, game.players[i])) {
                game.winner = game.players[i];
                token.transfer(game.winner, game.pot);
                game.pot = 0;
                game.isActive = false;
                emit WinnerDeclared(gameID, game.winner, game.pot);
                break;
            }
        }
    }

    /**
     * @dev Resets the game state.
     * @param gameID ID of the game to reset
     */
    function resetGame(uint8 gameID) external onlyOwner {
        Game storage game = games[gameID];
        require(!game.isActive, "Game is Still Active");

        delete game.players;
        game.winner = address(0);
        game.pot = 0;
        game.isActive = true;

        game.startTime = block.timestamp;
        game.lastDraw = 0;
        emit GameReset(gameID);
    }
}
