#Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [String]$subscription_id = "",
  [Parameter(Mandatory = $True, HelpMessage = "resource group name")]
  [String]$resource_group_name = "",
  [Parameter(Mandatory = $True, HelpMessage = "vmss name")]
  [String]$vmss_name = "",  
  [Parameter(Mandatory = $True, HelpMessage = "application insights key")]
  [String]$application_insights_key = "",
  [Parameter(Mandatory = $True, HelpMessage = "matchmaker load balancer fqdn")]
  [String]$mm_lb_fqdn = "",
  [Parameter(Mandatory = $False, HelpMessage = "github personal access token")]
  [String]$pat = ""
)

#####################################################################################################
#base variables
#####################################################################################################
<<<<<<< HEAD
$zipfilepath = "https://rockadman01.blob.core.windows.net/container-pixelstreaming/WindowsNoEditor.zip"
=======
$zipfilepath = "https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/WindowsNoEditor_ProjectAnywhere.zip"
>>>>>>> upstream/main
$zipfilename = "c:\WindowsNoEditor.zip"
$logsbasefolder = "C:\gaming"
$logsfolder = "c:\gaming\logs"
$folder = "c:\Unreal\"
$scriptfile = $folder + 'scripts\OnClientDisconnected.ps1'
<<<<<<< HEAD
$projectFolder =  $folder + 'iac\app\unreal\WindowsNoEditor'
$projectExecFolder =  $folder + 'iac\app\unreal\WindowsNoEditor\*'
=======
$projectFolder =  $folder + 'iac\unreal\ProjectAnywhere'
$projectExecFolder =  $folder + 'iac\unreal\WindowsNoEditor\*'
>>>>>>> upstream/main

$blobDestination = $folder + 'iac\unreal\app'
#$blobDestination = $folder + 'iac\unreal'
$vmServiceFolder = "C:\Unreal\iac\unreal\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
$executionfilepath = "C:\Unreal\scripts\startVMSS.ps1"
$gitpath = "https://github.com/mietzz/Unreal-Pixel-Streaming-on-Azure.git"

#handle if a Personal Access Token is being passed
if ($pat.Length -gt 0) {
  #handle if a PAT was passed and use that in the url
  $gitpath = "https://" + $pat + "@github.com/mietzz/Unreal-Pixel-Streaming-on-Azure.git"
}
#####################################################################################################

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
#create a log folder if it does not exist
if (-not (Test-Path -LiteralPath $logsfolder)) {
  Write-Output "creating directory :" + $logsfolder
  $fso = new-object -ComObject scripting.filesystemobject
  if (-not (Test-Path -LiteralPath $logsbasefolder)) {
    $fso.CreateFolder($logsbasefolder)
    Write-Output "created gaming folder"
  }
  $fso.CreateFolder($logsfolder)
}
else {
  Write-Output "Path already exists :" + $logsfolder
}

$logoutput = $logsfolder + '\ue4-setupVMSS-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
Write-Output $logoutput

$logmessage = "Starting at: " + (get-date).ToString('hh:mm:ss')
Add-Content -Path $logoutput -Value $logmessage
$logmessage = "Downloading Chocolatey"
Add-Content -Path $logoutput -Value $logmessage

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

$logmessage = "Downloading Chocolatey complete"
Add-Content -Path $logoutput -Value $logmessage

$logmessage = "Installing prerequisites"
Add-Content -Path $logoutput -Value $logmessage

$logmessage = "Installing Azure CLI"
Add-Content -Path $logoutput -Value $logmessage

choco upgrade git nodejs vcredist2017 directx azure-cli -y --no-progress
Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Scope Global
Set-Alias -Name node -Value "$Env:ProgramFiles\nodejs\node.exe" -Scope Global
Set-Alias -Name npm -Value "$Env:ProgramFiles\nodejs\node_modules\npm" -Scope Global

