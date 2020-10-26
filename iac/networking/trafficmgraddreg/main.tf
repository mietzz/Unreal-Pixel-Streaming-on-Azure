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

variable "index" {
    type = string
}

variable "service_name" {
    type = string
}

resource "azurerm_traffic_manager_endpoint" "traffic_manager_endpoint" {
  name                = format("%s-trafficmgr-%s-%s", var.base_name, var.service_name, var.index)
  resource_group_name = var.resource_group_name
  profile_name        = var.traffic_manager_profile_name
  target_resource_id  = var.region_resourceTargetId  
    #id of the matchmaker ELB
  type                = "azureEndpoints"
  priority            = var.index
}