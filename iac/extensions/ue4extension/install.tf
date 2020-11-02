variable "virtual_machine_scale_set_id" {
  type = string
}

variable "extension_name" {
  type = string
}

variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "vmss_name" {
  type = string
}

variable "application_insights_key" {
  type = string
}

locals {
  source = "./setupBackendVMSS.ps1"
}

resource "azurerm_virtual_machine_scale_set_extension" "ue4extension" {
  name                         = var.extension_name
  virtual_machine_scale_set_id = var.virtual_machine_scale_set_id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"

  #original command:     "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"./setupBackendVMSS.ps1; exit 0;\""
  settings           = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ${local.source} -subscription_id ${var.subscription_id} -resource_group_id ${var.resource_group_name} -vmss_name ${var.vmss_name} -application_insights_key ${var.application_insights_key}"    
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
    "fileUris": ["https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupBackendVMSS.ps1?raw=true"]
    }
  PROTECTED_SETTINGS  
}

