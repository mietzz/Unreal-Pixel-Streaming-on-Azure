# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
Param (
  [Parameter(Mandatory = $False, HelpMessage = "subscription id from terraform")]
  [String]$subscription_id = "",
  [Parameter(Mandatory = $False, HelpMessage = "resource group name")]
  [String]$resource_group_name = "",
  [Parameter(Mandatory = $False, HelpMessage = "vmss name")]
  [String]$vmss_name = "",
  [Parameter(Mandatory = $False, HelpMessage = "application insights key")]
  [String]$application_insights_key = "",
  [Parameter(Mandatory = $False, HelpMessage = "github access token")]
  [String]$pat = ""
)
Write-Output $subscription_id 
Write-Output $resource_group_name 
Write-Output $vmss_name
Write-Output $application_insights_key
Write-Output $pat
Write-Output $pat.Length

#####################################################################################################
#base variables
#####################################################################################################
$logsbasefolder = "C:\gaming"
$logsfolder = "c:\gaming\logs"
$stdout = $logsfolder + '\ue4-startMMS-stdout' + (get-date).ToString('MMddyyhhmmss') + '.txt'
$stderr = $logsfolder + '\ue4-startMMS-stderr' + (get-date).ToString('MMddyyhhmmss') + '.txt'

$folder = "c:\Unreal\"
$mmServiceFolder = "C:\Unreal\iac\unreal\Engine\Source\Programs\PixelStreaming\WebServers\Matchmaker"

#$gitpath = "https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git"
$gitpath = "https://github.com/danmanrique/Unreal-Pixel-Streaming-on-Azure/"

#handle if a Personal Access Token is being passed
if ($pat.Length -gt 0) {
  #handle if a PAT was passed and use that in the url
  $gitpath = "https://" + $pat + "@github.com/danmanrique/Unreal-Pixel-Streaming-on-Azure.git"
  Write-Output $gitpath
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

$logoutput = $logsfolder + '\ue4-updateMMS-output-' + (get-date).ToString('MMddyyhhmmss') + '.txt'
Write-Output $logoutput

$logmessage = "Starting at: " + (get-date).ToString('hh:mm:ss')
Add-Content -Path $logoutput -Value $logmessage

Write-Output $logoutput

$nodeProcesses = Get-Process node* 

$logmessage = "Processes: " +  $nodeProcesses.Count
Add-Content -Path $logoutput -Value $logmessage
Write-Output $logmessage

if($nodeProcesses.Count -gt 0)
{
    foreach($process in $nodeProcesses)
    {
        $path = $process.Path
        $procID = $process.Id
        
        
        $logmessage = "Stoping UE4 app: " +  $process.MainWindowTitle
        Add-Content -Path $logoutput -Value $logmessage
        Write-Output $logmessage

        $logmessage = "Stopping Node processId " + $procID
        Add-Content -Path $logoutput -Value $logmessage
        Write-Output $logmessage

        try 
        {
            $process | Stop-Process -Force
            $logmessage = "Stopped UE4 app: Successful"
            Add-Content -Path $logoutput -Value $logmessage
            Write-Output $logmessage
        }
        catch 
        {
            $logmessage = "ERROR:::An error occurred when stopping process: "
            Add-Content -Path $logoutput -Value $logmessage
            Write-Output $logmessage
            try 
            {
                $logmessage = "Stoping UE4 app try2: "
                Add-Content -Path $logoutput -Value $logmessage
                Write-Output $logmessage
                Start-Sleep -s 1                
                $process.Kill()
                $process.WaitForExit(1000)
                $logmessage = "Stopped UE4 app try2: Successful"
                Add-Content -Path $logoutput -Value $logmessage
                Write-Output $logmessage
            }
            catch 
            {
              $logmessage = "Error in killing the process try2" + $_.Exception.Message
              Write-Output $logmessage
              Add-Content -Path $logoutput -Value $logmessage
            }
        }
    }
 }

try {
  $logmessage = "Refreshing the environment variable"
  Add-Content -Path $logoutput -Value $logmessage

  $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
  refreshenv

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
    $logmessage = "Creating folder" + $endtag
    Add-Content -Path $logoutput -Value $logmessage
    Rename-Item -Path $folder  -NewName $endtag -Force
    $logmessage = "Created folder" + $endtag
    Add-Content -Path $logoutput -Value $logmessage
    git clone -q $gitpath $folder
  }
  $logmessage = "Git cloning Complete"
  Add-Content -Path $logoutput -Value $logmessage

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

  $logmessage = "Starting the MMS Process "
  Add-Content -Path $logoutput -Value $logmessage

  start-process "cmd.exe" "/c .\run.bat" -RedirectStandardOutput $stdout -RedirectStandardError $stderr

  $logmessage = "Completed at: " + (get-date).ToString('hh:mm:ss')
  Add-Content -Path $logoutput -Value $logmessage
  exit 0
}
catch {
  $logmessage = "Exception :" + $_.Exception.Message
  Write-Output $logmessage
  Add-Content -Path $logoutput -Value $logmessage
  exit 1
}
finally {
  $error.clear()
}
