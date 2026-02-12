## Peace Coin DAO

A modular DAO framework for the Peace Coin ecosystem. This repository contains the core on-chain components for creating DAOs, governing proposals with a timelock, issuing membership and governance tokens, running campaigns, distributing bounties, and staking PCE.

## Overview

This codebase provides:

- A DAO factory that deploys governance infrastructure (timelock, governor, governance token, SBT/NFT, and multiple-choice voting).
- Governance contracts for proposing, voting, and executing decisions through a timelock.
- Campaigns with configurable rewards (ERC20, SBT, or NFT) and optional signature validation.
- Bounty mechanics tied to proposal outcomes and contributors.
- Staking for PCE with wPCE receipt tokens and configurable rewards.
- A simple bytecode factory for owner-controlled deployments.

## Core Contracts

- `src/DAOFactory.sol` Factory that clones and configures DAO components, stores DAO config, and manages DAO roles.
- `src/Governance/GovernorAlpha.sol` Governor contract that tracks proposals, votes, and timelock execution.
- `src/Governance/Timelock.sol` Timelock used to queue and execute successful proposals with delay.
- `src/Governance/MultipleVotings.sol` Multiple-choice voting module (up to 20 options).
- `src/Governance/PEACECOINDAO_NFT.sol` ERC1155 NFT with per-ID voting weights and delegation.
- `src/Governance/PEACECOINDAO_SBT.sol` Non-transferable SBT variant of the DAO NFT.
- `src/Campaigns.sol` Campaigns with reward distribution (ERC20, SBT, or NFT) and optional signature gating.
- `src/Bounty.sol` Proposal and contributor bounties, gated by governance outcomes.
- `src/Staking.sol` PCE staking with wPCE receipts and reward-per-block emissions.
- `src/ContractFactory.sol` Owner-only factory for deploying arbitrary bytecode.

## Access Control Summary

- `DAOFactory` uses `DEFAULT_ADMIN_ROLE` and `DAO_MANAGER_ROLE` for DAO lifecycle and campaign controls.
- `Bounty` and `Staking` are `Ownable` and restrict admin actions to the owner.
- `ContractFactory` is owner-restricted for deployments.

## Documentation

Foundry Book: https://book.getfoundry.sh/

## Prerequisites

- Foundry installed and up to date.
- A funded deployer wallet for the target network.
- RPC endpoint for the target network (e.g., Polygon).
- Polygonscan API key for verification (optional but recommended).

## Project Structure

- `src/` Solidity contracts.
- `src/deploy/` Foundry deployment scripts.
- `test/` Foundry tests.

## Development


## Install Foundry Libraries

To install (or update) Foundry and its standard libraries, run:

```shell
foundryup
```

This will install or update `forge`, `cast`, and related tools to the latest version.

For contract libraries commonly used in Foundry projects (such as OpenZeppelin), you can add them as submodules, or install via `forge install`.

```shell
forge install
```


Build:

```shell
forge build
```

Test:

```shell
forge test
```

Format:

```shell
forge fmt
```

Gas snapshots:

```shell
forge snapshot
```

Start local node:

```shell
anvil
```

Cast helper:

```shell
cast <subcommand>
```

Help:

```shell
forge --help
anvil --help
cast --help
```

## Environment Setup

Create a `.env` file at the project root. Use `.env_example` as a template.

Required variables:

- `PRIVATE_KEY` Deployer wallet private key.
- `POLYGON_RPC_URL` RPC endpoint for Polygon.

Optional variables:

- `POLYSCAN_API_KEY` Polygonscan API key for contract verification.

Example:

```shell
PRIVATE_KEY=0xYOUR_PRIVATE_KEY
POLYGON_RPC_URL=https://polygon-rpc.com
POLYSCAN_API_KEY=YOUR_POLYGONSCAN_KEY
```

Notes:

- Never commit `.env` to version control.
- Use a dedicated deployer wallet with limited funds.

## Deployment (Polygon)

1. Ensure all required environment variables are properly configured in your `.env` file, and that your deployer wallet contains sufficient MATIC for gas fees.

2. ```shell
   # Load environment variables for this shell session
   source .env
   ```
3. Run the deployment script:

```shell
forge script 'src/deploy/deploy.s.sol' \
  --fork-url $POLYGON_RPC_URL \
  --broadcast \
  --via-ir
```

## Deployment + Verification (Polygon)

If you want automatic verification on Polygonscan:

```shell
forge script 'src/deploy/deploy.s.sol' \
  --fork-url $POLYGON_RPC_URL \
  --etherscan-api-key $POLYSCAN_API_KEY \
  --broadcast \
  --verify \
  --via-ir
```

## Common Troubleshooting

- `Invalid private key` Ensure `PRIVATE_KEY` is a hex string with `0x` prefix.
- `insufficient funds for gas` Fund the deployer wallet with MATIC.
- `unable to verify` Confirm `POLYSCAN_API_KEY` is valid and the network matches your RPC.

## Notes

- If you deploy to a different network, swap `POLYGON_RPC_URL` and the corresponding explorer API key.
- For local deployments, use `anvil` and replace `--fork-url` with `--rpc-url http://127.0.0.1:8545`.
