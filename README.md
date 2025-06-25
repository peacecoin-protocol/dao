# PEACE COIN Protocol DAO

<div align="center">

![built with docker](https://img.shields.io/badge/built%20with-docker-blue)
![built with solidity](https://img.shields.io/badge/built%20with-solidity-blue)
[![codecov](https://codecov.io/gh/peacecoin-protocol/dao/branch/main/graph/badge.svg)](https://codecov.io/gh/peacecoin-protocol/dao)

</div>

## Overview

The PEACE COIN Protocol DAO is a decentralized autonomous organization built on Ethereum, implementing a comprehensive governance system using OpenZeppelin's governance framework. This repository contains the smart contracts and deployment scripts for the PEACE COIN governance ecosystem.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Smart Contract Architecture](#smart-contract-architecture)
- [Deployment Guide](#deployment-guide)
- [Tally Integration](#tally-integration)
- [Configuration](#configuration)
- [Development](#development)

## Prerequisites

### Docker Environment

- **Docker Desktop**: [Download and install](https://www.docker.com/get-started/) for your operating system
  - Windows/Mac: Docker Compose is included with Docker Desktop
  - Linux: Install separately with `sudo apt-get install docker-compose`

### Development Environment

- **Node.js**: Version 16 or higher
- **Foundry**: For smart contract development and deployment
- **Git**: For version control

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/peacecoin-protocol/dao
cd dao
```

### 2. Start Development Environment

```bash
docker compose up
```

This will start all necessary services for local development.

## Smart Contract Architecture

The PEACE COIN DAO consists of three core smart contracts:

### Core Contracts

| Contract                  | Purpose                                                            | Source                                      |
| ------------------------- | ------------------------------------------------------------------ | ------------------------------------------- |
| **WPCE**                  | ERC-20 governance token with voting capabilities                   | `/src/Governance/WPCE.sol`                  |
| **PEACECOINDAO_GOVERNOR** | Governor contract implementing OpenZeppelin's governance framework | `/src/Governance/PEACECOINDAO_GOVERNOR.sol` |
| **Timelock**              | Timelock controller for delayed execution of proposals             | `/src/Governance/Timelock.sol`              |

### Contract Relationships

```
WPCE Token → Governor Contract → Timelock Controller → Target Contracts
```

## Deployment Guide

### Prerequisites

1. **Environment Setup**

   ```bash
   export PRIVATE_KEY="your_private_key_here"
   export RPC_URL="your_ethereum_rpc_url"
   ```

2. **Network Configuration**
   - Ensure you have sufficient ETH for gas fees
   - Verify your RPC endpoint is accessible

### Deployment Process

1. **Navigate to Smart Contract Directory**

   ```bash
   cd dao-smartcontract
   ```

2. **Deploy Contracts**
   ```bash
   forge script src/deploy/PEACECOINDAO_SBT.s_Testnet.sol \
     --rpc-url $RPC_URL \
     --broadcast \
     --via-ir
   ```

### Deployment Script

The deployment script (`/src/deploy/PEACECOINDAO_SBT.s_Testnet.sol`) handles the complete deployment process:

1. Deploys WPCE governance token
2. Deploys Timelock controller
3. Deploys Governor contract
4. Configures all contract relationships
5. Transfers ownership to the DAO

**⚠️ Important**: Update deployment parameters in the script before execution.

## Configuration

### Governor Parameters

| Parameter              | Value                  | Description                                  |
| ---------------------- | ---------------------- | -------------------------------------------- |
| **Voting Delay**       | 1 block                | Blocks to wait before voting starts          |
| **Voting Period**      | 50,400 blocks          | Duration of voting (~1 week)                 |
| **Proposal Threshold** | 1e18 (1 WPCE)          | Minimum tokens required to create a proposal |
| **Quorum**             | 1,000e18 (1,000 WPCE)  | Minimum votes required for proposal approval |
| **Timelock Delay**     | 86,400 seconds (1 day) | Delay before proposal execution              |

### Token Economics

- **Token Name**: WPCE (Wrapped PEACE COIN)
- **Token Symbol**: WPCE
- **Decimals**: 18
- **Total Supply**: Configurable in deployment script

## Tally Integration

### Adding Your DAO to Tally

1. **Visit Tally Platform**

   - Go to [Tally](https://www.tally.xyz/)
   - Connect your wallet

2. **Add Governor Contract**

   - Enter your deployed Governor contract address
   - Tally will automatically index your DAO

3. **Verify Integration**
   - Check that your DAO appears in the Tally interface
   - Verify proposal creation and voting functionality

### Governance Workflow

1. **Proposal Creation**: Users with sufficient WPCE tokens can create proposals
2. **Voting Period**: Token holders vote on proposals during the voting period
3. **Timelock**: Approved proposals enter the timelock period
4. **Execution**: Proposals can be executed after the timelock delay

## Development

### Local Development

```bash
# Install dependencies
npm install

# Run tests
npm test

# Compile contracts
forge build

# Run local node
anvil
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-test testFunctionName

# Run with coverage
forge coverage
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## Security

- All contracts are based on OpenZeppelin's audited governance framework
- Timelock provides additional security for proposal execution
- Multi-signature capabilities for critical operations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For questions and support:

- Create an issue on GitHub
- Join our community discussions
- Review the documentation

---

**Note**: This is a testnet deployment script. For mainnet deployment, ensure all parameters are thoroughly reviewed and tested.
