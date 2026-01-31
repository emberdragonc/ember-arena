export const EMBER_ARENA_ADDRESS = '0xcB1Aa33b4f8f4E2e113C3c41c92e59DF9Bfe6e9c' as const;

export const EMBER_ARENA_ABI = [
  {
    type: "function",
    name: "BURN_BPS",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "MIN_BACKING_AMOUNT",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "backIdea",
    inputs: [
      { name: "_ideaId", type: "uint256" },
      { name: "_amount", type: "uint256" },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "calculatePotentialWinnings",
    inputs: [
      { name: "_roundId", type: "uint256" },
      { name: "_ideaId", type: "uint256" },
      { name: "_backer", type: "address" },
    ],
    outputs: [{ name: "potentialWinnings", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "claimWinnings",
    inputs: [{ name: "_roundId", type: "uint256" }],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "currentRoundId",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "emberToken",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getCurrentPhase",
    inputs: [],
    outputs: [{ name: "phase", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getCurrentRound",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "roundId", type: "uint256" },
          { name: "submissionStart", type: "uint256" },
          { name: "votingStart", type: "uint256" },
          { name: "votingEnd", type: "uint256" },
          { name: "totalPool", type: "uint256" },
          { name: "winningIdeaId", type: "uint256" },
          { name: "resolved", type: "bool" },
          { name: "ideaCount", type: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getIdea",
    inputs: [{ name: "_ideaId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "ideaId", type: "uint256" },
          { name: "roundId", type: "uint256" },
          { name: "creator", type: "address" },
          { name: "description", type: "string" },
          { name: "metadata", type: "string" },
          { name: "totalBacking", type: "uint256" },
          { name: "isWinner", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRoundIdeaIds",
    inputs: [{ name: "_roundId", type: "uint256" }],
    outputs: [{ name: "", type: "uint256[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getRoundInfo",
    inputs: [{ name: "_roundId", type: "uint256" }],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "roundId", type: "uint256" },
          { name: "submissionStart", type: "uint256" },
          { name: "votingStart", type: "uint256" },
          { name: "votingEnd", type: "uint256" },
          { name: "totalPool", type: "uint256" },
          { name: "winningIdeaId", type: "uint256" },
          { name: "resolved", type: "bool" },
          { name: "ideaCount", type: "uint256" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getUserBackingForIdea",
    inputs: [
      { name: "_user", type: "address" },
      { name: "_roundId", type: "uint256" },
      { name: "_ideaId", type: "uint256" },
    ],
    outputs: [
      {
        name: "",
        type: "tuple",
        components: [
          { name: "backer", type: "address" },
          { name: "ideaId", type: "uint256" },
          { name: "amount", type: "uint256" },
          { name: "claimed", type: "bool" },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "getUserBackings",
    inputs: [
      { name: "_user", type: "address" },
      { name: "_roundId", type: "uint256" },
    ],
    outputs: [{ name: "backedIdeaIds", type: "uint256[]" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "minBackingThreshold",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "submitIdea",
    inputs: [
      { name: "_description", type: "string" },
      { name: "_metadata", type: "string" },
    ],
    outputs: [{ name: "ideaId", type: "uint256" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "totalIdeas",
    inputs: [],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "event",
    name: "IdeaBacked",
    inputs: [
      { name: "roundId", type: "uint256", indexed: true },
      { name: "ideaId", type: "uint256", indexed: true },
      { name: "backer", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "IdeaSubmitted",
    inputs: [
      { name: "roundId", type: "uint256", indexed: true },
      { name: "ideaId", type: "uint256", indexed: true },
      { name: "creator", type: "address", indexed: true },
      { name: "description", type: "string", indexed: false },
    ],
  },
  {
    type: "event",
    name: "WinnerSelected",
    inputs: [
      { name: "roundId", type: "uint256", indexed: true },
      { name: "winningIdeaId", type: "uint256", indexed: true },
      { name: "creator", type: "address", indexed: true },
      { name: "totalPool", type: "uint256", indexed: false },
    ],
  },
  {
    type: "event",
    name: "WinningsClaimed",
    inputs: [
      { name: "roundId", type: "uint256", indexed: true },
      { name: "backer", type: "address", indexed: true },
      { name: "amount", type: "uint256", indexed: false },
    ],
  },
] as const;

// ERC20 ABI for token approval
export const ERC20_ABI = [
  {
    type: "function",
    name: "approve",
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "", type: "bool" }],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "allowance",
    inputs: [
      { name: "owner", type: "address" },
      { name: "spender", type: "address" },
    ],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "balanceOf",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "symbol",
    inputs: [],
    outputs: [{ name: "", type: "string" }],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "decimals",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
    stateMutability: "view",
  },
] as const;
