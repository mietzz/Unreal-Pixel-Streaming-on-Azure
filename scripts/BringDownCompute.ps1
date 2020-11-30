#variables
$rootvariable = "fx38w"

#step 1 delete the resource groups
$rg1 = $rootvariable + "-eastus-unreal-rg"
$rg2 = $rootvariable + "-westeurope-unreal-rg"
$rg3 = $rootvariable + "-westus-unreal-rg"
$rg4 = $rootvariable + "-southeastasia-unreal-rg"
$rg5 = $rootvariable + "-global-unreal-rg"

$vm = $rootvariable + "-mm-vm0"
$vmss = $rootvariable + "vmss"

function handleenv($rg) {

    Write-Output ""
    Write-Output "----------------------------------"
    Write-Output "Addressing: " + $rg
    Write-Output "----------------------------------"
    Write-Output "Date/Time (UTC): " + (get-date).ToString('MM/dd/yy hh:mm:ss')
    Write-Output ""

    #change instance count to 2
    Write-Output "Scaling down VMSS"
    az vmss scale --name $vmss --new-capacity 2 --resource-group $rg --only-show-errors

    #restart vm
    Write-Output "Restarting VM"
    az vm restart -g $rg -n $vm --only-show-errors

    #restart vmss
    Write-Output "Restarting VMSS"
    az vmss restart --name $vmss --resource-group $rg --only-show-errors
    return
}

handleenv($rg1)
handleenv($rg2)
handleenv($rg3)
handleenv($rg4)

Write-Output "Date/Time (UTC): " + (get-date).ToString('MM/dd/yy hh:mm:ss')
Write-Output "Processing Complete"
