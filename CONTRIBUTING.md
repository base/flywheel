# contract-template

A boilerplate for developing, deploying and managing smart contracts at Coinbase using Foundry, and Terraform.

> [!TIP]
> For more help, visit https://docs.cbhq.net/onchain/SCM/getting-started

## Getting Started

Note: Terraform files can be organized as desired and do not have to follow specific naming formats, as long as they exist under the `terraform` directory. We recommend naming the directories (aka workspaces) in `terraform` based on their environment / network (e.g. `dev` / `prod`).

For security and audit purposes, you must provision your keys in a separate PR before you can use them. Do not provision keys and use them in the same PR.

### Provision K2 Keys

See [`./terraform/dev/keychain.tf`](https://github.cbhq.net/smart-contracts/contract-template/blob/master/terraform/dev/keychain.tf) for a full example. Keys must be provisioned before they can be used for transactions.

1. Update `coinbase_keychain_allocation_config` resource and set `name` to the current project name (the GitHub org/repo)
    - Generally, you do not need to change the pool ID already defined in the example `dev` and `prod`
2. Create a new `coinbase_keychain_key` resource, giving it a unique name based on its purpose
3. Create a PR -> Get +1s -> Merge

### Deploying Contract

See [`./terraform/dev/counter.tf`](https://github.cbhq.net/smart-contracts/contract-template/blob/master/terraform/dev/counter.tf) for a full example.

1. Delete / modify example `Counter.sol` contract in [`./src`](https://github.cbhq.net/smart-contracts/contract-template/blob/master/src/Counter.sol) and develop your own contract using [`forge`](#Foundry) (see below)
2. Compile contract using `forge build`, this should create the compiled contract artifacts in the `out` directory
3. Delete / modify example `counter.tf` and deploy your own contract using the `evm-smart-contract` module
    - Rename `counter.tf` and the module name to your contract's name
    - Set `keychain_signer_id` to the desired allocated key (`coinbase_keychain_key`) which will be signing the deployment transaction
    - Update the `artifact_path` parameter in the module to your contract's artifact file in the `out` directory
    - Update the `constructor_args` parameter if necessary (this corresponds to inputs for your contract's `constructor` which is called on deployment)
    - Update `.gitignore` if your contract's artifact file in the `out` directory is not being included in git
4. Create a PR -> Get +1s -> Merge

### Making Contract Calls

See `coinbase_evm_transaction.set_number` in [`./terraform/dev/counter.tf`](https://github.cbhq.net/smart-contracts/contract-template/blob/master/terraform/dev/counter.tf) for a full example.

1. Create a new `coinbase_evm_transaction` resource
2. Set `kms.keychain_signer_id` to the desired allocated key (`coinbase_keychain_key`) which will be signing the contract call transaction
3. Set the address of the contract as well as its ABI, function name and arguments
    - If your contract was deployed using `evm-smart-contract`, you can get these from the module's attributes (e.g. `module.counter.contract_address`, `module.counter.contract_abi`)
    - Tuples are supported for arguments, but ensure they are wrapped in parentheses (e.g. `(1,true)`)
4. Create a PR -> Get +1s -> Merge


## Common Development Patterns

### Versioning

Transactions cannot be reverted once they have landed onchain. That is, your deployed contracts' bytecode cannot be updated or deleted. To deploy a new version of your contract, we recommend storing your contract artifacts namespaced by timestamp and creating new resources, also namespaced by timestamp. This will allow you to preserve a record of historical transactions and hence, deployments.

For example:

```
.
└── terraform/
    └── dev/
        ├── build/
        │   ├── 20240501/
        │   │   └── Counter.json
        │   └── 20240601/
        │       └── Counter.json
        └── counter.tf
```

Then, referencing `Counter.json` like so:

```hcl
# Old / existing
module "counter_20240501" {
  source             = "git::https://github.cbhq.net/smart-contracts/modules.git//modules/evm-smart-contract?ref=v0.1.3"
  keychain_signer = coinbase_keychain_key.counter_deployer
  artifact_path      = "./build/20240501/Counter.json"
  constructor_args = {
    # ...
  }
}

# New
module "counter_20240601" {
  source             = "git::https://github.cbhq.net/smart-contracts/modules.git//modules/evm-smart-contract?ref=v0.1.3"
  keychain_signer = coinbase_keychain_key.counter_deployer
  artifact_path      = "./build/20240601/Counter.json"
  constructor_args = {
    # ...
  }
}
```

We DO NOT recommend trying to "delete" the deployment (e.g. removing the `module.counter_20240501`) or updating an existing deployment (e.g. changing `artifact_path` or `constructor_args` in `module.counter_20240501`). The latter will result in a noop onchain, but will remove any references to the onchain transaction in the Terraform state. The former will result in a new onchain transaction, but will remove any references to the previous onchain transaction in the Terraform state.

See [`smart-contracts/clear-pools`](https://github.cbhq.net/smart-contracts/clear-pools/tree/master/terraform) for full examples.

_As of June 2024, we are working on a smart contract inventory database which should ease versioning and artifact management in the long-term._


### Public Repos

If you would like to build your contracts in the open while still relying on Smart Contract Manager we suggest compiling your contracts in the public repo and simply copying the compiled contract artifacts to your internal `smart-contracts/` repo. That is, keep the source in the public repo and use the `smart-contracts/` repo for deployment / management config as well as artifacts.

_Also, as mentioned above, our work on a smart contract inventory database should provide us with better first-class support for deploying and managing contracts in public repos in the long-term._

### Deterministic Contract Address

The `evm-smart-contract` module supports deploying a contract at a deterministic location using a [CREATE2 Deterministic Deployment Proxy](https://github.com/Arachnid/deterministic-deployment-proxy). Simply specify a `create2_salt` as part of the resource's attributes. Example available on the [module docs](https://github.cbhq.net/smart-contracts/modules/blob/3d1803ff01e6de6c39085900e01c291e94d0b3db/examples/evm-smart-contract-simple/main.tf#L17).

The `contract_address` attribute for both the aforementioned module and the `coinbase_evm_transaction` resource supports CREATE2. The attribute will be populated with the contract's address if the underlying transaction deploys a contract.

It is also possible to determine the contract address ahead of time using the `coinbase_evm_contract_address` data source. See [docs](https://github.cbhq.net/infra/terraform-provider-coinbase/blob/3dec812ba7190861dd3b0ac1fbbe94e22ac1fe19/docs/examples/data-sources/coinbase_evm_contract_address/data-source.tf) for examples.


## Terraform

[Infra Provisioner (TFR)](https://github.cbhq.net/infra/provisioner) is used for managing the smart contracts.
 
See [`terraform`](https://github.cbhq.net/smart-contracts/contract-template/tree/master/terraform/dev) for examples on provisioning Keychain keys, and using them for contract deployment as well as management.

Changes are _applied_ after they are merged to the main branch.

**Need help? Find us at #proj-smart-contract-manager**


### Retrying

- Trigger a replan: close and open PR
- Trigger a reapply: comment `reapply-all` on your PR


## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.

### Documentation

https://book.getfoundry.sh/

### Usage

#### Build

```shell
$ forge build
```

#### Test

```shell
$ forge test
```

#### Format

```shell
$ forge fmt
```

#### Gas Snapshots

```shell
$ forge snapshot
```

#### Anvil

```shell
$ anvil
```

#### Local Deploy

With anvil running in a separate terminal, run this command (the example keys are outputted when you start up anvil):

```shell
$ forge create src/MyContract.sol:MyContract --private-key <anvil-example-key>
```

#### Cast

```shell
$ cast <subcommand>
```

#### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
