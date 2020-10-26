## variables
variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
}

variable "resource_group_name" {
    type = string
}

variable "traffic_routing_method" {
    type = string
    default = "Performance"
}

variable "service_name" {
    type = string
}

output "traffic_manager_profile_name" {
    value = azurerm_traffic_manager_profile.traffic_manager_profile.name
}

resource "azurerm_traffic_manager_profile" "traffic_manager_profile" {
  name                   = format("%s-trafficmgr-%s", var.base_name, var.service_name)
  resource_group_name    = var.resource_group_name
  traffic_routing_method = var.traffic_routing_method

  dns_config {
    relative_name = format("%s-trafficmgr", var.base_name)
    ttl           = 100
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

/*
resource "azurerm_traffic_manager_endpoint" "region1" {
  name                = format("%s-region1", var.base_name)
  resource_group_name = var.resource_group_name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager_profile.name
  target_resource_id  = var.region1_resourceTargetId
  type                = "azureEndpoints"
  priority            = 1
}

resource "azurerm_traffic_manager_endpoint" "region2" {
  name                = format("%s-region2", var.base_name)
  resource_group_name    = var.resource_group_name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager_profile.name
  target_resource_id  = var.region2_resourceTargetId
  type                = "azureEndpoints"
  priority            = 2
}
*/