variable "virtual_machine_id" {
    type = string
}

variable "extension_name" {
    type = string
}

resource "azurerm_virtual_machine_extension" "mmextension" {
  name                 = var.extension_name
  virtual_machine_id   = var.virtual_machine_id
  publisher = "Microsoft.Compute"
  type = "CustomScriptExtension"
  type_handler_version = "1.9"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
  {
    "fileUris": [
      "https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupMatchMakerVM.ps1"],
    "commandToExecute": "powershell.exe ./setupMatchMakerVM.ps1"
  }
  SETTINGS

#  protected_settings = <<PROTECTED_SETTINGS
#  {
#  }
#  PROTECTED_SETTINGS  
}