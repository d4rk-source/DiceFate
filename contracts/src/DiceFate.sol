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

contract DiceFate is VRFConsumerBaseV2 {
    // VRF Variables
    VRFCoordinatorV2Interface public vrfCoordinator;
    bytes32 public keyHash;
    uint64 public subId;
    uint16 public constant REQUEST_CONFIRMATIONS = 3;
    uint32 public constant CALLBACK_GAS_LIMIT = 100000;
    uint32 public constant NUM_WORDS = 1;

    // Bet Constants
    uint256 public constant PAYOUT_MULTIPLIER = 195; // 1.95x (in basis points)
    uint256 public constant HOUSE_EDGE_BPS = 500; // 5% (in basis points)
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public constant DICE_RANGE = 100; // 1-100

    // Bet struct
    struct Bet {
        address player;
        uint256 amount;
        uint8 targetNumber; // roll under this number (1-100)
        uint256 rollResult;
        bool resolved;
        bool won;
    }

    // State
    mapping(uint256 => Bet) public bets;
    mapping(address => uint256[]) public playerBets;
    uint256 public nextBetId;
    uint256 public contractBalance;
    address public owner;

    // Events
    event BetPlaced(
        uint256 indexed betId,
        address indexed player,
        uint256 amount,
        uint8 targetNumber,
        uint256 requestId
    );
    event BetResolved(
        uint256 indexed betId,
        address indexed player,
        uint256 rollResult,
        bool won,
        uint256 payout
    );
    event HouseDeposit(address indexed depositor, uint256 amount);
    event HouseWithdraw(address indexed withdrawer, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint64 _subId
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        owner = msg.sender;
        vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subId = _subId;
        nextBetId = 1;
    }

    /**
     * @notice Place a bet on a target number
     * @param targetNumber Number to roll under (1-100)
     */
    function placeBet(uint8 targetNumber) external payable returns (uint256) {
        require(msg.value > 0, "Bet must be greater than 0");
        require(
            targetNumber >= 2 && targetNumber <= 100,
            "Target must be between 2-100"
        );
        require(
            contractBalance >= (msg.value * PAYOUT_MULTIPLIER) / BASIS_POINTS,
            "Insufficient house balance"
        );

        uint256 betId = nextBetId++;

        Bet storage bet = bets[betId];
        bet.player = msg.sender;
        bet.amount = msg.value;
        bet.targetNumber = targetNumber;
        bet.resolved = false;

        playerBets[msg.sender].push(betId);
        contractBalance -= (msg.value * PAYOUT_MULTIPLIER) / BASIS_POINTS; // Reserve funds

        // Request random number
        uint256 requestId = vrfCoordinator.requestRandomWords(
            keyHash,
            subId,
            REQUEST_CONFIRMATIONS,
            CALLBACK_GAS_LIMIT,
            NUM_WORDS
        );

        emit BetPlaced(betId, msg.sender, msg.value, targetNumber, requestId);
        return betId;
    }

    /**
     * @notice Callback function called by VRF coordinator
     */
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        // Find the bet associated with this request
        // In production, you'd map requestId to betId
        // For this simplified version, we'll need to handle this differently
        // This is called by the VRF coordinator
    }

    /**
     * @notice Simulate bet resolution (for testing/local anvil)
     */
    function resolveBet(
        uint256 betId,
        uint256 randomNumber
    ) external onlyOwner {
        Bet storage bet = bets[betId];
        require(!bet.resolved, "Bet already resolved");

        uint256 rollResult = (randomNumber % DICE_RANGE) + 1; // 1-100
        bet.rollResult = rollResult;
        bet.resolved = true;

        uint256 payout = 0;
        if (rollResult < bet.targetNumber) {
            bet.won = true;
            // Calculate payout: bet * 1.95 * (1 - 0.05)
            payout = (bet.amount * PAYOUT_MULTIPLIER) / BASIS_POINTS;
            payout = (payout * (BASIS_POINTS - HOUSE_EDGE_BPS)) / BASIS_POINTS;

            // Transfer payout to player
            (bool success, ) = payable(bet.player).call{value: payout}("");
            require(success, "Transfer failed");

            contractBalance += bet.amount; // Add bet to house
        } else {
            bet.won = false;
            contractBalance += (bet.amount * PAYOUT_MULTIPLIER) / BASIS_POINTS; // Return reserved funds
        }

        emit BetResolved(betId, bet.player, rollResult, bet.won, payout);
    }

    /**
     * @notice Deposit ETH to house balance
     */
    function depositHouse() external payable onlyOwner {
        contractBalance += msg.value;
        emit HouseDeposit(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw from house balance
     */
    function withdrawHouse(uint256 amount) external onlyOwner {
        require(amount <= contractBalance, "Insufficient balance");
        contractBalance -= amount;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        emit HouseWithdraw(msg.sender, amount);
    }

    /**
     * @notice Get all bets for a player
     */
    function getPlayerBets(
        address player
    ) external view returns (uint256[] memory) {
        return playerBets[player];
    }

    /**
     * @notice Get bet details
     */
    function getBet(uint256 betId) external view returns (Bet memory) {
        return bets[betId];
    }

    /**
     * @notice Receive function to accept ETH transfers
     */
    receive() external payable {
        contractBalance += msg.value;
    }
}
