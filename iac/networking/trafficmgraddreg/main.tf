variable "base_name" {
  description = "Base name to use for the resources"
  type        = string
}

variable "resource_group_name" {
    type = string
}

variable "traffic_manager_profile_name" {
    type = string
}

variable "region_resourceTargetId" {
    type = string
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_endpoint" {
  name                = format("%s-trafficmgr", var.base_name)
  resource_group_name = var.resource_group_name
  profile_name        = var.traffic_manager_profile_name
  target_resource_id  = var.region_resourceTargetId  
  type                = "externalEndpoints"
  weight              = 100
}