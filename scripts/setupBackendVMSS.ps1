$logfilepath = "C:\InstallLogs\"
$logfilename = "MyLogs.log"
$logfullpath = $logfilepath + $logfilename

function WriteToLogFile($message)
{​​
    Add-content $logfullpath -value $message
}

#delete if the output file exists already
if (Test-Path $logfilepath)
{
    #delete any existing output file
    Remove-Item $logfullpath
}

#create output directory if it does not exist
New-Item -ItemType Directory -Force -Path $logfilepath

WriteToLogFile "Starting the run"

WriteToLogFile "Line 1"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
WriteToLogFile "Line 2"
Set-ExecutionPolicy Bypass -Scope Process -Force
WriteToLogFile "Line 3"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
WriteToLogFile "Line 4"
choco upgrade git directx -y --no-progress
WriteToLogFile "Line 5"
Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Force

WriteToLogFile "Line 6"
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

WriteToLogFile "Line 7"
Invoke-WebRequest https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/WindowsNoEditor.zip -OutFile C:\WindowsNoEditor.zip

$blobDestination = $folder + '\iac\unreal\app'
$zipFileName = 'C:\WindowsNoEditor.zip'

WriteToLogFile "Line 8"
Expand-Archive -LiteralPath $zipFileName -DestinationPath $blobDestination

WriteToLogFile "Line 9"
#install the nvidia driver
Invoke-WebRequest https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/452.39_grid_win10_64bit_whql.exe -OutFile C:\unreal\452.39_grid_win10_64bit_whql.exe
C:\unreal\452.39_grid_win10_64bit_whql.exe -s

WriteToLogFile "Complete run"