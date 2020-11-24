# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# This is optionally used by a pixel streaming app to reset the UE4 exe when a user disconnects

try {
    #Change name for the process to your executable name
    $processes = Get-Process ProjectEverywhere* 
    write-host "Processes: " $processes.Count
    $finalPath = ""
    $finalArgs = ""
    if($processes.Count -gt 0)
    {
        foreach($process in $processes)
        {
            $path = $process.Path
            $procID = $process.Id
            $cmdline = (Get-WMIObject Win32_Process -Filter "Handle=$procID").CommandLine

            write-host "Restarting UE4 app: " $process.MainWindowTitle
            write-host "Command Line: " + $cmdline
            write-host "Command Line Split Args: " $cmdline.substring($cmdline.IndexOf("-AudioMixer"))
    
            $process.Kill()
            $process.WaitForExit()
    
            Start-Sleep -s 1

            if($cmdline -Match "ProjectEverywhere.exe")
            {
                $finalPath = $path
                $finalArgs = $cmdline.substring($cmdline.IndexOf("-AudioMixer"))
            }
            else
            {
                Write-Host "Not restarting this process: " $procID
            }
        }

        #STart the final application
        Start-Process -FilePath $finalPath -ArgumentList $finalArgs
    }
    else
    {
        write-host "ProjectEverywhere not running when trying to restart"
    }
}
catch 
{
  Write-Host "ERROR:::An error occurred:"
  Write-Host $_
  Write-Host $_.ScriptStackTrace
}
