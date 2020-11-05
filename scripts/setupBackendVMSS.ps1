Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [String]$subscription_id = "",
  [Parameter(Mandatory = $True, HelpMessage = "resource group name")]
  [String]$resource_group_name = "",
  [Parameter(Mandatory = $True, HelpMessage = "vmss name")]
  [String]$vmss_name = "",
  [Parameter(Mandatory = $True, HelpMessage = "application insights key")]
  [String]$application_insights_key = ""
)

[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco upgrade git directx nodejs -y --no-progress
Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Force

Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\SharedAccess\Parameters\FirewallPolicy\DomainProfile' -name "EnableFirewall" -Value 0
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\SharedAccess\Parameters\FirewallPolicy\PublicProfile' -name "EnableFirewall" -Value 0
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\services\SharedAccess\Parameters\FirewallPolicy\Standardprofile' -name "EnableFirewall" -Value 0 

#New-NetFirewallRule -DisplayName 'Matchmaker-OB-90' -Profile 'All' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 90
#New-NetFirewallRule -DisplayName 'Matchmaker-OB-9999' -Profile 'All' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 9999
#New-NetFirewallRule -DisplayName 'Matchmaker-OB-19302' -Profile 'All' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 19302
#New-NetFirewallRule -DisplayName 'Matchmaker-OB-19303' -Profile 'All' -Direction Outbound -Action Allow -Protocol TCP -LocalPort 19303

#New-NetFirewallRule -DisplayName 'Matchmaker-IB-80' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 80
#New-NetFirewallRule -DisplayName 'Matchmaker-IB-7070' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 7070
#New-NetFirewallRule -DisplayName 'Matchmaker-IB-8888' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8888
#New-NetFirewallRule -DisplayName 'Matchmaker-IB-8889' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8889

#New-NetFirewallRule -DisplayName 'Matchmaker-IB-19302' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 19302
#New-NetFirewallRule -DisplayName 'Matchmaker-IB-19303' -Profile 'All' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 19303

$folder = "c:\Unreal\"
if (-not (Test-Path -LiteralPath $folder)) {
  git clone -q https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git $folder
}
else {
  #rename the existing folder if exists
  $endtag = 'unreal-' + (get-date).ToString('MMddyyhhmmss')
  Rename-Item -Path $folder  -NewName $endtag -Force
  git clone -q https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git $folder
}

Invoke-WebRequest https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/WindowsNoEditor.zip -OutFile C:\WindowsNoEditor.zip

$blobDestination = $folder + '\iac\unreal\app'
$zipFileName = 'C:\WindowsNoEditor.zip'

Expand-Archive -LiteralPath $zipFileName -DestinationPath $blobDestination

#test:
$logoutput = $folder + 'ue4-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
Set-Content -Path $logoutput -Value $subscription_id
Add-Content -Path $logoutput -Value $resource_group_name
Add-Content -Path $logoutput -Value $vmss_name
Add-Content -Path $logoutput -Value $application_insights_key

$arg1 = "-AudioMixer"
$arg2 = "-PixelStreamingIP=localhost"
$arg3 = "-PixelStreamingPort=8888"
$arg4 = "-RenderOffScreen"

& $RunPixelStreamer $arg1 $arg2 $arg3 $arg4

$vmServiceFolder = "C:\Unreal\iac\unreal\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
cd $vmServiceFolder 

$mmConfigJson = (Get-Content  "config.json" -Raw) | ConvertFrom-Json
echo $mmConfigJson

$mmConfigJson.resourceGroup = $resource_group_name
$mmConfigJson.subscriptionId = $subscription_id
$mmConfigJson.virtualMachineScaleSet = $vmss_name
$mmConfigJson.appInsightsId = $application_insights_key

$mmConfigJson | ConvertTo-Json | set-content "config.json"

#$RunVMSSService = ".\runAzure.bat"
#& $RunVMSSService

#need to change this as an exec 
start-process "cmd.exe" "/c .\runAzure.bat"
