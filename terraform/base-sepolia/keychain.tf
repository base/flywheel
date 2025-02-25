resource "scm_keychain_allocation_config" "flywheel-protocol-base-sepolia" {
  pool_id = "3dff1998-d258-4720-9676-055e144b3add"
  name    = local.project_name
}

resource "scm_keychain_key" "flywheel-protocol-base-sepolia-base-sepolia-deploy-key" {
  allocation_config_id = scm_keychain_allocation_config.flywheel-protocol-base-sepolia.id
}

