// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

variable "virtual_machine_scale_set_id" {
  type = string
}

variable "extension_name" {
  type = string
}

resource "azurerm_virtual_machine_scale_set_extension" "MMAExtension" {
  name                         = var.extension_name
  virtual_machine_scale_set_id = var.virtual_machine_scale_set_id
  publisher                    = "Microsoft.Azure.Monitoring.DependencyAgent"
  type                         = "DependencyAgentWindows"
  type_handler_version         = "9.5"
  auto_upgrade_minor_version   = true

  settings           = <<SETTINGS
  {
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
    }
  PROTECTED_SETTINGS  
}
