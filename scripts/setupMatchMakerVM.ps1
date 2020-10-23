
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;


#$currentDir = Get-Location | select -ExpandProperty Path

Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1')); choco install filezilla -y 

choco install git -y

choco install nodejs -y

New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe"


git clone -q -n https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git c:\Unreal\
