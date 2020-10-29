#######################################
## terraform configuration
#######################################
#terraform {
#  required_version = ">=0.12.6"

#  backend "azurerm" {
#resource_group_name   = "foo"
#storage_account_name  = "foo"
#container_name        = "foo"
#key                   = "foo"
#  }  
#}

#######################################
## Provider
#######################################
provider "azurerm" {
  #version = "=2.20.0"
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
//location is the Azure Region for the Stamp
//index is used in the file name of someof the resources
module "region_1" {
  source    = "./stamp"
  base_name = local.base_name
  location  = "eastus"
  index     = "1"
}

module "region_2" {
  source    = "./stamp"
  base_name = local.base_name
  location  = "westeurope"
  index     = "2"
}

#... Add additional regional modules for any other locations. 
#... Remember the requirement is for NV6 VMs, and not all regions contain those VMs

### todo: could we consolidate the tm as part of the region modules ###

#Traffic Manager implementation:

#Set up the matchmaker traffic manager profile
module "tm-profile-mm" {
  source    = "./networking/trafficmgr"
  base_name = local.base_name

  #put the PM in the first region
  resource_group_name = module.region_1.resource_group_name

  service_name = "mm"
  #the next line can be Weighted or Geographic for example
  traffic_routing_method = "Performance"

  log_analytics_workspace_id = module.region_1.LogA_workspace_id
}

#add the first region TM endpoint
module "add_region_1_mm" {
  source              = "./networking/trafficmgraddreg"
  base_name           = local.base_name
  resource_group_name = module.region_1.resource_group_name

  traffic_manager_profile_name = module.tm-profile-mm.traffic_manager_profile_name
  index                        = module.region_1.index
  service_name                 = "mm"

  pip_fqdn          = module.region_1.matchmaker-elb-fqdn
  endpoint_location = module.region_1.location
}

#add the second region TM endpoint
module "add_region_2_mm" {
  source    = "./networking/trafficmgraddreg"
  base_name = local.base_name

  #this needs to be the rg where the tm profile is:
  resource_group_name = module.region_1.resource_group_name

  traffic_manager_profile_name = module.tm-profile-mm.traffic_manager_profile_name
  index                        = module.region_2.index
  service_name                 = "mm"

  pip_fqdn          = module.region_2.matchmaker-elb-fqdn
  endpoint_location = module.region_2.location
}

#first set up the backend traffic manager profile
module "tm-profile-ue4" {
  source    = "./networking/trafficmgr"
  base_name = local.base_name

  #put the PM in the first region
  resource_group_name = module.region_1.resource_group_name

  service_name = "ue4"
  #the next line can be Weighted or Geographic for example
  traffic_routing_method = "Performance"

  log_analytics_workspace_id = module.region_1.LogA_workspace_id
}

#add the first region TM endpoint
module "add_region_1_ue4" {
  source              = "./networking/trafficmgraddreg"
  base_name           = local.base_name
  resource_group_name = module.region_1.resource_group_name

  traffic_manager_profile_name = module.tm-profile-ue4.traffic_manager_profile_name
  index                        = module.region_1.index
  service_name                 = "ue4"

  #plug in the ELB of the MM
  pip_fqdn          = module.region_1.ue4-elb-fqdn
  endpoint_location = module.region_1.location
}

#add the first region TM endpoint
module "add_region_2_ue4" {
  source    = "./networking/trafficmgraddreg"
  base_name = local.base_name

  #this needs to be the rg where the tm profile is:
  resource_group_name = module.region_1.resource_group_name

  traffic_manager_profile_name = module.tm-profile-ue4.traffic_manager_profile_name
  index                        = module.region_2.index
  service_name                 = "ue4"

  #plug in the ELB of the MM
  pip_fqdn          = module.region_2.ue4-elb-fqdn
  endpoint_location = module.region_2.location
}
