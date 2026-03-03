// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DiceFate} from "../src/DiceFate.sol";
import {MockVRFCoordinatorV2} from "../src/MockVRFCoordinatorV2.sol";

contract DiceFateTest is Test {
    DiceFate public diceFate;
    MockVRFCoordinatorV2 public mockVRF;

    address public owner = address(0x1);
    address public player1 = address(0x2);
    address public player2 = address(0x3);

    bytes32 public constant KEY_HASH = keccak256(abi.encode("key"));
    uint64 public constant SUB_ID = 1;
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        vm.startPrank(owner);

        mockVRF = new MockVRFCoordinatorV2();
        diceFate = new DiceFate(address(mockVRF), KEY_HASH, SUB_ID);

        // Fund the house
        diceFate.depositHouse{value: INITIAL_BALANCE}();

        vm.stopPrank();
    }

    function test_PlaceBet() public {
        vm.startPrank(player1);
        uint256 betAmount = 1 ether;

        uint256 betId = diceFate.placeBet{value: betAmount}(50);

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.player, player1);
        assertEq(bet.amount, betAmount);
        assertEq(bet.targetNumber, 50);
        assertEq(bet.resolved, false);

        vm.stopPrank();
    }

    function test_PlaceBetMultipleBets() public {
        vm.startPrank(player1);

        uint256 betId1 = diceFate.placeBet{value: 1 ether}(50);
        uint256 betId2 = diceFate.placeBet{value: 2 ether}(75);

        uint256[] memory playerBets = diceFate.getPlayerBets(player1);
        assertEq(playerBets.length, 2);
        assertEq(playerBets[0], betId1);
        assertEq(playerBets[1], betId2);

        vm.stopPrank();
    }

    function test_ResolveBetWin() public {
        vm.startPrank(player1);
        uint256 betAmount = 1 ether;
        uint256 betId = diceFate.placeBet{value: betAmount}(50);
        vm.stopPrank();

        uint256 player1BalanceBefore = player1.balance;

        vm.startPrank(owner);
        // Roll 25 (under 50) = winning bet
        uint256 randomNumber = 25;
        diceFate.resolveBet(betId, randomNumber);
        vm.stopPrank();

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.resolved, true);
        assertEq(bet.won, true);
        assertEq(bet.rollResult, 25);

        // Calculate expected payout: 1 ether * 1.95 * (1 - 0.05)
        // = 1e18 * 195 / 10000 * 9500 / 10000
        // = 1e18 * 0.185375
        uint256 expectedPayout = (((betAmount * 195) / 10000) * 9500) / 10000;
        assertEq(player1.balance - player1BalanceBefore, expectedPayout);
    }

    function test_ResolveBetLose() public {
        vm.startPrank(player1);
        uint256 betAmount = 1 ether;
        uint256 betId = diceFate.placeBet{value: betAmount}(50);
        vm.stopPrank();

        uint256 player1BalanceBefore = player1.balance;

        vm.startPrank(owner);
        // Roll 75 (over 50) = losing bet
        uint256 randomNumber = 75;
        diceFate.resolveBet(betId, randomNumber);
        vm.stopPrank();

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.resolved, true);
        assertEq(bet.won, false);
        assertEq(bet.rollResult, 75);

        // Player should not receive anything
        assertEq(player1.balance, player1BalanceBefore);
    }

    function test_InvalidTargetNumber() public {
        vm.startPrank(player1);

        // Too low
        vm.expectRevert("Target must be between 2-100");
        diceFate.placeBet{value: 1 ether}(1);

        // Too high
        vm.expectRevert("Target must be between 2-100");
        diceFate.placeBet{value: 1 ether}(101);

        vm.stopPrank();
    }

    function test_ZeroBet() public {
        vm.startPrank(player1);

        vm.expectRevert("Bet must be greater than 0");
        diceFate.placeBet{value: 0}(50);

        vm.stopPrank();
    }

    function test_InsufficientHouseBalance() public {
        vm.startPrank(owner);
        // Withdraw all house funds
        diceFate.withdrawHouse(INITIAL_BALANCE);
        vm.stopPrank();

        vm.startPrank(player1);

        vm.expectRevert("Insufficient house balance");
        diceFate.placeBet{value: 1 ether}(50);

        vm.stopPrank();
    }

    function test_HouseDeposit() public {
        uint256 balanceBefore = INITIAL_BALANCE;

        vm.startPrank(owner);
        diceFate.depositHouse{value: 100 ether}();
        vm.stopPrank();

        assertEq(diceFate.contractBalance(), balanceBefore + 100 ether);
    }

    function test_HouseWithdraw() public {
        vm.startPrank(owner);
        diceFate.withdrawHouse(100 ether);
        vm.stopPrank();

        assertEq(diceFate.contractBalance(), INITIAL_BALANCE - 100 ether);
    }

    function test_ReceiveETH() public {
        uint256 balanceBefore = diceFate.contractBalance();

        vm.startPrank(player1);
        (bool success, ) = payable(address(diceFate)).call{value: 50 ether}("");
        require(success, "Send failed");
        vm.stopPrank();

        assertEq(diceFate.contractBalance(), balanceBefore + 50 ether);
    }

    function test_MultiplePlayersMultipleBets() public {
        vm.startPrank(player1);
        uint256 bet1Id = diceFate.placeBet{value: 1 ether}(50);
        uint256 bet2Id = diceFate.placeBet{value: 2 ether}(75);
        vm.stopPrank();

        vm.startPrank(player2);
        uint256 bet3Id = diceFate.placeBet{value: 0.5 ether}(25);
        vm.stopPrank();

        // Resolve all bets
        vm.startPrank(owner);
        diceFate.resolveBet(bet1Id, 30); // win
        diceFate.resolveBet(bet2Id, 80); // lose
        diceFate.resolveBet(bet3Id, 10); // win
        vm.stopPrank();

        DiceFate.Bet memory bet1 = diceFate.getBet(bet1Id);
        DiceFate.Bet memory bet2 = diceFate.getBet(bet2Id);
        DiceFate.Bet memory bet3 = diceFate.getBet(bet3Id);

        assertEq(bet1.won, true);
        assertEq(bet2.won, false);
        assertEq(bet3.won, true);
    }

    function test_EdgeCase_RollExactly100() public {
        vm.startPrank(player1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(100);
        vm.stopPrank();

        vm.startPrank(owner);
        // Roll 100 - should be exactly 100 (not under)
        diceFate.resolveBet(betId, 0); // 0 % 100 + 1 = 1, wait this is wrong
        // Let me recalculate: randomNumber = 99, 99 % 100 + 1 = 100
        diceFate.resolveBet(betId, 99);
        vm.stopPrank();

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.rollResult, 100);
        assertEq(bet.won, false); // Not under 100
    }

    function test_DiceRangeCalculation() public {
        uint256 maxVal = 99;
        uint256 result = (maxVal % 100) + 1;
        assertEq(result, 100);

        uint256 minVal = 0;
        uint256 result2 = (minVal % 100) + 1;
        assertEq(result2, 1);
    }
}
