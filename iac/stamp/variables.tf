variable "vnet_address_space" {
  default = "10.100.0.0/16"
}

variable "subnet_address_prefixes" {
  default = "10.100.0.0/22"
}

variable "matchmaker_elb_private_ip_address" {
  default = "10.100.0.100"
}

variable "ue4_elb_private_ip_address" {
  default = "10.100.0.110"
}

#the following can only be 6 characters or less
variable "vm_name" {
  default = "mm"
}

variable "vm_count" {
  default = 3
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
  default = "2019-Datacenter"
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

variable "vmss_source_image_publisher" {
  default = "MicrosoftWindowsDesktop"
}

variable "vmss_source_image_offer" {
  default = "Windows-10"
}

variable "vmss_source_image_sku" {
  default = "20h2-pro"
}

variable "vmss_source_image_version" {
  default = "latest"
}
