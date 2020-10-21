#######################################
## terraform configuration
#######################################
terraform {
  required_version = ">=0.12.6"

#  backend "azurerm" {
    #resource_group_name   = "foo"
    #storage_account_name  = "foo"
    #container_name        = "foo"
    #key                   = "foo"
#  }  
}

#######################################
## Provider
#######################################
provider "azurerm" {
  version = "~>2.13"
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}

## variables
variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
  default     = "random"
}

## locals
locals {
  base_name = var.base_name == "random" ? random_string.base_id.result : var.base_name
}

## resources
resource "random_string" "base_id" {
  length  = 5
  special = false
  upper   = false
  number  = true
}

/*
This is the outermain to enable an instanciation of a region then connect into a Traffic Manager
*/

module "region_1" {
    source                    = "./stamp"
    base_name                 = local.base_name
    location                  = "eastus"
}

module "region_2" {
    source                    = "./stamp"
    base_name                 = local.base_name
    location                  = "westus"
}


#get the fields necessary for the traffic manager
module "tm" {
    source = "./networking/trafficmgr"
    base_name                 = local.base_name
    resource_group_name = module.region_1.resource_group_name

    traffic_routing_method = "Weighted"
    region1_public_ip_address_id = module.region_1.public_ip_address
    region2_public_ip_address_id = module.region_2.public_ip_address
}
