## variables
variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
}

variable "resource_group" {
  description = "The RG for the storage account"
  type = object({
    id     = string
    location = string
    name   = string
  })
}

variable "account_tier" {
  type = string
}

variable "account_replication_type" {
  type = string
}

## outputs
output "storage_account" {
  value = azurerm_storage_account.storageaccount
}
## locals
locals {
  base_name = var.base_name
}

## resources
resource "azurerm_storage_account" "storageaccount" {
  name                     = format("%sstorageacct", var.base_name)
  resource_group_name      = var.resource_group.name
  location                 = var.resource_group.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
}
