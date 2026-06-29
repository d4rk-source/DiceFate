// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {VRFConsumerBaseV2} from "./VRFConsumerBaseV2.sol";

interface VRFCoordinatorV2Interface {
    function requestRandomWords(
        bytes32 keyHash,
        uint64 subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}

/**
 * @title  DiceFate
 * @notice Provably-fair on-chain dice betting backed by Chainlink VRF v2.
 *
 *         Players choose a roll-under target (2–100). If the random roll lands
 *         below that target, they win. The payout multiplier scales inversely
 *         with win probability so the house maintains an exact 5% edge at every
 *         risk level — no fixed 2x cap, just pure math.
 *
 *         Production flow  : placeBet → VRF request → fulfillRandomWords (auto)
 *         Local/test flow  : placeBet → rollDice (player-triggered, block entropy)
 *
 * @dev    Security notes:
 *         - Checks-Effects-Interactions is applied throughout.
 *         - A simple reentrancy guard protects all state-mutating externals.
 *         - Custom errors are used instead of require strings for gas savings.
 *         - This contract is for educational/demo purposes — audit before mainnet.
 */
contract DiceFate is VRFConsumerBaseV2 {
    // ── Custom errors ────────────────────────────────────────────────────────
    error InvalidTarget(uint8 target);
    error BelowMinimumBet(uint256 sent, uint256 minimum);
    error InsufficientHouseBalance(uint256 required, uint256 available);
    error BetAlreadyResolved(uint256 betId);
    error BetNotFound(uint256 betId);
    error Unauthorized();
    error WithdrawExceedsBalance(uint256 requested, uint256 available);
    error TransferFailed();
    error Reentrant();

    // ── Chainlink VRF config ─────────────────────────────────────────────────
    VRFCoordinatorV2Interface public immutable vrfCoordinator;
    bytes32                   public immutable keyHash;
    uint64                    public immutable subId;

    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT    = 100_000;
    uint32 public constant NUM_WORDS             = 1;

    // ── Game parameters ──────────────────────────────────────────────────────
    uint256 public constant HOUSE_EDGE_BPS = 500;        // 5 % in basis points
    uint256 public constant BASIS_POINTS   = 10_000;
    uint256 public constant DICE_RANGE     = 100;        // outcomes: 1–100 inclusive
    uint256 public constant MIN_BET        = 0.001 ether;

    // ── Bet record ───────────────────────────────────────────────────────────
    struct Bet {
        address player;
        uint256 amount;
        uint8   targetNumber; // win condition: roll < targetNumber
        uint256 requestId;    // Chainlink VRF request id (0 for manual-resolved bets)
        uint256 rollResult;   // populated after resolution; 0 while pending
        bool    resolved;
        bool    won;
    }

    // ── State ────────────────────────────────────────────────────────────────
    address public owner;
    uint256 public nextBetId;

    // Tracks available house liquidity. Decremented when funds are reserved for
    // a pending bet; reconciled on resolution. Invariant: contractBalance ≤ address(this).balance
    uint256 public contractBalance;

    mapping(uint256 => Bet)       public bets;
    mapping(address => uint256[]) public playerBets;

    // Links a Chainlink VRF request back to its bet so fulfillRandomWords knows what to resolve.
    mapping(uint256 => uint256) public requestIdToBetId;

    // ── Events ───────────────────────────────────────────────────────────────
    event BetPlaced(
        uint256 indexed betId,
        address indexed player,
        uint256 amount,
        uint8   targetNumber,
        uint256 requestId
    );
    event BetResolved(
        uint256 indexed betId,
        address indexed player,
        uint256 rollResult,
        bool    won,
        uint256 payout
    );
    event HouseDeposit(address indexed depositor, uint256 amount);
    event HouseWithdraw(address indexed withdrawer, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ── Reentrancy guard ─────────────────────────────────────────────────────
    bool private _locked;

    modifier nonReentrant() {
        if (_locked) revert Reentrant();
        _locked = true;
        _;
        _locked = false;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // ── Constructor ──────────────────────────────────────────────────────────
    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64  _subId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        owner          = msg.sender;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash        = _keyHash;
        subId          = _subId;
        nextBetId      = 1; // 0 is reserved as "not found" sentinel in requestIdToBetId
    }

    // ── Pure math helpers ────────────────────────────────────────────────────

    /**
     * @notice Fair-odds multiplier for a given target, expressed in basis points.
     * @dev    multiplier = DICE_RANGE / (targetNumber - 1)
     *         e.g. target 50 → 100/49 ≈ 2.04x (20408 bps)
     *              target 10 → 100/9  ≈ 11.1x (111111 bps)
     */
    function calculatePayoutMultiplier(uint8 targetNumber) public pure returns (uint256) {
        if (targetNumber < 2 || targetNumber > 100) revert InvalidTarget(targetNumber);
        return (DICE_RANGE * BASIS_POINTS) / (targetNumber - 1);
    }

    /**
     * @notice Player payout on a win, after the 5% house edge is applied.
     */
    function calculateWinPayout(uint256 betAmount, uint8 targetNumber) public pure returns (uint256) {
        uint256 multiplier = calculatePayoutMultiplier(targetNumber);
        uint256 gross      = (betAmount * multiplier) / BASIS_POINTS;
        return (gross * (BASIS_POINTS - HOUSE_EDGE_BPS)) / BASIS_POINTS;
    }

    /**
     * @notice Win probability in basis points. Winning outcomes: roll ∈ [1, targetNumber-1].
     * @dev    P(win) = (targetNumber - 1) / DICE_RANGE
     */
    function winProbabilityBps(uint8 targetNumber) external pure returns (uint256) {
        if (targetNumber < 2 || targetNumber > 100) revert InvalidTarget(targetNumber);
        return ((targetNumber - 1) * BASIS_POINTS) / DICE_RANGE;
    }

    // ── View helpers ─────────────────────────────────────────────────────────

    function getPlayerBets(address player) external view returns (uint256[] memory) {
        return playerBets[player];
    }

    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    // ── Core game ─────────────────────────────────────────────────────────────

    /**
     * @notice Place a bet and request randomness from Chainlink VRF.
     * @param  targetNumber  Roll-under threshold (2–100). Lower = higher risk & payout.
     * @return betId         Unique identifier for this bet.
     */
    function placeBet(uint8 targetNumber) external payable nonReentrant returns (uint256 betId) {
        if (msg.value < MIN_BET) revert BelowMinimumBet(msg.value, MIN_BET);
        if (targetNumber < 2 || targetNumber > 100) revert InvalidTarget(targetNumber);

        uint256 maxPayout = calculateWinPayout(msg.value, targetNumber);
        if (contractBalance < maxPayout) revert InsufficientHouseBalance(maxPayout, contractBalance);

        // Reserve house liquidity upfront; reconciled in _resolveBet.
        contractBalance -= maxPayout;

        betId = nextBetId++;

        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        bets[betId] = Bet({
            player:       msg.sender,
            amount:       msg.value,
            targetNumber: targetNumber,
            requestId:    requestId,
            rollResult:   0,
            resolved:     false,
            won:          false
        });

        playerBets[msg.sender].push(betId);
        requestIdToBetId[requestId] = betId;

        emit BetPlaced(betId, msg.sender, msg.value, targetNumber, requestId);
    }

    /**
     * @notice Chainlink VRF callback — the production resolution path.
     * @dev    Called by the VRF coordinator after randomness is generated.
     *         Access is enforced by VRFConsumerBaseV2.rawFulfillRandomWords.
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 betId = requestIdToBetId[requestId];
        // nextBetId starts at 1, so 0 means no bet is mapped to this request.
        if (betId == 0) revert BetNotFound(requestId);
        _resolveBet(betId, randomWords[0]);
    }

    /**
     * @notice Owner-triggered resolution for testing the VRF callback path locally.
     * @dev    Lets the owner supply an arbitrary seed, replicating what the VRF coordinator
     *         would send. Remove or gate before any mainnet deployment.
     */
    function resolveBet(uint256 betId, uint256 randomNumber) external onlyOwner nonReentrant {
        if (bets[betId].player == address(0)) revert BetNotFound(betId);
        _resolveBet(betId, randomNumber);
    }

    /**
     * @notice Player-triggered resolution using block entropy — for local dev play.
     * @dev    NOT safe for production. block.prevrandao can be influenced by validators,
     *         so any real deployment must use the VRF path (fulfillRandomWords) instead.
     *         Entropy is mixed with bet-specific data so different bets get different rolls
     *         even within the same block.
     */
    function rollDice(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        if (bet.player == address(0)) revert BetNotFound(betId);
        if (bet.player != msg.sender) revert Unauthorized();

        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.prevrandao,
            msg.sender,
            betId,
            block.timestamp
        )));
        _resolveBet(betId, seed);
    }

    // ── House management ──────────────────────────────────────────────────────

    /**
     * @notice Deposit ETH as house liquidity. Only callable by owner.
     */
    function depositHouse() external payable onlyOwner {
        contractBalance += msg.value;
        emit HouseDeposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw house liquidity. Cannot withdraw funds reserved for pending bets.
     */
    function withdrawHouse(uint256 amount) external onlyOwner nonReentrant {
        if (amount > contractBalance) revert WithdrawExceedsBalance(amount, contractBalance);
        contractBalance -= amount;
        _sendEth(msg.sender, amount);
        emit HouseWithdraw(msg.sender, amount);
    }

    /**
     * @notice Transfer contract ownership.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert Unauthorized();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Accepts direct ETH transfers as anonymous house top-ups.
     */
    receive() external payable {
        contractBalance += msg.value;
        emit HouseDeposit(msg.sender, msg.value);
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    /**
     * @dev Shared resolution logic for both the VRF callback and the manual path.
     *
     *      Accounting recap:
     *        placeBet    → contractBalance -= maxPayout  (reservation)
     *                      contract receives +bet.amount (msg.value)
     *        win         → payout sent to player; house offsets with bet.amount
     *                      contractBalance += bet.amount
     *        loss        → reservation returned + house claims bet
     *                      contractBalance += reserved + bet.amount
     *
     *      Invariant maintained: contractBalance == address(this).balance
     *      whenever no bets are pending.
     *
     *      CEI order: checks → effects (state) → interaction (ETH transfer).
     */
    function _resolveBet(uint256 betId, uint256 randomSeed) internal {
        Bet storage bet = bets[betId];
        if (bet.resolved) revert BetAlreadyResolved(betId);

        uint256 rollResult = (randomSeed % DICE_RANGE) + 1; // maps to [1, 100]
        uint256 reserved   = calculateWinPayout(bet.amount, bet.targetNumber);

        // Effects — write all state before any external call.
        bet.rollResult = rollResult;
        bet.resolved   = true;

        uint256 payout;

        if (rollResult < bet.targetNumber) {
            bet.won = true;
            payout  = reserved;
            // House receives the player's bet as partial offset against the payout.
            contractBalance += bet.amount;
            // Interaction — send after all state is committed.
            _sendEth(bet.player, payout);
        } else {
            // House reclaims the reservation and keeps the player's bet.
            contractBalance += reserved + bet.amount;
        }

        emit BetResolved(betId, bet.player, rollResult, bet.won, payout);
    }

    function _sendEth(address to, uint256 amount) internal {
        (bool ok,) = payable(to).call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
