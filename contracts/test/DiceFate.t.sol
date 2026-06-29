// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DiceFate} from "../src/DiceFate.sol";
import {MockVRFCoordinatorV2} from "../src/MockVRFCoordinatorV2.sol";

// ─── Unit & integration tests ────────────────────────────────────────────────

contract DiceFateTest is Test {
    DiceFate             public diceFate;
    MockVRFCoordinatorV2 public mockVRF;

    address public constant OWNER   = address(0x1);
    address public constant PLAYER1 = address(0x2);
    address public constant PLAYER2 = address(0x3);

    bytes32 public constant KEY_HASH        = keccak256(abi.encode("key"));
    uint64  public constant SUB_ID          = 1;
    uint256 public constant INITIAL_BALANCE = 1_000 ether;

    function setUp() public {
        vm.deal(OWNER,   INITIAL_BALANCE + 100 ether);
        vm.deal(PLAYER1, 1_000 ether);
        vm.deal(PLAYER2, 1_000 ether);

        vm.startPrank(OWNER);
        mockVRF  = new MockVRFCoordinatorV2();
        diceFate = new DiceFate(address(mockVRF), KEY_HASH, SUB_ID);
        diceFate.depositHouse{value: INITIAL_BALANCE}();
        vm.stopPrank();
    }

    // ── Bet placement ────────────────────────────────────────────────────────

    function test_PlaceBet() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.player,       PLAYER1);
        assertEq(bet.amount,       1 ether);
        assertEq(bet.targetNumber, 50);
        assertFalse(bet.resolved);
    }

    function test_PlaceBet_StoresRequestId() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        // The mock VRF assigns sequential request IDs starting at 1.
        assertEq(bet.requestId, 1);
        assertEq(diceFate.requestIdToBetId(1), betId);
    }

    function test_PlaceBet_TracksPlayerBets() public {
        vm.startPrank(PLAYER1);
        uint256 id1 = diceFate.placeBet{value: 1 ether}(50);
        uint256 id2 = diceFate.placeBet{value: 2 ether}(75);
        vm.stopPrank();

        uint256[] memory playerBets = diceFate.getPlayerBets(PLAYER1);
        assertEq(playerBets.length, 2);
        assertEq(playerBets[0], id1);
        assertEq(playerBets[1], id2);
    }

    function test_PlaceBet_ReservesLiquidity() public {
        uint256 balBefore = diceFate.contractBalance();

        vm.prank(PLAYER1);
        diceFate.placeBet{value: 1 ether}(50);

        uint256 maxPayout = diceFate.calculateWinPayout(1 ether, 50);
        assertEq(diceFate.contractBalance(), balBefore - maxPayout);
    }

    // ── Resolution — owner path ──────────────────────────────────────────────

    function test_ResolveBet_Win() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        uint256 balBefore = PLAYER1.balance;

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 24); // (24 % 100) + 1 = 25 < 50 → win

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertTrue(bet.resolved);
        assertTrue(bet.won);
        assertEq(bet.rollResult, 25);

        uint256 expectedPayout = diceFate.calculateWinPayout(1 ether, 50);
        assertEq(PLAYER1.balance - balBefore, expectedPayout);
    }

    function test_ResolveBet_Loss() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        uint256 balBefore = PLAYER1.balance;

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 74); // (74 % 100) + 1 = 75 ≥ 50 → loss

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertTrue(bet.resolved);
        assertFalse(bet.won);
        assertEq(bet.rollResult, 75);
        assertEq(PLAYER1.balance, balBefore); // player receives nothing
    }

    function test_ResolveBet_Loss_HouseCreditsFullBetAmount() public {
        uint256 houseBefore = diceFate.contractBalance();

        vm.prank(PLAYER1);
        diceFate.placeBet{value: 1 ether}(50);

        vm.prank(OWNER);
        diceFate.resolveBet(1, 74); // loss

        // House reclaims its reservation AND the player's bet: net gain = 1 ether.
        assertEq(diceFate.contractBalance(), houseBefore + 1 ether);
    }

    function test_ResolveBet_CannotResolveTwice() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        vm.startPrank(OWNER);
        diceFate.resolveBet(betId, 24);

        vm.expectRevert(abi.encodeWithSelector(DiceFate.BetAlreadyResolved.selector, betId));
        diceFate.resolveBet(betId, 24);
        vm.stopPrank();
    }

    function test_ResolveBet_NotFound() public {
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(DiceFate.BetNotFound.selector, 999));
        diceFate.resolveBet(999, 0);
    }

    // ── Resolution — VRF callback path ───────────────────────────────────────

    /**
     * @dev Tests the production flow end-to-end: VRF coordinator fulfils the
     *      request, triggering fulfillRandomWords, which resolves the bet —
     *      no owner interaction required.
     */
    function test_VRFCallback_Win() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        uint256 requestId = diceFate.getBet(betId).requestId;
        uint256 balBefore = PLAYER1.balance;

        uint256[] memory words = new uint256[](1);
        words[0] = 24; // rollResult = 25 < 50 → win

        // Simulate Chainlink's callback (mockVRF is the authorised coordinator).
        mockVRF.fulfillRandomWords(requestId, words);

        DiceFate.Bet memory resolved = diceFate.getBet(betId);
        assertTrue(resolved.resolved);
        assertTrue(resolved.won);
        assertEq(resolved.rollResult, 25);
        assertEq(PLAYER1.balance - balBefore, diceFate.calculateWinPayout(1 ether, 50));
    }

    function test_VRFCallback_Loss() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        uint256 requestId = diceFate.getBet(betId).requestId;

        uint256[] memory words = new uint256[](1);
        words[0] = 74; // rollResult = 75 ≥ 50 → loss

        mockVRF.fulfillRandomWords(requestId, words);

        DiceFate.Bet memory resolved = diceFate.getBet(betId);
        assertTrue(resolved.resolved);
        assertFalse(resolved.won);
    }

    // ── Input validation ─────────────────────────────────────────────────────

    function test_InvalidTarget_TooLow() public {
        vm.prank(PLAYER1);
        vm.expectRevert(abi.encodeWithSelector(DiceFate.InvalidTarget.selector, 1));
        diceFate.placeBet{value: 1 ether}(1);
    }

    function test_InvalidTarget_TooHigh() public {
        vm.prank(PLAYER1);
        vm.expectRevert(abi.encodeWithSelector(DiceFate.InvalidTarget.selector, 101));
        diceFate.placeBet{value: 1 ether}(101);
    }

    function test_BelowMinimumBet() public {
        vm.prank(PLAYER1);
        vm.expectRevert(
            abi.encodeWithSelector(DiceFate.BelowMinimumBet.selector, 0, diceFate.MIN_BET())
        );
        diceFate.placeBet{value: 0}(50);
    }

    function test_InsufficientHouseBalance() public {
        vm.prank(OWNER);
        diceFate.withdrawHouse(INITIAL_BALANCE);

        uint256 required = diceFate.calculateWinPayout(1 ether, 50);
        vm.prank(PLAYER1);
        vm.expectRevert(
            abi.encodeWithSelector(DiceFate.InsufficientHouseBalance.selector, required, 0)
        );
        diceFate.placeBet{value: 1 ether}(50);
    }

    // ── House management ─────────────────────────────────────────────────────

    function test_HouseDeposit() public {
        vm.prank(OWNER);
        diceFate.depositHouse{value: 100 ether}();
        assertEq(diceFate.contractBalance(), INITIAL_BALANCE + 100 ether);
    }

    function test_HouseWithdraw() public {
        vm.prank(OWNER);
        diceFate.withdrawHouse(100 ether);
        assertEq(diceFate.contractBalance(), INITIAL_BALANCE - 100 ether);
    }

    function test_HouseWithdraw_ExceedsBalance() public {
        vm.prank(OWNER);
        vm.expectRevert(
            abi.encodeWithSelector(
                DiceFate.WithdrawExceedsBalance.selector,
                INITIAL_BALANCE + 1,
                INITIAL_BALANCE
            )
        );
        diceFate.withdrawHouse(INITIAL_BALANCE + 1);
    }

    function test_ReceiveETH() public {
        uint256 balBefore = diceFate.contractBalance();

        vm.prank(PLAYER1);
        (bool ok,) = payable(address(diceFate)).call{value: 50 ether}("");
        assertTrue(ok);

        assertEq(diceFate.contractBalance(), balBefore + 50 ether);
    }

    function test_TransferOwnership() public {
        address newOwner = address(0x99);

        vm.prank(OWNER);
        diceFate.transferOwnership(newOwner);
        assertEq(diceFate.owner(), newOwner);

        // Old owner can no longer call restricted functions.
        vm.prank(OWNER);
        vm.expectRevert(DiceFate.Unauthorized.selector);
        diceFate.depositHouse{value: 0}();
    }

    // ── Multi-player scenarios ───────────────────────────────────────────────

    function test_MultiplePlayersMultipleBets() public {
        vm.startPrank(PLAYER1);
        uint256 bet1 = diceFate.placeBet{value: 1 ether}(50);
        uint256 bet2 = diceFate.placeBet{value: 2 ether}(75);
        vm.stopPrank();

        vm.prank(PLAYER2);
        uint256 bet3 = diceFate.placeBet{value: 0.5 ether}(25);

        vm.startPrank(OWNER);
        diceFate.resolveBet(bet1, 29);  // 30 < 50  → win
        diceFate.resolveBet(bet2, 79);  // 80 ≥ 75  → loss
        diceFate.resolveBet(bet3, 9);   // 10 < 25  → win
        vm.stopPrank();

        assertTrue(diceFate.getBet(bet1).won);
        assertFalse(diceFate.getBet(bet2).won);
        assertTrue(diceFate.getBet(bet3).won);
    }

    // ── Edge cases ───────────────────────────────────────────────────────────

    function test_EdgeCase_RollEqualsTarget_IsLoss() public {
        // Win condition is strictly <, so roll == target is a loss.
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(50);

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 49); // (49 % 100) + 1 = 50; 50 < 50 is false → loss

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.rollResult, 50);
        assertFalse(bet.won);
    }

    function test_EdgeCase_MaxTarget_RollOf100_IsLoss() public {
        // target 100: rolls 1–99 win; only a roll of 100 loses.
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(100);

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 99); // (99 % 100) + 1 = 100; 100 < 100 is false → loss

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertEq(bet.rollResult, 100);
        assertFalse(bet.won);
    }

    function test_EdgeCase_MinTarget_OnlyRollOf1_Wins() public {
        // target 2: only roll = 1 wins; rolls 2–100 lose.
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(2);

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 0); // (0 % 100) + 1 = 1; 1 < 2 → win

        assertTrue(diceFate.getBet(betId).won);
    }

    // ── Payout math ──────────────────────────────────────────────────────────

    function test_MultiplierValues() public view {
        assertEq(diceFate.calculatePayoutMultiplier(10), 111_111); // 100/9  ≈ 11.11x
        assertEq(diceFate.calculatePayoutMultiplier(50), 20_408);  // 100/49 ≈ 2.04x
        assertEq(diceFate.calculatePayoutMultiplier(99), 10_204);  // 100/98 ≈ 1.02x
    }

    function test_LowerTargetHigherPayout() public view {
        uint256 p10 = diceFate.calculateWinPayout(1 ether, 10);
        uint256 p50 = diceFate.calculateWinPayout(1 ether, 50);
        uint256 p99 = diceFate.calculateWinPayout(1 ether, 99);

        assertGt(p10, p50, "target 10 must pay more than target 50");
        assertGt(p50, p99, "target 50 must pay more than target 99");

        assertGt(p10, 10 ether);
        assertLt(p10, 11 ether);
        assertGt(p50, 1.8 ether);
        assertLt(p50, 2.1 ether);
        assertLt(p99, 1 ether);
    }

    function test_HighRiskBetPayout() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(10);

        uint256 balBefore = PLAYER1.balance;

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 4); // roll = 5 < 10 → win

        uint256 expected = diceFate.calculateWinPayout(1 ether, 10);
        assertEq(PLAYER1.balance - balBefore, expected);
        assertGt(expected, 10 ether);
    }

    function test_LowRiskBetPayout() public {
        vm.prank(PLAYER1);
        uint256 betId = diceFate.placeBet{value: 1 ether}(99);

        uint256 balBefore = PLAYER1.balance;

        vm.prank(OWNER);
        diceFate.resolveBet(betId, 49); // roll = 50 < 99 → win

        uint256 expected = diceFate.calculateWinPayout(1 ether, 99);
        assertEq(PLAYER1.balance - balBefore, expected);
        assertLt(expected, 1 ether);
    }
}

