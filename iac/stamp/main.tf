variable "base_name" {
  type        = string
}

variable "location" {
  description = "Location of the region"
  default     = "eastus"
}

resource "random_string" "admin_password" {
  length  = 10
  special = true
  upper   = true
  number  = true
}
## outputs


#create a resource group, uses the location in the variables.tf file
module "unreal-rg" {
  source    = "../rg"
  base_name = var.base_name
  location = var.location
}

output "resource_group_name" {
  value = module.unreal-rg.resource_group.name
}

#create a virtual network, uses variables in the variables.tf file
module "unreal-vnet" {
    source                    = "../networking/vnet"
    base_name                 = var.base_name
    resource_group            = module.unreal-rg.resource_group
    vnet_address_space        = var.vnet_address_space
    subnet_address_prefixes   = var.subnet_address_prefixes
}

module "unreal-storage" {
  source         = "../storage"
  base_name      = var.base_name
  resource_group = module.unreal-rg.resource_group
  account_tier             = "Standard"
  account_replication_type = "LRS"  
}

#get a pip for the matchmaking vm
#options Dynamic or Static
module "matchmaker-vm-pip" {
  source = "../networking/publicip"
  base_name = var.base_name
  pip_name = "mm"
  pip_sku = "Standard"
  resource_group = module.unreal-rg.resource_group
  allocation_method = "Static"
}

#windows based matchmaking server
module "matchmaker-vm" {
  source = "../compute/vm"
  base_name = var.base_name
  vm_name = format("%s-%s", var.base_name, var.vm_name)
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
  source = "../networking/nsg"
  base_name = var.base_name
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
  source = "../networking/nsgassociation"
  network_interface_id      = module.matchmaker-vm.nic_id
  network_security_group_id = module.matchmaker_nsg.network_security_group_id
}

#add this security rule to open another port in the NSG
module "matchmaker_security_rule_888x" {
  source = "../networking/security_rule"
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
  source = "../networking/security_rule"
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
  source = "../compute/vmss"
  base_name = var.base_name
  vm_name = format("%s%s", var.base_name, "vmss")
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

output "public_ip_address" {
    value = module.compute-vmss.public_ip_address
}

module "compute-autoscale" {
  source = "../compute/autoscale"
  base_name = var.base_name
  resource_group = module.unreal-rg.resource_group
  vmss_id = module.compute-vmss.id
  capacity_default = var.capacity_default
  capacity_minimum = var.capacity_minimum
  capacity_maximum = var.capacity_maximum
}
