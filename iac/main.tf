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

#get a pip for the matchmaking vm
#options Dynamic or Static
module "matchmaker-vm-pip" {
  source = "./networking/publicip"
  base_name = local.base_name
  pip_name = "mm"
  pip_sku = "Standard"
  resource_group = module.unreal-rg.resource_group
  allocation_method = "Static"
}

#windows based matchmaking server
module "matchmaker-vm" {
  source = "./compute/vm"
  base_name = local.base_name
  vm_name = format("%s-%s", local.base_name, var.vm_name)
  resource_group = module.unreal-rg.resource_group
  subnet_id = module.unreal-vnet.subnet_id
  dia_stg_acct_id = module.unreal-storage.id
  storage_uri = module.unreal-storage.uri

  admin_username = var.matchmaker_admin_username
  admin_password = random_string.admin_password.result

  vm_size = var.matchmaker_vm_size
  vm_publisher = var.matchmaker_vm_publisher
  vm_offer = var.matchmaker_vm_offer
  vm_sku = var.matchmaker_vm_sku
  vm_version = var.matchmaker_vm_version

  public_ip_address_id = module.matchmaker-vm-pip.id
}

#TODO?
#turn on the vm diagnostic settings
#turn on the vm alerts
#turn on the vm logs

#ADD the first NSG
module "matchmaker_nsg" {
  source = "./networking/nsg"
  base_name = local.base_name
  resource_group = module.unreal-rg.resource_group
  nsg_name = "mm-nsg"
  security_rule_name                       = "Open80"
  security_rule_priority                   = 1000
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "80"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

#associate the NSG to the NIC
module "matchmaker_nsg_association" {
  source = "./networking/nsgassociation"
  network_interface_id      = module.matchmaker-vm.nic_id
  network_security_group_id = module.matchmaker_nsg.network_security_group_id
}

#add this security rule to open another port in the NSG
module "matchmaker_security_rule_888x" {
  source = "./networking/security_rule"
  resource_group = module.unreal-rg.resource_group
  network_security_group_name = module.matchmaker_nsg.network_security_group_name

  security_rule_name                       = "Open888x"
  security_rule_priority                   = 1010
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "8888-8889"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

#add this security rule to open another port in the NSG
module "matchmaker_security_rule_7070" {
  source = "./networking/security_rule"
  resource_group = module.unreal-rg.resource_group
  network_security_group_name = module.matchmaker_nsg.network_security_group_name

  security_rule_name                       = "Open7070"
  security_rule_priority                   = 1020
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "7070"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

module "compute-vmss" {
  source = "./compute/vmss"
  base_name = local.base_name
  vm_name = format("%s%s", local.base_name, "vmss")
  resource_group = module.unreal-rg.resource_group
  subnet_id = module.unreal-vnet.subnet_id
  
  admin_username = var.matchmaker_admin_username
  admin_password = random_string.admin_password.result

  sku = "Standard_NV6"
  instances = 2

  vm_publisher = var.matchmaker_vm_publisher
  vm_offer = var.matchmaker_vm_offer
  vm_sku = var.matchmaker_vm_sku
  vm_version = var.matchmaker_vm_version
}

module "compute-autoscale" {
  source = "./compute/autoscale"
  base_name = local.base_name
  resource_group = module.unreal-rg.resource_group
  vmss_id = module.compute-vmss.id
  capacity_default = var.capacity_default
  capacity_minimum = var.capacity_minimum
  capacity_maximum = var.capacity_maximum
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

#I need to add an extension to the vm above to add IIS to respond to 80/443
module "iis_extension" {
  source = "./iac/extensions/iis_extension/"
  iis_vm_id = module.windows_server_spoke.vm_id
}

*/