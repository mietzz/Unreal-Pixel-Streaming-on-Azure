# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

# This is optionally used by a pixel streaming app to reset the UE4 exe when a user disconnects

try {
    #Change name for the process to your executable name
    $processes = Get-Process ClemensMessestand* 
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

            if($cmdline -Match "ClemensMessestand.exe")
            {
                $finalPath = $path
                $finalArgs = $cmdline.substring($cmdline.IndexOf("-AudioMixer"))
            }
            else
            {
                Write-Host "Not restarting this process: " $procID
            }
        }        
    }
    else
    {
        write-host "ClemensMessestand not running when trying to restart"
    }

    try 
    {
        Start-Sleep -s 5

        $newProcesses = Get-Process ClemensMessestand*
        Write-Host "Checking processes restarted: " $newProcesses.Count
        if($newProcesses.Count -le 0)
        {
            #Start the final application if not already restarted
            Start-Process -FilePath "C:\Unreal\iac\unreal\ClemensMessestand.exe" -ArgumentList "-AudioMixer -PixelStreamingIP=localhost -PixelStreamingPort=8888 -WinX=0 -WinY=0 -ResX=1920 -ResY=1080 -Windowed -TimeLimit=300 -RenderOffScreen -ForceRes"
        }
    }
    catch 
    {
        Write-Host "ERROR:::An error occurred when starting the process: " "C:\Unreal\iac\unreal\ClemensMessestand.exe" "-AudioMixer -PixelStreamingIP=localhost -PixelStreamingPort=8888 -WinX=0 -WinY=0 -ResX=1920 -ResY=1080 -Windowed -TimeLimit=300 -RenderOffScreen -ForceRes"
        Write-Host $_
    }
}
catch 
{
  Write-Host "ERROR:::An error occurred:"
  Write-Host $_
  Write-Host $_.ScriptStackTrace
}
