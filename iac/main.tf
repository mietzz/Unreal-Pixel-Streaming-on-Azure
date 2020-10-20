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

## outputs

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

resource "random_string" "admin_password" {
  length  = 10
  special = true
  upper   = true
  number  = true
}

#create a resource group, uses the location in the variables.tf file
module "unreal-rg" {
  source    = "./rg"
  base_name = local.base_name
  location = var.location
}

#create a virtual network, uses variables in the variables.tf file
module "unreal-vnet" {
    source                    = "./networking/vnet"
    base_name                 = local.base_name
    resource_group            = module.unreal-rg.resource_group
    vnet_address_space        = var.vnet_address_space
    subnet_address_prefixes   = var.subnet_address_prefixes
}
#turn on ddos? any other vnet capabilities?

module "unreal-storage" {
  source         = "./storage"
  base_name      = local.base_name
  resource_group = module.unreal-rg.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"  
}

/*
//pvt FunctionApp module
module "funcapp" {
  source         = "./iac/funcapp/"
  base_name      = local.base_name
  resource_group = module.rgs.spoke_rg
  spoke_vnet = module.network.spoke_vnet
  spoke_endpoint_subnet = module.network.spoke_endpoint_subnet  
}

#get a pip for the first client
#options Dynamic or Static
module "daniman_vm_pip" {
  source = "./iac/network/public_ip"
  base_name = local.base_name
  pip_name = "client1"
  pip_sku = "Standard"
  resource_group = module.rgs.onprem_rg
  allocation_method = "Static"
}


#ADD NSG
module "vm1_nsg" {
  source = "./iac/network/nsgs/"
  base_name = local.base_name
  resource_group = module.rgs.onprem_rg
  nsg_name = "daniman-vm-nsg"
  security_rule_name                       = "OpenRDP"
  security_rule_priority                   = 1000
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "3389"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

#windows web server in spoke
module "windows_server_spoke" {
  source = "./iac/vms/servers/windows/"
  base_name = local.base_name
  vm_name = "webserver"
  resource_group = module.rgs.spoke_rg
  vm_size = "Standard_DS3_v2"
  subnet_id = module.network.spoke_subnet.id
  dia_stg_acct_id = module.vm-stg.diag_stg.id
  admin_username = "azureadmin"
  admin_password = random_string.admin_password.result
}

#I need to add an extension to the vm above to add IIS to respond to 80/443
module "iis_extension" {
  source = "./iac/extensions/iis_extension/"
  iis_vm_id = module.windows_server_spoke.vm_id
}

*/