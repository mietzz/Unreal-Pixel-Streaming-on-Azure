## variables
variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
}

/*
 variable "resource_group" {
  description = "The RG for the storage account"
  type = object({
    id     = string
    location = string
    name   = string
  })
}
*/
variable "resource_group_name" {
    type = string
}

variable "traffic_routing_method" {
    type = string
    default = "Weighted"
}

variable "region1_public_ip_address_id" {
    type = string
}

variable "region2_public_ip_address_id" {
    type = string
}

resource "azurerm_traffic_manager_profile" "traffic_manager_profile" {
  name                   = format("%s-trafficmgr", var.base_name)
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

resource "azurerm_traffic_manager_endpoint" "region1" {
  name                = format("%s-region1", var.base_name)
  resource_group_name = var.resource_group_name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager_profile.name
  target_resource_id  = var.region1_public_ip_address_id
  type                = "azureEndpoints"
  weight              = 100
}

resource "azurerm_traffic_manager_endpoint" "region2" {
  name                = format("%s-region2", var.base_name)
  resource_group_name    = var.resource_group_name
  profile_name        = azurerm_traffic_manager_profile.traffic_manager_profile.name
  target_resource_id  = var.region2_public_ip_address_id
  type                = "azureEndpoints"
  weight              = 100
}
