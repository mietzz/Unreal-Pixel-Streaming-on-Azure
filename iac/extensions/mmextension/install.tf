variable "virtual_machine_ids" {
  type = list(object({ id = string }))
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
  source = "./setupMatchMakerVM.ps1"
}

#original command: "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"./setupMatchMakerVM.ps1; exit 0;\""
resource "azurerm_virtual_machine_extension" "mmextension" {
  count                = length(var.virtual_machine_ids)
  name                 = var.extension_name
  virtual_machine_id   = var.virtual_machine_ids[count.index].id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  #auto_upgrade_minor_version = true

  settings           = <<SETTINGS
  {
    "commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ${local.source} -subscription_id ${var.subscription_id} -resource_group_name ${var.resource_group_name} -vmss_name ${var.vmss_name} -application_insights_key ${var.application_insights_key}"
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
    "fileUris": ["https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupMatchMakerVM.ps1?raw=true"]
    }
  PROTECTED_SETTINGS  
}

//"commandToExecute": "powershell.exe -ExecutionPolicy Unrestricted -File ${azurerm_storage_blob.configure-dc-01.name} -DomainPrefix ${var.dc_domain_prefix} -DomainName ${var.dc_domain_name} -SafeModeAdministratorPassword ${var.dc_safe_mode_password} -User ${var.dc_username} -Password ${var.dc_password}"
