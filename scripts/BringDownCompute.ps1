Param (
    [Parameter(Mandatory = $True, HelpMessage = "5 Character Env Prefix")]
    [String]$rootvariable = "",
    [Parameter(Mandatory = $True, HelpMessage = "Instances")]
    [int]$instances = 0
)

#check for 5 characters
if ($rootvariable.Length -ne 5) {
    Write-Output "Please enter the 5 character prefix (ex j6693)"
    return
}

#check for an int between 0 and 200
If ($instances -lt 0 -OR $instances -gt 200) {
    Write-Output "The second value is not a between 0 and 200"
    return
}

$rg1 = $rootvariable + "-eastus-unreal-rg"
$rg2 = $rootvariable + "-westeurope-unreal-rg"
$rg3 = $rootvariable + "-westus-unreal-rg"
$rg4 = $rootvariable + "-southeastasia-unreal-rg"

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
    Write-Output "Scaling VMSS to: " + $instances.ToString()
    #    az vmss scale --name $vmss --new-capacity $instances --resource-group $rg --only-show-errors

    #restart vm
    Write-Output "Restarting VM"
    #    az vm restart -g $rg -n $vm --only-show-errors

    #restart vmss
    Write-Output "Restarting VMSS"
    #    az vmss restart --name $vmss --resource-group $rg --only-show-errors
    return
}

handleenv($rg1)
handleenv($rg2)
handleenv($rg3)
handleenv($rg4)

Write-Output "Date/Time (UTC): " + (get-date).ToString('MM/dd/yy hh:mm:ss')
Write-Output "Processing Complete"