$INCLUDE = "C:\Program Files\nodejs;C:\Program Files (x86)\Microsoft SDKs\Azure"

$OLDPATH = [System.Environment]::GetEnvironmentVariable('PATH', 'machine')
$NEWPATH = "$OLDPATH;$INCLUDE"
[Environment]::SetEnvironmentVariable("PATH", "$NEWPATH", "Machine")

$logmessage = "Refreshing env"
Add-Content -Path $logoutput -Value $logmessage

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
refreshenv

$logmessage = "Refreshing env complete"
Add-Content -Path $logoutput -Value $logmessage

$logmessage = "Installing prerequisites complete"
Add-Content -Path $logoutput -Value $logmessage

#sleep for 45 seconds to wait for install processes to complete
Start-Sleep -s 5

$logmessage = "Disabling Windows Firewalls"
Add-Content -Path $logoutput -Value $logmessage

Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

#check if the disable of the firewall was successful, if not write an event to the event log
[string]$Domain = Invoke-command { netsh advfirewall show domain state }
[string]$Private = Invoke-command { netsh advfirewall show private state }
[string]$Public = Invoke-command { netsh advfirewall show public state }

$endsInOn = ($Domain.Contains("ON") -or $Private.Contains("ON") -or $Public.Contains("ON"));
if ($endsInOn) {
  #log the error
  $logmessage = "Disabling Windows Firewalls ***Failed***"
  Add-Content -Path $logoutput -Value $logmessage

  #event log the error
  Write-EventLog -LogName "Application" -Source "PixelStreamer" -EventID 3109 -EntryType Error -Message $logmessage
}

$logmessage = "Disabling Windows Firewalls complete"
Add-Content -Path $logoutput -Value $logmessage

$logmessage = "Cloning the github repo"
Add-Content -Path $logoutput -Value $logmessage

try {
  if (-not (Test-Path -LiteralPath $folder)) {
    $logmessage = $folder + "doesn't exist. Adding unreal"
    Add-Content -Path $logoutput -Value $logmessage
    git clone -q $gitpath $folder
  }
  else {
    #rename the existing folder if exists
    $logmessage = $folder + " already exists. Renaming."
    Add-Content -Path $logoutput -Value $logmessage

    $endtag = 'unreal-' + (get-date).ToString('MMddyyhhmmss')
    Rename-Item -Path $folder  -NewName $endtag -Force
    git clone -q $gitpath $folder
  }
  $logmessage = "Cloning the github repo complete"
  Add-Content -Path $logoutput -Value $logmessage
}
catch {
  $logmessage = $_.Exception.Message
  Write-Output $logmessage
  Add-Content -Path $logoutput -Value $logmessage
}
finally {
  $error.clear()
}


try{
  $logmessage = "Downloading WindowsNoEditor binaries from blob storage"
  Add-Content -Path $logoutput -Value $logmessage

  Invoke-WebRequest $zipfilepath -OutFile $zipfilename 
  # Adding a wait for zipfile download to complete
  #sleep for 2 seconds to wait for install processes to complete
  Start-Sleep -s 2

  $logmessage = "Downloading WindowsNoEditor binaries from blob storage complete"
  Add-Content -Path $logoutput -Value $logmessage

  $logmessage = "Extracting WindowsNoEditor to " + $blobDestination
  Add-Content -Path $logoutput -Value $logmessage
  Expand-Archive -LiteralPath $zipFileName -DestinationPath $blobDestination -force

  # Adding a wait for zipfile download to complete
  #sleep for 2 seconds to wait for install processes to complete
  Start-Sleep -s 2

  $logmessage = "Extracting WindowsNoEditor Complete"
  Add-Content -Path $logoutput -Value $logmessage

  $logmessage = "Copying WindowsNoEditor Folder:" 
  Write-Output $logmessage
  Add-Content -Path $logoutput -Value $logmessage

  Move-Item $projectExecFolder $blobDestination -force
  $logmessage = "Copying WindowsNoEditor Folder Complete"

  Add-Content -Path $logoutput -Value $logmessage

  Copy-Item $scriptfile $projectFolder -force
  $logmessage = "Copying OnClientDisconnected Complete"
  
  Add-Content -Path $logoutput -Value $logmessage
}
catch{
  $logmessage = $_.Exception.Message
  $logbasemessage = "Copying WindowsNoEditor Failed. Error: "
  Write-Output $logbasemessage + $logmessage 
  Add-Content -Path $logoutput -Value $logmessage
}
finally {
  $error.clear()
}


