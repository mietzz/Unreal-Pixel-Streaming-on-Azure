# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.


$rootvariable = "fx38w"

#variables
$RG1 = $rootvariable + "-eastus-unreal-rg"
$RG2 = $rootvariable + "-westus-unreal-rg"
$RG3 = $rootvariable + "-westeurope-unreal-rg"
$RG4 = $rootvariable + "-southeastasia-unreal-rg"

$vmScaleSet = $rootvariable + "vmss";


$vmnames = az vmss list-instances -g $RG1 --name $vmScaleSet --output table --query "[].name" -o tsv

foreach($vmname in $vmnames)
{
    Write-Output "Processing for vm "+$vmname

}




#$vmname = az vmss list-instances --resource-group  $RG1 --name $--query "[].name" -o tsv

#Write-Output $vmname

#Set-VMVideo -VMName $vmname -HorizontalResolution 1920 -VerticalResolution 1200