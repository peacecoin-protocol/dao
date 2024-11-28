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


### Start Anvil: Deploy Contracts on Local Testnet
Open Terminal and run:

```shell
anvil
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
