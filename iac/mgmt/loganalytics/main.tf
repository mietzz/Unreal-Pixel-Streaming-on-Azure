## variables
variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
}

variable "resource_group_name" {
  type        = string
}

variable "location" {
  type        = string
}

output "workspace_id" {
    value = azurerm_log_analytics_workspace.logA.workspace_id
}

output "id" {
    value = azurerm_log_analytics_workspace.logA.id
}

resource "azurerm_log_analytics_workspace" "logA" {
  name                = format("%s-loganalytics-%s", var.base_name, lower(var.location))
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
}