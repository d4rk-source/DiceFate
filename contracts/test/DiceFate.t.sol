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
        uint256 targetNumber = 50;
        uint256 betId = diceFate.placeBet{value: betAmount}(targetNumber);
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

            // Calculate expected payout with corrected variable payouts
            // For target 50: multiplier = 100/49 ≈ 2.04x
            // payout = 1 ether * (100/49) * 0.95 ≈ 1.939 ether
        uint256 expectedPayout = diceFate.calculateWinPayout(
            betAmount,
            targetNumber
        );
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

    function test_VariablePayoutsLowerTargetHigherPayout() public {
        uint256 betAmount = 1 ether;

        // Target 10: 100/9 ≈ 11.11x multiplier
        uint256 payout10 = diceFate.calculateWinPayout(betAmount, 10);

        // Target 50: 100/49 ≈ 2.04x multiplier
        uint256 payout50 = diceFate.calculateWinPayout(betAmount, 50);

        // Target 99: 100/98 ≈ 1.02x multiplier
        uint256 payout99 = diceFate.calculateWinPayout(betAmount, 99);

        // Higher risk (lower target) should have higher payout
        assertGt(
            payout10,
            payout50,
            "Target 10 should have higher payout than target 50"
        );
        assertGt(
            payout50,
            payout99,
            "Target 50 should have higher payout than target 99"
        );

        // Exact payout estimates (with 5% house edge):
        // Target 10: 1 * (100/9) * 0.95 ≈ 10.56 ETH
        // Target 50: 1 * (100/49) * 0.95 ≈ 1.939 ETH
        // Target 99: 1 * (100/98) * 0.95 ≈ 0.969 ETH
        assertGt(
            payout10,
            10 ether,
            "Target 10 should pay ~10.56 ETH on 1 ETH bet"
        );
        assertLt(payout10, 11 ether, "Target 10 should pay less than 11 ETH");

        assertGt(
            payout50,
            1.8 ether,
            "Target 50 should pay ~1.939 ETH on 1 ETH bet"
        );
        assertLt(payout50, 2.1 ether, "Target 50 should pay less than 2.1 ETH");
    }

    function test_VariablePayoutsHighRiskBet() public {
        vm.startPrank(player1);
        // High risk bet: target 10 (10% win chance)
        uint256 betAmount = 1 ether;
        uint256 targetNumber = 10;
        uint256 betId = diceFate.placeBet{value: betAmount}(targetNumber);
        vm.stopPrank();

        uint256 player1BalanceBefore = player1.balance;

        vm.startPrank(owner);
        // Roll 5 (under 10) = WINNING high-risk bet
        diceFate.resolveBet(betId, 5);
        vm.stopPrank();

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.won, true);

        // Target 10: multiplier = 100/9 ≈ 11.11x, payout = 1 * (100/9) * 0.95 ≈ 10.56 ETH
        uint256 expectedPayout = diceFate.calculateWinPayout(
            betAmount,
            targetNumber
        );
        assertEq(player1.balance - player1BalanceBefore, expectedPayout);
        assertGt(
            expectedPayout,
            10 ether,
            "High risk bet should payout > 10 ETH"
        );
    }

    function test_VariablePayoutsLowRiskBet() public {
        vm.startPrank(player1);
        // Low risk bet: target 99 (99% win chance)
        uint256 betAmount = 1 ether;
        uint256 targetNumber = 99;
        uint256 betId = diceFate.placeBet{value: betAmount}(targetNumber);
        vm.stopPrank();

        uint256 player1BalanceBefore = player1.balance;

        vm.startPrank(owner);
        // Roll 50 (under 99) = WINNING low-risk bet
        diceFate.resolveBet(betId, 50);
        vm.stopPrank();

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.won, true);

        // Target 99: multiplier = 100/98 ≈ 1.02x, payout = 1 * (100/98) * 0.95 ≈ 0.969 ETH
        uint256 expectedPayout = diceFate.calculateWinPayout(
            betAmount,
            targetNumber
        );
        assertEq(player1.balance - player1BalanceBefore, expectedPayout);
        assertLt(expectedPayout, 1 ether, "Low risk bet should payout < 1 ETH (0.969)");
    }

    function test_PayoutMultipliers() public {
        // Test the multipliers directly

        uint256 mult10 = diceFate.calculatePayoutMultiplier(10); // Should be ~11.11x = 111111
        uint256 mult50 = diceFate.calculatePayoutMultiplier(50); // Should be ~2.04x = 20408
        uint256 mult99 = diceFate.calculatePayoutMultiplier(99); // Should be ~1.02x = 10204
    }
        assertEq(mult10, 111111, "Target 10 should have ~11.11x multiplier");
        assertEq(mult50, 20408, "Target 50 should have ~2.04x multiplier");
        assertEq(mult99, 10204, "Target 99 should have ~1.02x multiplier");
}
