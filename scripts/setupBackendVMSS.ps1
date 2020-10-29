[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
choco upgrade git directx nodejs -y --no-progress
Set-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Force

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

$RunPixelStreamer = "C:\Unreal\iac\unreal\App\WindowsNoEditor\PixelStreamer.exe"
$arg1 = "-AudioMixer"
$arg2 = "-PixelStreamingIP=localhost"
$arg3 = "-PixelStreamingPort=8888"
$arg4 = "-RenderOffScreen"

& $RunPixelStreamer $arg1 $arg2 $arg3 $arg4

$vmServiceFolder = "C:\Unreal\iac\unreal\App\WindowsNoEditor\Engine\Source\Programs\PixelStreaming\WebServers\SignallingWebServer"
cd $vmServiceFolder 

#$RunVMSSService = ".\runAWS_WithTURN.bat"
#& $RunVMSSService

#need to change this as an exec 
start-process "cmd.exe" "/c .\runAWS_WithTURN.bat"
