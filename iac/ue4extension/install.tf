variable "virtual_machine_scale_set_id" {
    type = string
}

variable "extension_name" {
    type = string
}

/*
resource "azurerm_virtual_machine_scale_set_extension" "ue4_nvidia_drivers" {
  name                 = "NvidiaGpuDriverWindows"
  virtual_machine_scale_set_id    = var.virtual_machine_scale_set_id 
  publisher            = "Microsoft.HpcCompute"
  type                 = "NvidiaGpuDriverWindows"
  type_handler_version = "1.3"
  auto_upgrade_minor_version = true
}
*/

#az vmss extension set 
#-g 936v1-eastus-unreal-rg 
#--vmss-name 936v1vmss 
#--name CustomScript 
#--publisher Microsoft.Azure.Extensions 
#--version 2.0 
#--settings '{ \"fileUris\": [\"https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupBackendVMSS.ps1\"],\"commandToExecute\": \"powershell -ExecutionPolicy Unrestricted -File setupBackendVMSS.ps1\" }'

resource "azurerm_virtual_machine_scale_set_extension" "ue4extension" {
  name                 = var.extension_name
  virtual_machine_scale_set_id    = var.virtual_machine_scale_set_id 
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.0"

  settings = <<SETTINGS
  {
    "commandToExecute": "powershell -ExecutionPolicy Unrestricted -File \"setupBackendVMSS.ps1; exit 0;\""
  }
  SETTINGS
    protected_settings = <<PROTECTED_SETTINGS
    {
    "fileUris": ["https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure/blob/main/scripts/setupBackendVMSS.ps1"]
    }
  PROTECTED_SETTINGS  
}

