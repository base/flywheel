terraform {
  required_providers {
    scm = {
      # https://github.cbhq.net/terraform/provider-smart-contract-manager/
      source  = "coinbase/smart-contract-manager"
      version = "~> 0.0.16"
    }
  }
}

provider "scm" {
  keychain_url      = "rpc.keychain.us-east-1.development.cbhq.net:8360"
  evm_rpc_url       = "https://ethereum-sepolia-node.cbhq.net"
  asset_inventory_service_url = "https://asset-inventory-service.cbhq.net:8000"
}
