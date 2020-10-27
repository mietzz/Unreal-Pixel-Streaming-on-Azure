[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

choco upgrade git directx nvidia-display-driver -y --no-progress

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

#install the nvidia driver
Invoke-WebRequest https://unrealbackendfiles.blob.core.windows.net/ourpublicblobs/452.39_grid_win10_64bit_whql.exe -OutFile C:\452.39_grid_win10_64bit_whql.exe
C:\452.39_grid_win10_64bit_whql.exe -s
