variable "iis_vm_id" {
    type = string
}

resource "azurerm_virtual_machine_extension" "iis_ext" {
  name                 = "addIIStoWebServer"
  virtual_machine_id   = var.iis_vm_id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.4"

  settings = <<SETTINGS
    {
        "commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell      Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"
    }
SETTINGS
}