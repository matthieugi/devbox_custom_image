#!/bin/bash

# Set subscription ID
subscription2="dada2713-e440-4d78-89fd-b77025678f5c"
subscription1="68be309e-79c1-483f-886f-0351d776e20c"

# Prerequisites
az login


# Add vNet and subnet
az account set --subscription $subscription2
az group create --location centralindia --resource-group rg-network-devbox-demo
az network vnet create --name MyVNet1 --resource-group rg-network-devbox-demo --address-prefix 10.0.0.0/16 --subnet-name default --subnet-prefix 10.0.0.0/24
az network vnet subnet create --resource-group rg-network-devbox-demo --vnet-name MyVNet1 --name vnet-for-databases --address-prefix 10.0.2.0/24
az network vnet subnet create --resource-group rg-network-devbox-demo --vnet-name MyVNet1 --name vnet-for-devboxes --address-prefix 10.0.4.0/24

# Add DevBox Network connection (subscription2)
devbox_subnet_id=$(az network vnet subnet show --name vnet-for-devboxes --resource-group rg-network-devbox-demo --vnet-name "MyVNet1" -o tsv --query id)
echo $devbox_subnet_id
az devcenter admin network-connection create --location centralindia --domain-join-type "AzureADJoin" --networking-resource-group-name "DevBoxNetworkInterfacesRG" --subnet-id ${devbox_subnet_id} --name "DevboxDefaultNetworkConnection" --resource-group rg-network-devbox-demo
nc_id=$(az devcenter admin network-connection show --name DevboxDefaultNetworkConnection -g rg-network-devbox-demo -o tsv --query id)
echo $nc_id


# Define the role
# https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli
tenantId=$(az account  show -o tsv --query "{tenantId:tenantId}")
appPassword=$(az ad sp create-for-rbac --name myServicePrincipalForDevBox -o tsv --query "{password:password}")
#az ad sp list  --filter "displayname eq 'myServicePrincipalForDevBox' and servicePrincipalType eq 'Application'"
#az ad sp list --filter "displayname eq 'myServicePrincipalForDevBox'" --query "[].{displayName:displayName, id:id, appId:appId}" --output json
appId=$(az ad sp list --display-name myServicePrincipalForDevBox --query "[].appId" -o tsv)
# servicePrincipalId="value de appID"
#Assign `Contributor` Role to DevCenter Network Connection Id
az role assignment create --assignee ${appId} --role "Contributor" --scope $nc_id
# Using the subscription1 login
az login --subscription $subscription1
#check if the role was can be restricted to /attachednetworks/AttachedDevboxDefaultNetworkConnection ?
az role assignment create --assignee ${appId} --role "Contributor" --scope /subscriptions/${subscription1}/resourceGroups/rg-devbox-demo/providers/Microsoft.DevCenter/devcenters/ContosoDevCenter


az login --service-principal -u ${appID} -p ${appPassword} -t ${tenantId}

# Databases (subscription2)
az group create --location centralindia --resource-group rg-db-devbox-demo
db_subnet_id=$(az network vnet subnet show --name vnet-for-databases --resource-group rg-network-devbox-demo --vnet-name "MyVNet1" -o tsv --query id)
echo $db_subnet_id
az postgres flexible-server create --resource-group rg-db-devbox-demo --name myDevBoxPostgresServer --location centralindia --admin-user devboxadminpg --admin-password 1974@microsoft --sku-name standard_d2s_v3 --tier generalpurpose --subnet ${db_subnet_id}
