[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force

Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); 

choco install git -yr --no-progress
choco install directx -yr --no-progress

New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Force

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


Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force

install-module azurerm -force

$StorageContext = New-AzureStorageContext -StorageAccountName 'unrealbackendfiles' -StorageAccountKey $key


$Container = Get-AzureStorageContainer -Name 'ourpublicblobs' -Context $StorageContext 

$blobDestination = $folder + '\iac\unreal\app'

Get-AzureStorageBlobContent -Container 'ourpublicblobs' -Blob "WindowsNoEditor.zip" -Destination $blobDestination -Context $StorageContext

exit 0
