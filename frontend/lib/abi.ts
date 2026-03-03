export const DICE_FATE_ABI = [
  {
    type: "constructor",
    inputs: [
      { name: "_vrfCoordinator", type: "address" },
      { name: "_keyHash", type: "bytes32" },
      { name: "_subId", type: "uint64" }
    ]
  },
  {
    type: "function",
    name: "placeBet",
    inputs: [{ name: "targetNumber", type: "uint8" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "resolveBet",
    inputs: [
      { name: "betId", type: "uint256" },
      { name: "randomNumber", type: "uint256" }
    ],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "getBet",
    inputs: [{ name: "betId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "player", type: "address" },
          { name: "amount", type: "uint256" },
          { name: "targetNumber", type: "uint8" },
          { name: "rollResult", type: "uint256" },
          { name: "resolved", type: "bool" },
          { name: "won", type: "bool" }
        ],
        internalType: "struct DiceFate.Bet"
      }
    ],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "getPlayerBets",
    inputs: [{ name: "player", type: "address" }],
    outputs: [{ name: "", type: "uint256[]" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "depositHouse",
    inputs: [],
    outputs: [],
    stateMutability: "payable"
  },
  {
    type: "function",
    name: "withdrawHouse",
    inputs: [{ name: "amount", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable"
  },
  {
    type: "function",
    name: "contractBalance",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view"
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view"
  },
  {
    type: "event",
    name: "BetPlaced",
    inputs: [
      { name: "betId", type: "uint256", indexed: true },
      { name: "player", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
      { name: "targetNumber", type: "uint8", indexed: false },
      { name: "requestId", type: "uint256", indexed: false }
    ]
  },
  {
    type: "event",
    name: "BetResolved",
    inputs: [
      { name: "betId", type: "uint256", indexed: true },
      { name: "player", type: "address", indexed: true },
      { name: "rollResult", type: "uint256", indexed: false },
      { name: "won", type: "bool", indexed: false },
      { name: "payout", type: "uint256", indexed: false }
    ]
  }
];
