Param (
    [Parameter(Mandatory = $True, HelpMessage = "root environment prefix")]
    [String]$rootvariable = ""
)

#this script is to delete an environment

#variables
#$rootvariable = "6kboy"
#$rootvariable = "fx38w"
#$vnetname = "jumpbox-vnet" 
$vnetname = "jumpbox-forked-vnet" 

#script

#step 1 delete the resource groups
$r1 = $rootvariable + "-eastus-unreal-rg"
az group delete --name $r1 --no-wait --yes

$r2 = $rootvariable + "-westeurope-unreal-rg"
az group delete --name $r2 --no-wait --yes

$r3 = $rootvariable + "-westus-unreal-rg"
az group delete --name $r3 --no-wait --yes

$r4 = $rootvariable + "-southeastasia-unreal-rg"
az group delete --name $r4 --no-wait --yes

$r5 = $rootvariable + "-global-unreal-rg"
az group delete --name $r5 --no-wait --yes

#step 2 delete the resource peerings if they exist
az network vnet peering delete --name LinkVnet1ToVnet2 --resource-group OtherAssets --vnet-name $vnetname
az network vnet peering delete --name LinkVnet1ToVnet3 --resource-group OtherAssets --vnet-name $vnetname
az network vnet peering delete --name LinkVnet1ToVnet4 --resource-group OtherAssets --vnet-name $vnetname
az network vnet peering delete --name LinkVnet1ToVnet5 --resource-group OtherAssets --vnet-name $vnetname
