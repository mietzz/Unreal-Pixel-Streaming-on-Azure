# Infrastructure Deployment
## Pre-Reqs
1. Install Terraform
    Downloads are at: https://www.terraform.io/downloads.html
2. Open a command prompt
3. Navigate to the root of where you want the repo (for example, c:\repos)
4. On the command line type: git clone https://github.com/Azure/Unreal-Pixel-Streaming-on-Azure.git
5. Navigate to the new folder
6. Login to Azure by typing: az login
7. Set your subscription to deploy to: az account set --subscription {put in your subscription here}
8. Change directory to the iac folder on your hard drive for this project in your repo folder. 
9. Optionally adjust the values in the variables.tf file and save the file
10. Run the following Terraform commands
    terraform init 
    terraform plan
    terraform apply
        (note the base name variable, and the random password for VMs)
11. Go to your subscription and look for your new resource group and assets. To assure two deployments do not crash into each other, there is a 5 character random string at the front of the assets for your deployment. 

## Notes about Terraform
The init function initializes state on your machine. The plan function will show you what we be created or destroyed based on any changes to the terraform code. The apply function will do the actual deployment. 

If you are doing hardcore terraform development, you may want to use the terraform validate function as well before running plan or apply. 

## Clean Up
To remove the code deployed in your Terraform state, type:
    terraform destroy

