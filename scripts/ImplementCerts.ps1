#Create a certificate in Key Vault
$VaultName = "akv-fx38w-eastus"
$CertName = "ue4-backend-vmss-cert"
$SubjectName = "CN=ue4-backend-vmss-cert"

$policy = New-AzKeyVaultCertificatePolicy -SubjectName $SubjectName -IssuerName Self -ValidityInMonths 12
Add-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName -CertificatePolicy $policy

#Update virtual machine scale sets profile with certificate
$ResourceGroupName = "fx38w-eastus-unreal-rg"
$VMSSName = "fx38wvmss"
$CertStore = "My" # Update this with the store you want your certificate placed in, this is LocalMachine\My

# If you have added your certificate to the keyvault certificates, use
$CertConfig = New-AzVmssVaultCertificateConfig -CertificateUrl (Get-AzKeyVaultCertificate -VaultName $VaultName -Name $CertName).SecretId -CertificateStore $CertStore

# Otherwise, if you have added your certificate to the keyvault secrets, use
#$CertConfig = New-AzVmssVaultCertificateConfig -CertificateUrl (Get-AzKeyVaultSecret -VaultName $VaultName -Name $CertName).Id -CertificateStore $CertStore

$VMSS = Get-AzVmss -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMSSName

# If this KeyVault is already known by the virtual machine scale set, for example if the cluster certificate is deployed from this keyvault, use
$VMSS.virtualmachineprofile.osProfile.secrets[0].vaultCertificates.Add($CertConfig)

# Otherwise use
$VMSS = Add-AzVmssSecret -VirtualMachineScaleSet $VMSS -SourceVaultId (Get-AzKeyVault -VaultName $VaultName).ResourceId  -VaultCertificate $CertConfig

#Update the virtual machine scale set
Update-AzVmss -ResourceGroupName $ResourceGroupName -VirtualMachineScaleSet $VMSS -VMScaleSetName $VMSSName


az network nsg rule delete -g fx38w-eastus-unreal-rg --nsg-name fx38w-ue4-nsg -n Open7070
az network nsg rule delete -g fx38w-eastus-unreal-rg --nsg-name fx38w-ue4-nsg -n Open888x

az network nsg rule delete -g fx38w-westus-unreal-rg --nsg-name fx38w-ue4-nsg -n Open7070
az network nsg rule delete -g fx38w-westus-unreal-rg --nsg-name fx38w-ue4-nsg -n Open888x

az network nsg rule delete -g fx38w-westeurope-unreal-rg --nsg-name fx38w-ue4-nsg -n Open7070
az network nsg rule delete -g fx38w-westeurope-unreal-rg --nsg-name fx38w-ue4-nsg -n Open888x

az network nsg rule delete -g fx38w-southeastasia-unreal-rg --nsg-name fx38w-ue4-nsg -n Open7070
az network nsg rule delete -g fx38w-southeastasia-unreal-rg --nsg-name fx38w-ue4-nsg -n Open888x