try{
   Set-Location -Path $vmServiceFolder 

   $logmessage = "Current folder " + $vmServiceFolder
   Add-Content -Path $logoutput -Value $logmessage

   $logmessage = "Writing paramters from extension " + $vmServiceFolder
   Add-Content -Path $logoutput -Value $logmessage

   $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
   Write-Output $vmssConfigJson

   $logMessage = "current config :" + $vmssConfigJson
   Add-Content -Path $logoutput -Value $logMessage

   $vmssConfigJson.resourceGroup = $resource_group_name
   $vmssConfigJson.subscriptionId = $subscription_id
   $vmssConfigJson.virtualMachineScaleSet = $vmss_name
   $vmssConfigJson.appInsightsId = $application_insights_key
   $vmssConfigJson.matchmakerAddress = $mm_lb_fqdn
   $vmssConfigJson.publicIp = $thispublicip

   $vmssConfigJson | ConvertTo-Json | set-content "config.json"
   $vmssConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
   Write-Output $vmssConfigJson

   $logMessage = "Writing parameters from extension complete. Updated config :" + $vmssConfigJson
   Add-Content -Path $logoutput -Value $logMessage
}
catch {
  $logmessage = "Exception: " + $_.Exception
  Write-Output $logmessage
  Add-Content -Path $logoutput -Value $logmessage
}
finally {
  $error.clear()    
}

$logmessage = "Creating a job schedule "
Add-Content -Path $logoutput -Value $logmessage

$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:10
try {
  $User = "NT AUTHORITY\SYSTEM"
  $PS = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy bypass -noprofile -file $executionfilepath"
  Register-ScheduledTask -Trigger $trigger -User $User -TaskName "StartVMSS" -Action $PS -RunLevel Highest -AsJob -Force
}
catch {
  $logmessage = "Exception: " + $_.Exception
  Write-Output $logmessage
  Add-Content -Path $logoutput -Value $logmessage
}
finally {
  $error.clear()    
}

$logmessage = "Creating a job schedule complete"
Add-Content -Path $logoutput -Value $logmessage

#install the nvidia extension on this vmss
$logMessage = "Starting the installation of the nVidia extension"
Add-Content -Path $logoutput -Value $logMessage

az login --identity
az account set --subscription $subscription_id
$isExtInstalled = az vmss extension show --name NvidiaGpuDriverWindows --resource-group $resource_group_name --vmss-name $vmss_name
if (!$isExtInstalled.Length -gt 0) {
  #install extension
  az vmss extension set -g $resource_group_name --vmss-name $vmss_name --name NvidiaGpuDriverWindows --publisher Microsoft.HpcCompute --version 1.3 --no-wait --settings '{ }'

  $logMessage = "Completed the installation of the nVidia extension"
  Add-Content -Path $logoutput -Value $logMessage
}
else {
  $logmessage = "nVidia Extension already installed "
  Add-Content -Path $logoutput -Value $logmessage
}

#just in case there is not a reboot, run the process...
$logmessage = "Starting the VMSS Process "
Add-Content -Path $logoutput -Value $logmessage

#invoke the script to start it this time
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force

Invoke-Expression -Command $executionfilepath

$logmessage = "Completed at: " + (get-date).ToString('hh:mm:ss')
Add-Content -Path $logoutput -Value $logmessage
