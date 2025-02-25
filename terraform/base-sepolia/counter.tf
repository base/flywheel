# module "counter" {
#   # See https://github.cbhq.net/smart-contracts/modules/tree/master/examples/evm-smart-contract-simple for examples.
#   source = "git::https://github.cbhq.net/smart-contracts/modules.git//modules/evm-smart-contract?ref=v0.3.3"
# 
#   keychain_signer = scm_keychain_key.example_1
# 
#   # Ensure this file is checked into git, and not ignored.
#   artifact_path = "../../out/Counter.sol/Counter.json"
#   constructor_args = {
#     "startNum" = "1"
#   }
# 
#   inventory_metadata = {
#     # enabled = false # Please leave inventory enabled for any mainnet deployments. Optonal for testnet, but still encouraged.
#     # language      = "solidity"
#     project_name  = local.project_name
#     contract_name = "Counter"
#     # is_proxy = false
#     # implementation_addresses = []
#     privileged_role_addresses = {
#       "signer" = scm_keychain_key.example_1.default_address
#     }
#     # source_code_url = "https://github.cbhq.net/smart-contracts/contract-template/blob/master/src/Counter.sol"
#     # source_code_data = "" // Optional
#   }
# }
# 
# output "contract_address" {
#   value = module.counter.contract_address
# }
# 
# resource "scm_evm_transaction" "set_number" {
#   kms = {
#     keychain_signer_id = scm_keychain_key.example_2.id
#   }
# 
#   address       = module.counter.contract_address
#   abi           = module.counter.contract_abi
#   function_name = "setNumber"
#   args = {
#     "newNumber" = "2"
#   }
# 
#   value = 0 // Optional, defaults to 0
# }
