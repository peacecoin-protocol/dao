# PEACE COIN Protocol DAO

<div align="center">

![built with docker](https://img.shields.io/badge/built%20with-docker-blue)
![built with solidity](https://img.shields.io/badge/built%20with-solidity-blue)
[![codecov](https://codecov.io/gh/peacecoin-protocol/dao/branch/main/graph/badge.svg)](https://codecov.io/gh/peacecoin-protocol/dao)

</div>

## Docker Setup

### Prerequisites

- Install Docker:

  1. Visit https://www.docker.com/get-started/
  2. Download Docker Desktop for your operating system (Windows/Mac/Linux)
  3. Run the installer and follow the setup wizard
  4. Start Docker Desktop after installation

- Install Docker Compose:
  - For Windows/Mac: Docker Compose is included with Docker Desktop
  - For Linux:
    1. Run: `sudo apt-get update`
    2. Install with: `sudo apt-get install docker-compose`
    3. Verify with: `docker-compose --version`

### Getting Started

1. Clone the repository:
   https://github.com/peacecoin-protocol/dao

2. Navigate to the repository directory:

   ```bash
   cd dao
   ```

3. Run the following command to start the Docker containers:
   ```bash
   docker compose up
   ```

## Deploy DAO for Tally

To deploy the PEACECOIN DAO contracts for integration with Tally governance platform:

### Prerequisites

- Set up environment variables:
  ```bash
  export PRIVATE_KEY="your_private_key_here"
  ```

### Deployment

1. Navigate to the smart contract directory:

   ```bash
   cd dao-smartcontract
   ```

2. Deploy the DAO contracts using Forge:
   ```bash
   forge script src/deploy/PEACECOINDAO.s.sol --rpc-url <your_rpc_url> --broadcast --via-ir
   ```

### Deployed Contracts

The deployment script will create the following contracts:

- **PCEGovTokenTest**: ERC-20 governance token with voting capabilities
- **PEACECOINDAO_GOVERNOR**: Governor contract implementing OpenZeppelin's governance framework
- **Timelock**: Timelock controller for delayed execution of proposals

### Governor Configuration

The governor is configured with the following parameters:

- **Voting Delay**: 1 block
- **Voting Period**: 302,400 blocks (~1 week)
- **Proposal Threshold**: 1 PCE token
- **Quorum**: 1,000 PCE tokens
- **Timelock Delay**: 1 day

### Tally Integration

After deployment, add your DAO to Tally by:

1. Visit [Tally](https://www.tally.xyz/)
2. Connect your wallet
3. Add your deployed Governor contract address
4. Your DAO will be indexed and available for governance participation
