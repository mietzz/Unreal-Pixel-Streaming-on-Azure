variable "virtual_machine_scale_set_id" {
    type = string
}

variable "extension_name" {
    type = string
}

resource "azurerm_virtual_machine_scale_set_extension" "ue4extension" {
  name                 = var.extension_name
  depends_on           = []
  virtual_machine_scale_set_id    = var.virtual_machine_scale_set_id 
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = <<SETTINGS
  {
    "fileUris": [
      "https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupBackendVMSS.ps1"],
    "commandToExecute": "powershell.exe ./setupBackendVMSS.ps1"
  }
  SETTINGS

  protected_settings = <<PROTECTED_SETTINGS
  {
  }
  PROTECTED_SETTINGS  
}