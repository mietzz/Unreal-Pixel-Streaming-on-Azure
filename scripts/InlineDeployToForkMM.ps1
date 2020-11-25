#variables to set
##Copyright (c) Microsoft Corporation.
## Licensed under the MIT license.
# The Script downloads the code on the MMS server from git
Param (
  [Parameter(Mandatory = $True, HelpMessage = "subscription id from terraform")]
  [String]$subscription_id = "",
  [Parameter(Mandatory = $True, HelpMessage = "resource group name")]
  [String]$resource_group_name = "",
  [Parameter(Mandatory = $True, HelpMessage = "vmss name")]
  [String]$vmss_name = "",
  [Parameter(Mandatory = $True, HelpMessage = "application insights key")]
  [String]$application_insights_key = "",
  [Parameter(Mandatory = $False, HelpMessage = "github access token")]
  [String]$pat = ""
)
#$rootvariable = "mj6s1"
$rootvariable = "fx38w"

#variables
$RG1 = $rootvariable + "-eastus-unreal-rg"
$RG2 = $rootvariable + "-westus-unreal-rg"
$RG3 = $rootvariable + "-westeurope-unreal-rg"
$RG4 = $rootvariable + "-southeastasia-unreal-rg"

#set the base github path for the unreal code

#for each rg

$vmids = az vm list --resource-group  $RG1 --query "[].id" -o tsv
#$vmids = az vm list --resource-group  $RG2 --query "[].id" -o tsv
$vmname = az vm list --resource-group  $RG1 --query "[].name" -o tsv
$mmsArgs =  $subscription_id + " " + $resource_group_name + " " + $vmss_name + " " + $application_insights_key
Write-Output $mmsArgs
$mmsArgs = $mmsArgs + " " + $pat
Write-Output $vmids
Write-Output $vmname

#az vm run-command invoke --command-id RunPowerShellScript --ids $vmids --scripts ' echo hello ' 

#az vm run-command invoke --command-id RunPowerShellScript --ids $vmids  --scripts "@./updateAndRestartMMS.ps1"  $mmsArgs

#$mmsArgs =  $subscription_id + " " + $resource_group_name + " " + $vmss_name + " " + $application_insights_key
#$mmsArgs =  $subscription_id + " " + $resource_group_name + " " + $vmss_name + " " + $application_insights_key
Invoke-AzVMRunCommand -ResourceGroupName $RG1 -VMName $vmname -CommandId 'RunPowerShellScript' -ScriptPath './updateAndRestartMMS.ps1' -Parameter @{"subscription_id" = "$subscription_id"; "pat" = "$pat";"resource_group_name" = "$resource_group_name";  "vmss_name" = "$vmss_name"; "application_insights_key"="$application_insights_key"}

    
