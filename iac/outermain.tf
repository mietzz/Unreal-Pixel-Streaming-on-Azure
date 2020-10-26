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
  #this variable is used on all naming to avoid name collisions
  base_name = var.base_name == "random" ? random_string.base_id.result : var.base_name
}

## resources
resource "random_string" "base_id" {
  length  = 5
  special = false
  upper   = false
  number  = true
}

//stamp directory is the instance for a region
//location is the Azure Region
//index is used in the file name of the storage account
module "region_1" {
    source                    = "./stamp"
    base_name                 = local.base_name
    location                  = "eastus"
    index                     = "1"
}

module "region_2" {
    source                    = "./stamp"
    base_name                 = local.base_name
    location                  = "westeurope"
    index                     = "2"
}

#first set up the matchmaker traffic manager profile
module "tm-profile-mm" {
    source = "./networking/trafficmgr"
    base_name = local.base_name

    #put the PM in the first region
    resource_group_name = module.region_1.resource_group_name

    service_name = "mm"
    #the next line can be Weighted or Geographic for example
    traffic_routing_method = "Performance"
}

#add the first region TM endpoint
module "add_region_1_mm" {
    source = "./networking/trafficmgraddreg"
    base_name = local.base_name
    resource_group_name = module.region_1.resource_group_name

    traffic_manager_profile_name = module.tm-profile-mm.traffic_manager_profile_name
    index = module.region_1.index

    #plug in the ELB of the MM
    region_resourceTargetId = module.region_1.matchmaker-elb-id
}

#add the second region TM endpoint
module "add_region_2_mm" {
    source = "./networking/trafficmgraddreg"
    base_name = local.base_name
    resource_group_name = module.region_2.resource_group_name

    traffic_manager_profile_name = module.tm-profile-mm.traffic_manager_profile_name
    index = module.region_2.index

    #plug in the ELB of the MM
    region_resourceTargetId = module.region_2.matchmaker-elb-id
}

#first set up the backend traffic manager profile
module "tm-profile-ue4" {
    source = "./networking/trafficmgr"
    base_name = local.base_name

    #put the PM in the first region
    resource_group_name = module.region_1.resource_group_name

    service_name = "ue4"
    #the next line can be Weighted or Geographic for example
    traffic_routing_method = "Performance"
}

#add the first region TM endpoint
module "add_region_1_ue4" {
    source = "./networking/trafficmgraddreg"
    base_name = local.base_name
    resource_group_name = module.region_1.resource_group_name

    traffic_manager_profile_name = module.tm-profile-ue4.traffic_manager_profile_name
    index = module.region_1.index

    #plug in the ELB of the MM
    region_resourceTargetId = module.region_1.ue4-elb-id
}

#add the first region TM endpoint
module "add_region_2_ue4" {
    source = "./networking/trafficmgraddreg"
    base_name = local.base_name
    resource_group_name = module.region_2.resource_group_name

    traffic_manager_profile_name = module.tm-profile-ue4.traffic_manager_profile_name
    index = module.region_2.index

    #plug in the ELB of the MM
    region_resourceTargetId = module.region_2.ue4-elb-id
}

/* TODO
    -decide on faster disks for vms or vmss
    -turn on log analytics and capture diags
    -turn on process for autoupdate on vmss and vms
    -consider how to make the tm add geo points
    -take out vmss autoscale
*/