// ─── Fuzz tests ───────────────────────────────────────────────────────────────

contract DiceFateFuzzTest is Test {
    DiceFate             public diceFate;
    MockVRFCoordinatorV2 public mockVRF;

    address public constant OWNER  = address(0x1);
    address public constant PLAYER = address(0x10);

    function setUp() public {
        vm.deal(OWNER,  100_000 ether);
        vm.deal(PLAYER, 100_000 ether);

        vm.startPrank(OWNER);
        mockVRF  = new MockVRFCoordinatorV2();
        diceFate = new DiceFate(address(mockVRF), keccak256(abi.encode("key")), 1);
        diceFate.depositHouse{value: 100_000 ether}();
        vm.stopPrank();
    }

    /**
     * @dev Payout should always be positive and strictly less than the gross
     *      (pre-house-edge) value for any valid input combination.
     */
    function testFuzz_PayoutProperties(uint8 rawTarget, uint128 rawAmount) public view {
        uint8   target = uint8(bound(uint256(rawTarget), 2, 100));
        uint256 amount = bound(uint256(rawAmount), diceFate.MIN_BET(), 100 ether);

        uint256 multiplier = diceFate.calculatePayoutMultiplier(target);
        uint256 gross      = (amount * multiplier) / diceFate.BASIS_POINTS();
        uint256 payout     = diceFate.calculateWinPayout(amount, target);

        assertGt(payout, 0,     "payout must be positive");
        assertLt(payout, gross, "house edge must reduce payout below gross");
    }

    /**
     * @dev Risk ordering invariant: a lower target (harder to win) must always
     *      yield a higher payout than a higher target, for any bet size.
     */
    function testFuzz_RiskOrdering(
        uint8   rawLow,
        uint8   rawHigh,
        uint128 rawAmount
    ) public view {
        uint8   low    = uint8(bound(uint256(rawLow),  2,  50));
        uint8   high   = uint8(bound(uint256(rawHigh), 51, 100));
        uint256 amount = bound(uint256(rawAmount), diceFate.MIN_BET(), 100 ether);

        assertGt(
            diceFate.calculateWinPayout(amount, low),
            diceFate.calculateWinPayout(amount, high),
            "lower target must always pay more"
        );
    }

    /**
     * @dev End-to-end fuzz: any valid bet should settle cleanly and the core
     *      solvency invariant (contractBalance ≤ address(this).balance) must
     *      hold both before and after resolution.
     */
    function testFuzz_BetSettlement(uint8 rawTarget, uint128 rawAmount, uint256 randomSeed) public {
        uint8   target = uint8(bound(uint256(rawTarget), 2, 100));
        uint256 amount = bound(uint256(rawAmount), diceFate.MIN_BET(), 10 ether);

        uint256 playerBefore = PLAYER.balance;

        vm.prank(PLAYER);
        uint256 betId = diceFate.placeBet{value: amount}(target);

        // Solvency must hold even while a bet is pending.
        assertLe(diceFate.contractBalance(), address(diceFate).balance);

        vm.prank(OWNER);
        diceFate.resolveBet(betId, randomSeed);

        DiceFate.Bet memory bet = diceFate.getBet(betId);
        assertTrue(bet.resolved);

        // After placeBet the player already spent `amount`; the expected balance is
        // (playerBefore - amount) + payout, where payout = 0 on a loss.
        uint256 payout = bet.won ? diceFate.calculateWinPayout(amount, target) : 0;
        assertEq(PLAYER.balance, playerBefore - amount + payout, "unexpected player balance after resolution");

        // Solvency must hold after resolution too.
        assertLe(diceFate.contractBalance(), address(diceFate).balance);
    }

    /**
     * @dev House edge validation: the retained amount (gross - payout) should
     *      be within 1 wei of exactly 5% of the gross payout.
     */
    function testFuzz_HouseEdgeApplied(uint8 rawTarget, uint128 rawAmount) public view {
        uint8   target = uint8(bound(uint256(rawTarget), 2, 100));
        uint256 amount = bound(uint256(rawAmount), diceFate.MIN_BET(), 100 ether);

        uint256 multiplier   = diceFate.calculatePayoutMultiplier(target);
        uint256 gross        = (amount * multiplier) / diceFate.BASIS_POINTS();
        uint256 payout       = diceFate.calculateWinPayout(amount, target);
        uint256 retained     = gross - payout;
        uint256 expectedEdge = (gross * diceFate.HOUSE_EDGE_BPS()) / diceFate.BASIS_POINTS();

        // ±1 wei tolerance for integer truncation in the nested multiplications.
        assertApproxEqAbs(retained, expectedEdge, 1);
    }
}

