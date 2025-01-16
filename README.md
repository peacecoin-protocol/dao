# pce_dao

** Peace Coin DAO **

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```

### Deployment

```
forge script 'src/deploy/DAOScript.sol':DAOScript --rpc-url $AMOY_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --verify
```

### Use the Pre-Funded Account:

The account will have test ETH ready to interact with your local testnet. Use this ETH for deploying contracts or testing transactions.

### Deploy Contracts

```shell
forge script 'src/deploy/DAOFactoryScript.sol:DAOFactoryScript' --fork-url http://127.0.0.1:8545 --broadcast --via-ir
```

### Deploy Testnet

```shell
forge script 'src/deploy/PCECommunityGovTokenScript.sol:PCECommunityGovTokenScript' --fork-url $AMOY_RPC_URL --etherscan-api-key $ETHERSCAN_API_KEY --broadcast --verify --via-ir
```

### Start Anvil: Deploy Contracts on Local Testnet

Open Terminal and run:

```shell
anvil
```

### Deploy Contract on Anvil Local Testnet

```shell
forge script 'src/script/script.s.sol:script' --fork-url http://127.0.0.1:8545 --broadcast --via-ir
```

### Setting up a local Subgraph Environment

## Prquisites

The following packeges and tools have to be installed for the setup to be working:

### Docker

https://docs.docker.com/get-started/#download-and-install-docker

### IPFS

https://github.com/ipfs/ipfs-desktop/releases

### Graph CLI

```
# NPM
npm install -g @graphprotocol/graph-cli

# Yarn
yarn global add @graphprotocol/graph-cli
```

### Local Graph Node

Set up local Graph node with graph-cli.

In new Terminal navigate to the docker folder:

```
cd graph-node/docker
```

Then run:

```
./setup.sh
```

This adapts the local docker-compose file of the graph-node to link to the local chain, that we host with anvil.

```
docker-compose up
```

Starts the graph-node that should link up to the local chain automatically.

### Deploying Subgraph

In new Terminal navigate to the subgraph folder:

```
cd PCEDaoSubgraph
```

Create the subgraph via:

```
graph codegen && graph build
```

Register subgraph name in the graph-node:

```
npm run create-local
```

Deploy the subgraph to the local graph-node:

```
npm run deploy-local
```
