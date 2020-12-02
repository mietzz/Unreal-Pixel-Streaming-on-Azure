# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.


$rootvariable = "fx38w"

#variables
$RG1 = $rootvariable + "-eastus-unreal-rg"
$RG2 = $rootvariable + "-westus-unreal-rg"
$RG3 = $rootvariable + "-westeurope-unreal-rg"
$RG4 = $rootvariable + "-southeastasia-unreal-rg"

$vmScaleSet = $rootvariable + "vmss";

$vmnames = az vmss list-instances -g $RG1 --name $vmScaleSet --output table
Write-Output "Processing for vm :"$vmnames


foreach($vmname in $vmnames)
{
    Write-Output "Processing for vm name :"$vmname
}


$vmInstanceIds = az vmss list-instances -g $RG1 --name $vmScaleSet --output table --query "[].instanceId" -o tsv
Write-Output "Processing for vm instanceIds :"$vmInstanceIds




foreach($vmid in $vmInstanceIds)
{
    Write-Output "Processing for vm instance id:"$vmid
    az vmss run-command  invoke --command-id RunPowerShellScript --instance-id  $vmid -n $vmScaleSet -g $RG1 --scripts "@./updateProjectAnywhere.ps1"
}