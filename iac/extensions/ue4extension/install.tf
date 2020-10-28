variable "virtual_machine_scale_set_id" {
    type = string
}

variable "extension_name" {
    type = string
}

resource "azurerm_virtual_machine_scale_set_extension" "ue4extension" {
  name                 = var.extension_name
  virtual_machine_scale_set_id    = var.virtual_machine_scale_set_id 
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command \"./setupBackendVMSS.ps1; exit 0;\""
  }
  SETTINGS
    protected_settings = <<PROTECTED_SETTINGS
    {
    "fileUris": ["https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupBackendVMSS.ps1?raw=true"]
    }
  PROTECTED_SETTINGS  
}

