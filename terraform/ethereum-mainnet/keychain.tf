# An example of provisioning keys in production.

# resource "scm_keychain_allocation_config" "example" {
#   # UUID, see production pool: https://houston.cbhq.net/keychain/pools/181aecf2-e2cb-468b-804f-3a559ad0b163
#   pool_id = "181aecf2-e2cb-468b-804f-3a559ad0b163"
#   # Must be unique per pool.
#   name = local.project_name
# }

# resource "scm_keychain_key" "example_1" {
#   allocation_config_id = scm_keychain_allocation_config.example.id

#   # Must be specified when working in production,
#   # otherwise it will default to `ethereum-sepolia`.
#   network = "ethereum-mainnet"
# }
