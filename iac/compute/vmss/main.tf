variable "base_name" {
  type = string
}

variable "resource_group" {
  description = "The RG VMs"
  type = object({
    id     = string
    location = string
    name   = string
  })
}

variable "vm_publisher" {
  type        = string
}

variable "vm_offer" {
  type        = string
}

variable "vm_sku" {
  type        = string
}

variable "vm_version" {
  type        = string
}

variable "subnet_id" {
  description = "Subnet to use for the vms"
  type        = string
}

variable "admin_username" {
  description = "user name for the VMs"
  type        = string
}

variable "admin_password" {
  description = "Password for the VMs"
  type        = string
}

variable "vm_name" {
  type = string
}

variable "sku" {
    type = string
}

variable "instances" {
    type = string
}

output "id" {
    value = azurerm_windows_virtual_machine_scale_set.vmss.id
}

output "public_ip_address" {
    value = azurerm_public_ip.pip.ip_address
}

resource "azurerm_public_ip" "pip" {
  name                = format("%s-lb-pip", var.base_name)
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb" {
  name                = format("%s-lb", var.base_name)
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  frontend_ip_configuration {
    name                 = "internal"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_address_pool" {
  name                = format("%s-backend-pool", var.base_name)
  #location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  loadbalancer_id     = azurerm_lb.lb.id
}

resource "azurerm_lb_nat_pool" "lb_nat_pool" {
  name                           = format("%s-nat-pool", var.base_name)
  resource_group_name            = var.resource_group.name
  loadbalancer_id                = azurerm_lb.lb.id
  frontend_ip_configuration_name = "internal"
  protocol                       = "Tcp"
  frontend_port_start            = 80
  frontend_port_end              = 90
  backend_port                   = 8080
}

resource "azurerm_lb_probe" "probe" {
  name                = format("%s-lb_probe", var.base_name)
  resource_group_name = var.resource_group.name
  loadbalancer_id     = azurerm_lb.lb.id
  port                = 22
  protocol            = "Tcp"
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = format("%s-lb-rule", var.base_name)
  resource_group_name            = var.resource_group.name
  loadbalancer_id                = azurerm_lb.lb.id
  probe_id                       = azurerm_lb_probe.probe.id
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_address_pool.id
  frontend_ip_configuration_name = "internal"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
}

resource "azurerm_windows_virtual_machine_scale_set" "vmss" {
  name                = var.vm_name
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  #size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password

  sku                 = var.sku
  instances           = var.instances

  health_probe_id     = azurerm_lb_probe.probe.id
  upgrade_mode        = "Rolling"

  source_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "vmss-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = var.subnet_id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.lb_backend_address_pool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lb_nat_pool.id]      
    }
  }

  rolling_upgrade_policy {
    max_batch_instance_percent              = 21
    max_unhealthy_instance_percent          = 22
    max_unhealthy_upgraded_instance_percent = 23
    pause_time_between_batches              = "PT30S"
  }  
}