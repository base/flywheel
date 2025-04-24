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
  keychain_url      = "rpc.keychain.us-east-1.production.cbhq.net:8360"
  evm_rpc_url       = "https://arbitrum-mainnet-node.cbhq.net:8547"
  asset_inventory_service_url = "https://asset-inventory-service.cbhq.net:8000"
}
