#set the variable
$base_name = "82bdz"

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