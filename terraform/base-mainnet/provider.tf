terraform {
  required_providers {
    scm = {
      # https://github.cbhq.net/terraform/provider-smart-contract-manager/
      source  = "coinbase/smart-contract-manager"
      version = "~> 0.0.12"
    }
  }
}

provider "scm" {
  keychain_url      = "rpc.keychain.us-east-1.production.cbhq.net:8360"
  evm_rpc_url       = "https://base-mainnet.cbhq.net"
  hodor_service_url = "https://hodor.cbhq.net:8000"
}
