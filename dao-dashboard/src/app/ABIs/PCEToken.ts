export const PCE_ABI = [
  {
    type: 'function',
    name: 'DECREASE_RATE',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'DECREASE_RATE_BASE',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'DOMAIN_SEPARATOR',
    inputs: [],
    outputs: [{ name: '', type: 'bytes32', internalType: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'INITIAL_FACTOR',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'allowance',
    inputs: [
      { name: 'owner', type: 'address', internalType: 'address' },
      { name: 'spender', type: 'address', internalType: 'address' },
    ],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'approve',
    inputs: [
      { name: 'spender', type: 'address', internalType: 'address' },
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'balanceOf',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'burn',
    inputs: [{ name: 'amount', type: 'uint256', internalType: 'uint256' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'burnFrom',
    inputs: [
      { name: 'account', type: 'address', internalType: 'address' },
      { name: 'amount', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'checkpoints',
    inputs: [
      { name: 'account', type: 'address', internalType: 'address' },
      { name: 'pos', type: 'uint32', internalType: 'uint32' },
    ],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct VotesUpgradeable.Checkpoint',
        components: [
          { name: 'fromBlock', type: 'uint32', internalType: 'uint32' },
          { name: 'votes', type: 'uint224', internalType: 'uint224' },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'createToken',
    inputs: [
      {
        name: 'tokenInfo',
        type: 'tuple',
        internalType: 'struct PCEToken.TokenInfo',
        components: [
          { name: 'name', type: 'string', internalType: 'string' },
          { name: 'symbol', type: 'string', internalType: 'string' },
          {
            name: 'amountToExchange',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'dilutionFactor',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'decreaseIntervalDays',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'afterDecreaseBp',
            type: 'uint16',
            internalType: 'uint16',
          },
          {
            name: 'maxIncreaseOfTotalSupplyBp',
            type: 'uint16',
            internalType: 'uint16',
          },
          {
            name: 'maxIncreaseBp',
            type: 'uint16',
            internalType: 'uint16',
          },
          {
            name: 'maxUsageBp',
            type: 'uint16',
            internalType: 'uint16',
          },
          { name: 'changeBp', type: 'uint16', internalType: 'uint16' },
          {
            name: 'incomeExchangeAllowMethod',
            type: 'uint8',
            internalType: 'enum ExchangeAllowMethod',
          },
          {
            name: 'outgoExchangeAllowMethod',
            type: 'uint8',
            internalType: 'enum ExchangeAllowMethod',
          },
          {
            name: 'incomeTargetTokens',
            type: 'address[]',
            internalType: 'address[]',
          },
          {
            name: 'outgoTargetTokens',
            type: 'address[]',
            internalType: 'address[]',
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'decimals',
    inputs: [],
    outputs: [{ name: '', type: 'uint8', internalType: 'uint8' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'decreaseAllowance',
    inputs: [
      { name: 'spender', type: 'address', internalType: 'address' },
      {
        name: 'subtractedValue',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'delegate',
    inputs: [{ name: 'delegatee', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'delegateBySig',
    inputs: [
      { name: 'delegatee', type: 'address', internalType: 'address' },
      { name: 'nonce', type: 'uint256', internalType: 'uint256' },
      { name: 'expiry', type: 'uint256', internalType: 'uint256' },
      { name: 'v', type: 'uint8', internalType: 'uint8' },
      { name: 'r', type: 'bytes32', internalType: 'bytes32' },
      { name: 's', type: 'bytes32', internalType: 'bytes32' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'delegates',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'epochTime',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'faucet',
    inputs: [],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getBlockBaseFee',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getCurrentFactor',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getDepositedPCETokens',
    inputs: [
      {
        name: 'communityToken',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getElapsedMinutes',
    inputs: [
      { name: '_start', type: 'uint256', internalType: 'uint256' },
      { name: '_end', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'getExchangeRate',
    inputs: [
      {
        name: 'communityToken',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getLocalToken',
    inputs: [
      {
        name: 'communityToken',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      {
        name: '',
        type: 'tuple',
        internalType: 'struct Utils.LocalToken',
        components: [
          { name: 'isExists', type: 'bool', internalType: 'bool' },
          {
            name: 'exchangeRate',
            type: 'uint256',
            internalType: 'uint256',
          },
          {
            name: 'depositedPCEToken',
            type: 'uint256',
            internalType: 'uint256',
          },
        ],
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getMetaTransactionFee',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getNativeTokenToPceTokenRate',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPastTotalSupply',
    inputs: [{ name: 'blockNumber', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getPastVotes',
    inputs: [
      { name: 'account', type: 'address', internalType: 'address' },
      { name: 'blockNumber', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getSwapRate',
    inputs: [{ name: 'toToken', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getTokens',
    inputs: [],
    outputs: [{ name: '', type: 'address[]', internalType: 'address[]' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'getVotes',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'hasDecreaseTimeWithin',
    inputs: [
      { name: '_start', type: 'uint256', internalType: 'uint256' },
      { name: '_end', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'increaseAllowance',
    inputs: [
      { name: 'spender', type: 'address', internalType: 'address' },
      { name: 'addedValue', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'initialize',
    inputs: [
      { name: '_name', type: 'string', internalType: 'string' },
      { name: '_symbol', type: 'string', internalType: 'string' },
      {
        name: 'communityTokenAddress',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'isCommunityToken',
    inputs: [{ name: '', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'isWednesdayBetween',
    inputs: [
      { name: 'start', type: 'uint256', internalType: 'uint256' },
      { name: 'end', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    name: 'lastDecreaseTime',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'lastModifiedFactor',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'localTokens',
    inputs: [
      {
        name: 'deployedAddress',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [
      { name: 'isExists', type: 'bool', internalType: 'bool' },
      {
        name: 'exchangeRate',
        type: 'uint256',
        internalType: 'uint256',
      },
      {
        name: 'depositedPCEToken',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'metaTransactionGas',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'metaTransactionPriorityFee',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'mint',
    inputs: [
      { name: 'to', type: 'address', internalType: 'address' },
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'moveVotingPower',
    inputs: [
      { name: 'from', type: 'address', internalType: 'address' },
      { name: 'to', type: 'address', internalType: 'address' },
      { name: 'amount', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'name',
    inputs: [],
    outputs: [{ name: '', type: 'string', internalType: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'nativeTokenToPceTokenRate',
    inputs: [],
    outputs: [{ name: '', type: 'uint160', internalType: 'uint160' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'nonces',
    inputs: [{ name: 'owner', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'numCheckpoints',
    inputs: [{ name: 'account', type: 'address', internalType: 'address' }],
    outputs: [{ name: '', type: 'uint32', internalType: 'uint32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'owner',
    inputs: [],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'permit',
    inputs: [
      { name: 'owner', type: 'address', internalType: 'address' },
      { name: 'spender', type: 'address', internalType: 'address' },
      { name: 'value', type: 'uint256', internalType: 'uint256' },
      { name: 'deadline', type: 'uint256', internalType: 'uint256' },
      { name: 'v', type: 'uint8', internalType: 'uint8' },
      { name: 'r', type: 'bytes32', internalType: 'bytes32' },
      { name: 's', type: 'bytes32', internalType: 'bytes32' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'renounceOwnership',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setCommunityTokenAddress',
    inputs: [
      {
        name: 'communityTokenAddress',
        type: 'address',
        internalType: 'address',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMetaTransactionGas',
    inputs: [
      {
        name: '_metaTransactionGas',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setMetaTransactionPriorityFee',
    inputs: [
      {
        name: '_metaTransactionPriorityFee',
        type: 'uint256',
        internalType: 'uint256',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'setNativeTokenToPceTokenRate',
    inputs: [
      {
        name: '_nativeTokenToPceTokenRate',
        type: 'uint160',
        internalType: 'uint160',
      },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'swapFromLocalToken',
    inputs: [
      { name: 'fromToken', type: 'address', internalType: 'address' },
      { name: 'amountToSwap', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'swapToLocalToken',
    inputs: [
      { name: 'toToken', type: 'address', internalType: 'address' },
      { name: 'amountToSwap', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'symbol',
    inputs: [],
    outputs: [{ name: '', type: 'string', internalType: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'tokens',
    inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    outputs: [{ name: '', type: 'address', internalType: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'totalSupply',
    inputs: [],
    outputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'transfer',
    inputs: [
      { name: 'receiver', type: 'address', internalType: 'address' },
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'transferFrom',
    inputs: [
      { name: 'sender', type: 'address', internalType: 'address' },
      { name: 'receiver', type: 'address', internalType: 'address' },
      { name: 'balance', type: 'uint256', internalType: 'uint256' },
    ],
    outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'transferOwnership',
    inputs: [{ name: 'newOwner', type: 'address', internalType: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'updateFactorIfNeeded',
    inputs: [],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'version',
    inputs: [],
    outputs: [{ name: '', type: 'string', internalType: 'string' }],
    stateMutability: 'pure',
  },
  {
    type: 'event',
    name: 'Approval',
    inputs: [
      {
        name: 'owner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'spender',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'value',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'DelegateChanged',
    inputs: [
      {
        name: 'delegator',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'fromDelegate',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'toDelegate',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'DelegateVotesChanged',
    inputs: [
      {
        name: 'delegate',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'previousBalance',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'newBalance',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'OwnershipTransferred',
    inputs: [
      {
        name: 'previousOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'newOwner',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'TokenCreated',
    inputs: [
      {
        name: 'tokenAddress',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'creator',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'pcetokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'newTokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'TokensSwappedFromLocalToken',
    inputs: [
      {
        name: 'to',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'fromToken',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'targetTokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'pceTokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'TokensSwappedToLocalToken',
    inputs: [
      {
        name: 'from',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'toToken',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'pceTokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
      {
        name: 'targetTokenAmount',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
  {
    type: 'event',
    name: 'Transfer',
    inputs: [
      {
        name: 'from',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'to',
        type: 'address',
        indexed: true,
        internalType: 'address',
      },
      {
        name: 'value',
        type: 'uint256',
        indexed: false,
        internalType: 'uint256',
      },
    ],
    anonymous: false,
  },
]
