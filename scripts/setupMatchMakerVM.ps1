[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;
Set-ExecutionPolicy Bypass -Scope Process -Force
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); 

choco upgrade filezilla -yr --no-progress
choco upgrade git -yr --no-progress
choco upgrade nodejs -yr --no-progress
choco upgrade vcredist-all -yr --no-progress
choco upgrade directx -yr --no-progress

New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe" -Force

export GITHUB_USER=anonuser
export GITHUB_TOKEN=(az keyvault secret show -n thekey --vault-name uegamingakv | ConvertFrom-Json).value
export GITHUB_REPOSITORY=Azure/Unreal-Pixel-Streaming-on-Azure

$folder = "c:\Unreal\"
if (-not (Test-Path -LiteralPath $folder)) {
    #git clone -q https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git $folder
    git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY} $folder
}
else {
    #rename the existing folder
    $endtag = 'unreal-' + (get-date).ToString('MMddyyhhmmss')
    Rename-Item -Path $folder  -NewName $endtag -Force
    #git clone -q https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git $folder
    git clone https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_REPOSITORY} $folder
}
exit 0