// ─── Invariant tests ──────────────────────────────────────────────────────────

/**
 * @dev Handler for the invariant test suite. Foundry's invariant runner calls
 *      these functions with random inputs, trying to drive the contract into a
 *      state that violates the declared invariants.
 */
contract DiceFateHandler is Test {
    DiceFate public diceFate;
    address  public owner;

    uint256[] internal _pendingBetIds;

    constructor(DiceFate _diceFate, address _owner) {
        diceFate = _diceFate;
        owner    = _owner;
    }

    // Required so the handler can receive ETH when it wins a bet.
    receive() external payable {}

    function placeBet(uint8 rawTarget, uint128 rawAmount) external {
        uint8   target = uint8(bound(uint256(rawTarget), 2, 100));
        uint256 amount = bound(uint256(rawAmount), diceFate.MIN_BET(), 1 ether);

        // Skip if house can't cover the potential payout.
        if (diceFate.contractBalance() < diceFate.calculateWinPayout(amount, target)) return;

        vm.deal(address(this), amount);
        uint256 betId = diceFate.placeBet{value: amount}(target);
        _pendingBetIds.push(betId);
    }

    function resolveBet(uint256 randomSeed) external {
        if (_pendingBetIds.length == 0) return;

        // Swap-remove to avoid an O(n) array shift.
        uint256 idx   = randomSeed % _pendingBetIds.length;
        uint256 betId = _pendingBetIds[idx];
        _pendingBetIds[idx] = _pendingBetIds[_pendingBetIds.length - 1];
        _pendingBetIds.pop();

        vm.prank(owner);
        diceFate.resolveBet(betId, randomSeed);
    }
}

