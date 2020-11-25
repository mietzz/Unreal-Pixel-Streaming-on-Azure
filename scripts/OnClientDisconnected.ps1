# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# This is optionally used by a pixel streaming app to reset the UE4 exe when a user disconnects

try {
    #Change name for the process to your executable name
    $processes = Get-Process ProjectAnywhere* 
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
    
            try 
            {
                $process | Stop-Process -Force
            }
            catch 
            {
                Write-Host "ERROR:::An error occurred when stopping process: "
                Write-Host $_

                try 
                {
                    Start-Sleep -s 1
                    
                    $process.Kill()
                    $process.WaitForExit(1000)
                }
                catch 
                {
                    Write-Host "ERROR:::An error occurred when killing process: "
                    Write-Host $_
                }
            }

            Start-Sleep -s 1

            if($cmdline -Match "ProjectAnywhere.exe")
            {
                $finalPath = $path
                $finalArgs = $cmdline.substring($cmdline.IndexOf("-AudioMixer"))
            }
            else
            {
                Write-Host "Not restarting this process: " $procID
            }
        }

        try 
        {
            #Start the final application
            Start-Process -FilePath $finalPath -ArgumentList $finalArgs
        }
        catch 
        {
            Write-Host "ERROR:::An error occurred when starting the process: " $finalPath $finalArgs
            Write-Host $_
        }
    }
    else
    {
        write-host "ProjectAnywhere not running when trying to restart"
    }
}
catch 
{
  Write-Host "ERROR:::An error occurred:"
  Write-Host $_
  Write-Host $_.ScriptStackTrace
}
