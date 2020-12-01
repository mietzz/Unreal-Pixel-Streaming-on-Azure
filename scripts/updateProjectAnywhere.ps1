# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.
#####################################################################################################
#base variables
#####################################################################################################
#$PixelStreamerFolder = "C:\Unreal\iac\unreal\App\WindowsNoEditor\"
$folder = "c:\Unreal\"
$PixelStreamerFolder = "C:\Unreal\iac\unreal\"
$PixelStreamerExecFile = $PixelStreamerFolder + "ProjectAnywhere.exe"

$zipfilepath = "https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/WindowsNoEditor_ProjectAnywhere.zip"
$zipfilename = "c:\WindowsNoEditor.zip"
$blobDestination = $folder + 'iac\unreal'
$scriptfile = $folder + 'scripts\OnClientDisconnected.ps1'
$newProjectAWFolder =  $folder + 'iac\unreal\ClemensMessestand'
$projectAWFolder =  $folder + 'iac\unreal\WindowsNoEditor\*'


$logsbasefolder = "C:\gaming"
$logsfolder = "c:\gaming\logs"
$logoutput = $logsfolder + '\ue4-updateVMSS-output' + (get-date).ToString('MMddyyhhmmss') + '.txt'

#ProjectAnywhere args
$arg1 = "-AudioMixer"
$arg2 = "-PixelStreamingIP=localhost"
$arg3 = "-PixelStreamingPort=8888"
$arg4 = "-RenderOffScreen"

#####################################################################################################
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force

try {
   New-EventLog -Source PixelStreamer -LogName Application -MessageResourceFile $PixelStreamerExecFile -CategoryResourceFile $PixelStreamerExecFile
}
catch {
   #do nothing, this is ok.
}
finally {
   $error.clear()    
}
 
#create a log folder if it does not exist
if (-not (Test-Path -LiteralPath $logsfolder)) {
   Write-Output "creating directory :" + $logsfolder
   $fso = new-object -ComObject scripting.filesystemobject
   if (-not (Test-Path -LiteralPath $logsbasefolder)) {
      $fso.CreateFolder($logsbasefolder)
      Write-Output "created gaming folder"
   }
   $fso.CreateFolder($logsfolder)
   Write-EventLog -LogName "Application" -Source "PixelStreamer" -EventID 3100 -EntryType Information -Message "Created logs folder"
}
else {
   Write-Output "Path already exists :" + $logsfolder
   Write-EventLog -LogName "Application" -Source "PixelStreamer" -EventID 3101 -EntryType Information -Message "log folder alredy exists"
}


$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
refreshEnv

Set-Content -Path $logoutput -Value "updateProjectAnywhere"

if (-not (Test-Path -LiteralPath $PixelStreamerFolder)) {
   $logMessage = "PixelStreamer folder :" + $PixelStreamerFolder + " doesn't exist" 
   Write-EventLog -LogName "Application" -Source "PixelStreamer" -EventID 3102 -EntryType Error -Message $logMessage
   Add-Content -Path $logoutput -Value $logMessage
}

Set-Location -Path $PixelStreamerFolder 
$logMessage = "current folder :" + $PixelStreamerFolder 
Add-Content -Path $logoutput -Value $logMessage

   $logMessage = "Downloading ProjectAnywhere zip file :" 
   Add-Content -Path $logoutput -Value $logMessage
   
   try
   {
      Remove-Item $zipFileName -recurse -force
      $logmessage = "Deleting Old zipFiler Complete"
      Add-Content -Path $logoutput -Value $logmessage

      $logmessage = "Downloading again WindowsNoEditor binaries from blob storage"
      Add-Content -Path $logoutput -Value $logmessage

      Invoke-WebRequest $zipfilepath -OutFile $zipfilename 
      # Adding a wait for zipfile download to complete
      #sleep for 15 seconds to wait for install processes to complete
      #Start-Sleep -s 15

      $checkFile = $zipFileName

      [Int]$zipFileSize = (Get-Item $checkFile).length

      $logmessage = "Zipfile size" + $zipFileSize

      Add-Content -Path $logoutput -Value $logmessage

      if($zipFileSize -lt 100000) {
         $logmessage = "Error:Zip file not downloaded correctly"
         Write-Output $logmessage
         Add-Content -Path $logoutput -Value $logmessage
      } else {
         $logmessage = "Zip file downloaded correctly"
         Write-Output $logmessage
         
         $removeFiles = $PixelStreamerFolder+"Project*"
         Remove-Item $removeFiles -recurse -force
         
         $logmessage = "Deleted Old Files ProjectAnywhere Folder Complete :"+$removeFiles
         Add-Content -Path $logoutput -Value $logmessage

         $logmessage = "Extracting WindowsNoEditor to " + $blobDestination
         Add-Content -Path $logoutput -Value $logmessage
         Expand-Archive -LiteralPath $zipFileName -DestinationPath $blobDestination -force
      
         $logmessage = "Extracting WindowsNoEditor Complete"
         Add-Content -Path $logoutput -Value $logmessage
         $logmessage = "Move Contents of WindowsNoEditor Folder to :" + $blobDestination
         #Write-Output $logmessage
         Add-Content -Path $logoutput -Value $logmessage

         Move-Item $projectAWFolder $blobDestination  -force
         $logmessage = "Moving Contents of WindowsNoEditor Folder Complete"
         Add-Content -Path $logoutput -Value $logmessage

         Copy-Item $scriptfile $newProjectAWFolder -force
         $logmessage = "Copying OnClientDisconnected Complete"
         
         Add-Content -Path $logoutput -Value $logmessage


      }
      
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
   


try {
& $PixelStreamerExecFile $arg1 $arg2 $arg3 $arg4 -WinX=0 -WinY=0 -ResX=1920 -ResY=1080 -Windowed -TimeLimit=300 -ForceRes
$logMessage = "started :" + $PixelStreamerExecFile 
}
catch {
   $logMessage = "Exception in starting Pixel Streamer : " + $_.Exception.Message
   Write-Output $logmessage
 }
 finally {
   $error.clear()
 }

Add-Content -Path $logoutput -Value $logMessage