contract DiceFateInvariantTest is StdInvariant, Test {
    DiceFate             public diceFate;
    DiceFateHandler      public handler;
    MockVRFCoordinatorV2 public mockVRF;

    address public constant OWNER = address(0x1);

    function setUp() public {
        vm.deal(OWNER, 10_000 ether);

        vm.startPrank(OWNER);
        mockVRF  = new MockVRFCoordinatorV2();
        diceFate = new DiceFate(address(mockVRF), keccak256(abi.encode("key")), 1);
        diceFate.depositHouse{value: 10_000 ether}();
        vm.stopPrank();

        handler = new DiceFateHandler(diceFate, OWNER);
        targetContract(address(handler));
    }

    /**
     * @dev The tracked house liquidity must never exceed the actual ETH held.
     *      A violation means the contract cannot honour its pending obligations.
     */
    function invariant_SolvencyHolds() public view {
        assertLe(
            diceFate.contractBalance(),
            address(diceFate).balance,
            "contractBalance must never exceed actual ETH balance"
        );
    }

    /**
     * @dev nextBetId should grow monotonically and never reset to 0.
     */
    function invariant_BetIdMonotonicallyIncreases() public view {
        assertGt(diceFate.nextBetId(), 0, "nextBetId should never be 0");
    }
}
