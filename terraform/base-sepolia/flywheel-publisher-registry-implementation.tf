module "flywheel_publisher_registry_implementation" {
  source = "git::https://github.cbhq.net/terraform/scm-modules.git//modules/evmsmartcontract"

  keychain_signer = scm_keychain_key.flywheel-protocol-base-sepolia-base-sepolia-deploy-key

  artifact_path = "../../out/FlywheelPublisherRegistry.sol/FlywheelPublisherRegistry.json"
  constructor_args = {}

  inventory_metadata = {
    language = "solidity"
    project_name = local.project_name
    contract_name = "FlywheelPublisherRegistry"
    is_proxy = false  # This is the implementation, not a proxy
    privileged_role_addresses = {
      "owner" = scm_keychain_key.flywheel-protocol-base-sepolia-base-sepolia-deploy-key.default_address
    }
  }

  etherscan_verification = {
    enabled = true
    contract_name = "src/FlywheelPublisherRegistry.sol:FlywheelPublisherRegistry"
    build_info_path = "../../out/build-info/1bd655e5e5e3281b4dff91c8616519ba.json"
  }
}

output "flywheel_publisher_registry_implementation_address" {
  value = module.flywheel_publisher_registry_implementation.contract_address
} 