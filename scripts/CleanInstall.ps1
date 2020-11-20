#this script is to create an environment from absolute scratch

#variables
$rootiacfolder = "I:\dlm\Repos\Unreal-Pixel-Streaming-on-Azure\iac\"
$statefile = $rootiacfolder + "terraform.tfstate"
$statebackupfile = $rootiacfolder + "terraform.tfstate.backup"

#delete the tf state
If (Test-Path $statefile){
	Remove-Item $statefile
}
If (Test-Path $statebackupfile){
	Remove-Item $statebackupfile
}

#apply
Set-Location -Path $rootiacfolder
terraform apply -var 'git-pat=d7ee9c633cabf02400f838a1bdd430a1fb6e6226' -parallelism=24 --auto-approve

#get parameters from state file
$ConfigJson = (Get-Content  $statefile -Raw) | ConvertFrom-Json
$base_name = $ConfigJson.resources[0].instances[0].attributes.id 

#post deployment
$t = az ad signed-in-user show
$t = "$t"
$j = ConvertFrom-Json $t
$myobjectid = $j.objectId

#akv string
$akv = "akv-" + $base_name + "-eastus"

#akv give me list permissions
az keyvault set-policy --name $akv --object-id $myobjectid --secret-permissions get list set delete

#akv get secrets
$r1 = $base_name + "-eastus-password"
$kv1 = Get-AzKeyVaultSecret -Name $r1 -VaultName $akv
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kv1.SecretValue)
try {
   $secretValueText1 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

$r2 = $base_name + "-westus-password"
$kv2 = Get-AzKeyVaultSecret -Name $r2 -VaultName $akv
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kv2.SecretValue)
try {
   $secretValueText2 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

$r3 = $base_name + "-westeurope-password"
$kv3 = Get-AzKeyVaultSecret -Name $r3 -VaultName $akv
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kv3.SecretValue)
try {
   $secretValueText3 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

$r4 = $base_name + "-southeastasia-password"
$kv4 = Get-AzKeyVaultSecret -Name $r4 -VaultName $akv
$ssPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($kv4.SecretValue)
try {
   $secretValueText4 = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ssPtr)
} finally {
   [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ssPtr)
}

Write-Output $r1 + " password: " + $secretValueText1
Write-Output $r2 + " password: " + $secretValueText2
Write-Output $r3 + " password: " + $secretValueText3
Write-Output $r4 + " password: " + $secretValueText4

$rgname = $base_name + "-global-unreal-rg"
$tmname = $base_name + "-trafficmgr-mm"

$tm = az network traffic-manager profile show -g $rgname -n $tmname | ConvertFrom-Json
Write-Output "TM: http://" $tm.dnsConfig.fqdn + ":90"

