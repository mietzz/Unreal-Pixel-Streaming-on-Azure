#rg, location, diag sa, network
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

variable "vm_size" {
   description = "VM Size for the client"
  type        = string
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

variable "dia_stg_acct_id" {
  description = "The diag storage account id for the VMs"
  type        = string
}

variable "storage_uri" {
  type = string
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

## outputs
output "admin_password" {
  value = var.admin_password
}

output "vm_id" {
    value = azurerm_windows_virtual_machine.vm.id
}

output "nic_id" {
  value = azurerm_network_interface.nic.id
}

## resources
resource "azurerm_network_interface" "nic" {
  name                = format("%s-nic", var.vm_name)
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name

  ip_configuration {
    name                          = "Internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "vm" {
  name                = format("%s-vm", var.vm_name)
  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  boot_diagnostics {
    //enabled = "true"
    storage_account_uri = var.storage_uri
  }  
}