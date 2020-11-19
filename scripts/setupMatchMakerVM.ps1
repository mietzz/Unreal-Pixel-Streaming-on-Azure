# Copyright (c) Microsoft Corporation.
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

  [Parameter(Mandatory = $False, HelpMessage = "github access token")]
  [String]$pat = ""
)

#####################################################################################################
#base variables
#####################################################################################################
$logsbasefolder = "C:\gaming"
$logsfolder = "c:\gaming\logs"
$folder = "c:\Unreal\"
$mmServiceFolder = "C:\Unreal\iac\unreal\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker"
$executionfilepath = "C:\Unreal\scripts\startMMS.ps1"
$gitpath = "https://github.com/DanManrique/Unreal-Pixel-Streaming-on-Azure.git"

#handle if a Personal Access Token is being passed
if ($pat.Length -gt 0) {
  #handle if a PAT was passed and use that in the url
  $gitpath = "https://" + $pat + "@github.com/DanManrique/Unreal-Pixel-Streaming-on-Azure.git"
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

$logoutput = $logsfolder + '\ue4-setupMMS-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
Write-Output $logoutput

$logmessage = "Starting at: " + (get-date).ToString('hh:mm:ss')
Add-Content -Path $logoutput -Value $logmessage

try {
  $logmessage = "Downloading Chocolatey"
  Add-Content -Path $logoutput -Value $logmessage
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  $logmessage = "Downloading Chocolatey Complete"
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


try {
  $logmessage = "Installing prerequisites"
  Add-Content -Path $logoutput -Value $logmessage
  choco upgrade filezilla git nodejs vcredist2017 directx -y --no-progress
  $logmessage = "Installing prerequisites Complete"
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

Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Scope Global
Set-Alias -Name node -Value "$Env:ProgramFiles\nodejs\node.exe" -Scope Global
Set-Alias -Name npm -Value "$Env:ProgramFiles\nodejs\node_modules\npm" -Scope Global


#sleep for 5 seconds to wait for install processes to complete
Start-Sleep -s 5

$logmessage = "Refreshing env"
Add-Content -Path $logoutput -Value $logmessage

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
refreshenv

$logmessage = "Refreshing env complete"
Add-Content -Path $logoutput -Value $logmessage

New-NetFirewallRule -DisplayName 'Matchmaker-IB-90' -Profile 'Private' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 90
New-NetFirewallRule -DisplayName 'Matchmaker-IB-9999' -Profile 'Private' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 9999

New-NetFirewallRule -DisplayName 'Matchmaker-OB-80' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 80
New-NetFirewallRule -DisplayName 'Matchmaker-OB-7070' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 7070
New-NetFirewallRule -DisplayName 'Matchmaker-OB-8888' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 8888
New-NetFirewallRule -DisplayName 'Matchmaker-OB-8889' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 8889
New-NetFirewallRule -DisplayName 'Matchmaker-OB-19302' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 19302
New-NetFirewallRule -DisplayName 'Matchmaker-OB-19303' -Profile 'Private' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 19303

$logmessage = "Disabling Windows Firewalls complete"
Add-Content -Path $logoutput -Value $logmessage

try {
  $logmessage = "Cloning code from git"
  Add-Content -Path $logoutput -Value $logmessage
  if (-not (Test-Path -LiteralPath $folder)) {
    $logmessage = $folder + " doesn't exist"
    Add-Content -Path $logoutput -Value $logmessage
    git clone -q $gitpath $folder
  }
  else {
    #rename the existing folder
    $logmessage = $folder + " exist"
    Add-Content -Path $logoutput -Value $logmessage
    $endtag = 'unreal-' + (get-date).ToString('MMddyyhhmmss')
    Rename-Item -Path $folder  -NewName $endtag -Force
    git clone -q $gitpath $folder
  }
  $logmessage = "Git cloning Complete"
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

Set-Location -Path $mmServiceFolder 

$logmessage = "Current folder " + $mmServiceFolder
Add-Content -Path $logoutput -Value $logmessage

Add-Content -Path $logoutput -Value $subscription_id
Add-Content -Path $logoutput -Value $resource_group_name
Add-Content -Path $logoutput -Value $vmss_name
Add-Content -Path $logoutput -Value $application_insights_key

$mmConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
Write-Output $mmConfigJson
$logmessage = "Config json before update" + $mmConfigJson
Add-Content -Path $logoutput -Value $logmessage

$mmConfigJson.resourceGroup = $resource_group_name
$mmConfigJson.subscriptionId = $subscription_id
$mmConfigJson.virtualMachineScaleSet = $vmss_name
$mmConfigJson.appInsightsId = $application_insights_key

$mmConfigJson | ConvertTo-Json | set-content "config.json"

# Reading again to confirm the update
$mmConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
Write-Output $mmConfigJson

$logMessage = "Writing parameters from extension complete. Updated config :" + $mmConfigJson
Add-Content -Path $logoutput -Value $logMessage

$logmessage = "Creating a job schedule "
Add-Content -Path $logoutput -Value $logmessage

$trigger = New-JobTrigger -AtStartup -RandomDelay 00:00:10
try {
  $User = "azureadmin"
  $PS = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-executionpolicy bypass -noprofile -file $executionfilepath"
  Register-ScheduledTask -Trigger $trigger -User $User -TaskName "StartMMS" -Action $PS -RunLevel Highest -Force 
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

$logmessage = "Starting the MMS Process "
Add-Content -Path $logoutput -Value $logmessage

#invoke the script to start it this time
Invoke-Expression -Command $executionfilepath

$logmessage = "Completed at: " + (get-date).ToString('hh:mm:ss')
Add-Content -Path $logoutput -Value $logmessage
