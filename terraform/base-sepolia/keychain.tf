# resource "scm_keychain_allocation_config" "example" {
#   # UUID, see development pool: https://houston-dev.cbhq.net/keychain/pools/3dff1998-d258-4720-9676-055e144b3add
#   pool_id = "3dff1998-d258-4720-9676-055e144b3add"
#   # Must be unique per pool.
#   name = local.project_name
# }
# 
# resource "scm_keychain_key" "example_1" {
#   allocation_config_id = scm_keychain_allocation_config.example.id
# }
# 
# resource "scm_keychain_key" "example_2" {
#   allocation_config_id = scm_keychain_allocation_config.example.id
# }
