# Dowlloading the package Chocolatey
Install-Module PowershellGet -Force 
#
#
Get-PackageProvider -Name Chocolatey -ForceBootstrap
#
# #Updating the package to trusted so that we don't get issue at install
Set-PackageSource -Name chocolatey -Trusted
#
#
Install-package filezilla -Verbose -Force -ProviderName chocolatey
#
#
Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
#
# #Using Chocolatey install to install node.js
choco install -fy nodejs
#
# #Using Chocolatey install to install git
choco install -fy git

New-Alias -Name git -Value "$Env:ProgramFiles\Git\bin\git.exe"


git clone https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git
