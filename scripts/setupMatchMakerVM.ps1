# Dowlloading the package Chocolatey
Get-PackageProvider -Name Chocolatey -ForceBootstrap

#Updating the package to trusted so that we don't get issue at install
Set-PackageSource -Name chocolatey -Trusted 

Install-package filezilla -Verbose -Force -ProviderName chocolatey

#Using Chocolatey install to install node.js
cinst nodejs

#Using Chhocolatey to install git
