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

resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

resource "azurerm_traffic_manager_profile" "tm" {
  name                   = random_id.server.hex
  resource_group_name    = var.resource_group.name
  traffic_routing_method = "Geographic"

  dns_config {
    relative_name = random_id.server.hex
    ttl           = 100
  }

  monitor_config {
    protocol                     = "http"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 9
    tolerated_number_of_failures = 3
  }
}

resource "azurerm_traffic_manager_endpoint" "tm_endpoint" {
  name                = random_id.server.hex
  resource_group_name = var.resource_group.name
  profile_name        = azurerm_traffic_manager_profile.tm.name
  target              = "terraform.io"  
  type                = "externalEndpoints"
  weight              = 100
}