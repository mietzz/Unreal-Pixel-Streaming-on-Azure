variable "resource_group_name" {
  type        = string
}

variable "location" {
  type        = string
}

resource "azurerm_availability_set" "availset" {
  name                = "mm-availset"
  resource_group_name = var.resource_group_name
  location            = var.location
}