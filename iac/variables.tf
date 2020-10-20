variable "location" {
  description = "Location of the network"
  default     = "eastus"
}

variable "vnet_address_space" {
  default = "10.100.0.0/16"
}

variable "subnet_address_prefixes" {
  default = "10.100.0.0/18"
}