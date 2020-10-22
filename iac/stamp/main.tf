variable "base_name" {
  type        = string
}

variable "location" {
  description = "Location of the region"
}

variable "index" {
  type = string
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
  index = var.index
}

//add an external load balancer in front of the matchmaker vm
module "matchmaker-elb" {
  source         = "../networking/elb"
  base_name      = var.base_name
  lb_name        = "mm"
  resource_group = module.unreal-rg.resource_group
  domain_name_label = format("%s-%s-%s", var.location, lower(var.base_name), "mm")

  nat_pool_frontend_port_start = 80
  nat_pool_frontend_port_end = 90
  nat_pool_backend_port = 90

  sku = "Standard"
  subnet_id = module.unreal-vnet.subnet_id
  private_ip_address = "10.100.0.100"
  private_ip_address_allocation = "Static"
}

module "ue4-elb" {
  source         = "../networking/elb"
  base_name      = var.base_name
  resource_group = module.unreal-rg.resource_group
  lb_name        = "ue4"
  domain_name_label = format("%s-%s-%s", var.location, lower(var.base_name), "ue4")

  nat_pool_frontend_port_start = 80
  nat_pool_frontend_port_end = 90
  nat_pool_backend_port = 90

  sku = "Standard"
  subnet_id = module.unreal-vnet.subnet_id
  private_ip_address = "10.100.0.110"
  private_ip_address_allocation = "Static"
}

#windows based matchmaking server with no pip as it is behind a ELB
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

  lb_backend_address_pool_id = module.matchmaker-elb.lb_backend_address_pool_id
  lb_nat_pool_id = module.matchmaker-elb.lb_nat_pool_id
  ip_configuration_name   = format("%s-mm-config-%s", var.base_name, var.index)    
}

# add the matchmaker vm to the elb
module "vm_to_backend_pool" {
  source = "../networking/backendpoolassociation"
  network_interface_id    = module.matchmaker-vm.nic_id
  ip_configuration_name   = format("%s-mm-config-%s", var.base_name, var.index)  
  backend_address_pool_id = module.matchmaker-elb.lb_backend_address_pool_id
}

#add the first NSG for the matchmaker nic
module "matchmaker_nsg" {
  source = "../networking/nsg"
  base_name = var.base_name
  resource_group = module.unreal-rg.resource_group
  nsg_name = "mm-nsg"
  security_rule_name                       = "Open90"
  security_rule_priority                   = 1000
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "90"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

#associate the NSG to the NIC
module "matchmaker_nsg_association" {
  source = "../networking/nsgassociation"
  network_interface_id      = module.matchmaker-vm.nic_id
  network_security_group_id = module.matchmaker_nsg.network_security_group_id
}

#add this security rule to open another port in the NSG for the return from the UE4
module "matchmaker_security_rule_9999" {
  source = "../networking/security_rule"
  resource_group = module.unreal-rg.resource_group
  network_security_group_name = module.matchmaker_nsg.network_security_group_name

  security_rule_name                       = "Open9999"
  security_rule_priority                   = 1010
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "9999"
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

  sku = var.vmss_sku
  instances = var.vmss_start_instances
  upgrade_mode = "Manual"

  vm_publisher = var.matchmaker_vm_publisher
  vm_offer = var.matchmaker_vm_offer
  vm_sku = var.matchmaker_vm_sku
  vm_version = var.matchmaker_vm_version

  lb_backend_address_pool_id = module.ue4-elb.lb_backend_address_pool_id
  lb_nat_pool_id = module.ue4-elb.lb_nat_pool_id
  health_probe_id = module.ue4-elb.health_probe_id
}

/* not sure how to link an nsg to a vmss
module "ue4_nsg" {
  source = "../networking/nsg"
  base_name = var.base_name
  resource_group = module.unreal-rg.resource_group
  nsg_name = "ue4-nsg"
  security_rule_name                       = "Open7070"
  security_rule_priority                   = 1000
  security_rule_direction                  = "Inbound"
  security_rule_access                     = "Allow"
  security_rule_protocol                   = "Tcp"
  security_rule_source_port_range          = "*"
  security_rule_destination_port_range     = "7070"
  security_rule_source_address_prefix      = "*"
  security_rule_destination_address_prefix = "*"
}

#associate the NSG to the NIC
module "ue4_nsg_association" {
  source = "../networking/nsgassociation"
  network_interface_id      = module.compute-vmss.nic_id
  network_security_group_id = module.ue4_nsg.network_security_group_id
}

module "matchmaker_security_rule_888x" {
  source = "../networking/security_rule"
  resource_group = module.unreal-rg.resource_group
  network_security_group_name = module.ue4_nsg.network_security_group_name

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
*/

/* disabled as code is now in code on the VMSS Servers
module "compute-autoscale" {
  source = "../compute/autoscale"
  base_name = var.base_name
  resource_group = module.unreal-rg.resource_group
  vmss_id = module.compute-vmss.id
  capacity_default = var.capacity_default
  capacity_minimum = var.capacity_minimum
  capacity_maximum = var.capacity_maximum
}
*/