// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/BingoBoard.sol";
import "../src/BingoGame.sol";
import "../src/BingoToken.sol";
import "forge-std/console.sol"; 


contract BingoGameTest is Test {
    BingoToken public token;
    BingoGame public game;
    BingoBoard public board;

    address owner = address(1);
    address player1 = address(2);
    address player2 = address(3);

    uint256 entryFee = 100;

    function setUp() public {
        vm.startPrank(owner);

        token = new BingoToken(1000);
        board = new BingoBoard();
        game = new BingoGame(address(token), address(board));

        token.mint(player1, 1000);
        token.mint(player2, 1000);

        vm.stopPrank();

        vm.prank(player1);
        token.approve(address(game), entryFee); //approving game contract

        vm.prank(player2);
        token.approve(address(game), entryFee);
    }

    function testCreateGame() public {
        vm.startPrank(owner);

        vm.expectEmit(true, false, false, true);  
        emit BingoGame.GameCreated(1, block.timestamp);
        game.createGame();

        (uint256 gameID,,, uint256 pot, , bool isActive) = game.games(1);

        assertEq(gameID, 1);
        assertEq(isActive, true);
        assertEq(pot, 0);

        vm.stopPrank();
    }

    function testJoinGame() public{
        vm.prank(owner);
        game.createGame();

        vm.expectEmit(true, true, false, true);
        emit BingoGame.PlayerJoined(1, player1, entryFee);
        vm.prank(player1);
        game.joinGame(1);

        address[] memory players = game.getPlayers(1);

        (, , , uint256 pot, , ) = game.games(1);
        assertEq(players.length, 1);
        assertEq(pot, game.entryFee());
    }

    function testDrawNumber() public{
        vm.prank(owner);
        game.createGame();

        vm.prank(player1);
        game.joinGame(1);

        vm.warp(block.timestamp + game.turnDuration());

        vm.expectEmit(true, false, false, true);
        vm.prank(owner);
        game.drawNumber(1);
        
        (, , uint256 lastDraw, , , ) = game.games(1);
        assert(lastDraw > 0); // Ensure lastDraw timestamp is updated
    }

    function testDeclareWinner() public{
        vm.prank(owner);
        game.createGame();

        vm.prank(player1);
        game.joinGame(1);

        vm.prank(player2);
        game.joinGame(1);

        vm.warp(block.timestamp + game.turnDuration());

        vm.prank(owner);
        game.drawNumber(1);

        vm.mockCall(
            address(board), //address of the contract we want to mock
            abi.encodeWithSelector(board.check.selector, 1, player1),
            abi.encode(true)//mocked return value
        );

        vm.prank(owner);
        game.declareWinner(1);

        (, , , uint256 pot,address winner, bool isActive) = game.games(1);
        address[] memory players = game.getPlayers(1);
        
        assertEq(winner, player1);
        assertEq(pot, 0);
        assertEq(false, isActive);
        assertEq(players.length, 2);
    }

    function testResetGame() public {
        vm.prank(owner);
        game.createGame();

        vm.prank(player1);
        game.joinGame(1);

        vm.warp(block.timestamp + game.turnDuration());

        vm.prank(owner);
        game.drawNumber(1);

        vm.mockCall(
            address(board), //address of the contract we want to mock
            abi.encodeWithSelector(board.check.selector, 1, player1),
            abi.encode(true)//mocked return value
        );

        vm.prank(owner);
        game.declareWinner(1);

        vm.prank(owner);
        game.resetGame(1);

        (, , uint256 lastDraw, uint256 pot,address winner, bool isActive) = game.games(1);
        address[] memory players = game.getPlayers(1);

        assertEq(players.length, 0);
        assertEq(winner, address(0));
        assertEq(pot, 0);
        assertEq(lastDraw, 0);
        assertEq(isActive, true);
    }
}
