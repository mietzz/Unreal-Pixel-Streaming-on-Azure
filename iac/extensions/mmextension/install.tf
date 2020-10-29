variable "virtual_machine_ids" {
  type = list(object({ id = string }))
}

variable "extension_name" {
  type = string
}

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
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"./setupMatchMakerVM.ps1; exit 0;\""
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
    {
    "fileUris": ["https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupMatchMakerVM.ps1?raw=true"]
    }
  PROTECTED_SETTINGS  
}

#  depends_on         = [azurerm_virtual_machine_extension.mmextension]
