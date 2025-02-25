resource "scm_keychain_allocation_config" "flywheel-protocol-base-mainnet" {
  pool_id = "181aecf2-e2cb-468b-804f-3a559ad0b163"
  name    = local.project_name
}

resource "scm_keychain_key" "flywheel-protocol-base-mainnet-base-mainnet-deploy-key" {
  allocation_config_id = scm_keychain_allocation_config.flywheel-protocol-base-mainnet.id
  network = "ethereum-mainnet"
}

