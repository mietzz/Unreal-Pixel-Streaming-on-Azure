/* variable "location" {
  description = "Location of the network"
  default     = "eastus"
} */

variable "vnet_address_space" {
  default = "10.100.0.0/16"
}

variable "subnet_address_prefixes" {
  default = "10.100.0.0/18"
}

#the following can only be 6 characters or less
variable "vm_name" {
  default = "mm"
}

variable "matchmaker_vm_size" {
  default = "Standard_DS3_v2"
}

variable "matchmaker_vm_publisher" {    
  default = "MicrosoftWindowsServer"
}

variable "matchmaker_vm_offer" {        
  default = "WindowsServer"
}

variable "matchmaker_vm_sku" {          
  default = "2016-Datacenter"
}

variable "matchmaker_vm_version" {      
  default = "latest"  
}

variable "matchmaker_admin_username" {  
  default = "azureadmin"
}
/*
# we moved the autoscale from terraform config to code on the VMSS
variable "capacity_default" {
  default = 3
}
variable "capacity_minimum" {
  default = 1
}
variable "capacity_maximum" {
  default = 5
}
*/
variable "vmss_start_instances" {
  default = 2
}
variable "vmss_sku" {
  default = "Standard_NV6"
}