#!/bin/bash

# Prerequisites
az login
az extension add --name devcenter

# DevCenter
az group create --location centralindia --resource-group rg-devbox-demo
az devcenter admin devcenter create --location "centralindia" --tags CostCode="12345" --name "ContosoDevCenter" --resource-group "rg-devbox-demo"

# Add DevBox Definition
az devcenter admin devbox-definition list -g rg-devbox-demo --dev-center ContosoDevCenter -o table
az devcenter admin image list -g rg-devbox-demo --dev-center ContosoDevCenter --output table --query "[].{resource:resourceGroup, name:name, description:description}"
image_id=$(az devcenter admin image show --name microsoftvisualstudio_visualstudio2019plustools_vs-2019-ent-general-win11-m365-gen2 -g rg-devbox-demo --dev-center ContosoDevCenter --gallery-name Default --output tsv --query "id")
echo $image_id
az devcenter admin devbox-definition create --location "centralindia" --image-reference id="${image_id}" --os-storage-type "ssd_512gb" --sku name="general_i_8c32gb512ssd_v2" --name "WebDevBox" -g rg-devbox-demo --dev-center ContosoDevCenter
az devcenter admin devbox-definition list -g rg-devbox-demo --dev-center ContosoDevCenter -o table

# Add Environment Types
az devcenter admin environment-type list -g rg-devbox-demo --dev-center ContosoDevCenter
az devcenter admin environment-type create -g rg-devbox-demo --dev-center ContosoDevCenter --name "DevTest"
az devcenter admin environment-type create -g rg-devbox-demo --dev-center ContosoDevCenter --name "QAandUAT"
az devcenter admin environment-type list -g rg-devbox-demo --dev-center ContosoDevCenter --output table

# Add Network connection
#az group create --location centralindia --resource-group rg-network-devbox-demo
#az network vnet create --name MyVNet1 --resource-group rg-network-devbox-demo --address-prefix 10.0.0.0/16 --subnet-name default --subnet-prefix 10.0.0.0/24
#az network vnet subnet create --resource-group rg-network-devbox-demo --vnet-name MyVNet1 --name vnet-for-databases --address-prefix 10.0.2.0/24
#az network vnet subnet create --resource-group rg-network-devbox-demo --vnet-name MyVNet1 --name vnet-for-devboxes --address-prefix 10.0.4.0/24

exit 100

devbox_subnet_id=$(az network vnet subnet show --name vnet-for-devboxes --resource-group rg-network-devbox-demo --vnet-name "MyVNet1" -o tsv --query id)
echo $devbox_subnet_id
az devcenter admin network-connection create --location centralindia --domain-join-type "AzureADJoin" --networking-resource-group-name "DevBoxNetworkInterfacesRG" --subnet-id ${devbox_subnet_id} --name "DevboxDefaultNetworkConnection" --resource-group rg-network-devbox-demo
nc_id=$(az devcenter admin network-connection show --name DevboxDefaultNetworkConnection -g rg-network-devbox-demo -o tsv --query id)
echo $nc_id
az devcenter admin attached-network create --attached-network-connection-name AttachedDevboxDefaultNetworkConnection -g rg-devbox-demo --dev-center ContosoDevCenter --network-connection-id ${nc_id}

# Project
devcenter_id=$(az devcenter admin devcenter show --name ContosoDevCenter -o tsv --query '[id]' --resource-group rg-devbox-demo)
az devcenter admin project list
az devcenter admin project create --location "centralindia" --description "This is my first project." --dev-center-id "${devcenter_id}" --tags CostCenter="DevTeam1" --name "Project1" --resource-group "rg-devbox-demo" --max-dev-boxes-per-user "2"
az devcenter admin project list -o table --query "[].{resource:resourceGroup, name:name, location:location}"

# Assign Environment Type to the Project
az devcenter admin project-environment-type list --project-name "Project1" --resource-group "rg-devbox-demo"
subscription_id=$(az account show -o tsv --query '[id]')
echo $subscription_id
az devcenter admin project-environment-type create --environment-type-name "DevTest" --project-name "Project1" --resource-group "rg-devbox-demo" --deployment-target-id "/subscriptions/${subscription_id}" --status "Enabled" --identity-typ SystemAssigned --roles "{\"4cbf0b6c-e750-441c-98a7-10da8387e4d6\":{}}"

# Manage Devbox pools
az devcenter admin pool list --project-name "Project1" --resource-group "rg-devbox-demo"
az devcenter admin pool create --pool-name "DevPoolManaged" --devbox-definition-name "WebDevBox" --project-name "Project1" --resource-group "rg-devbox-demo" --location "centralindia" --local-administrator "Enabled" --virtual-network-type "Managed" --single-sign-on-status "Enabled" --managed-virtual-network-regions centralindia
az devcenter admin pool create --pool-name "DevBoxPoolDatabases" --devbox-definition-name "WebDevBox" --project-name "Project1" --resource-group "rg-devbox-demo" --location "centralindia" --local-administrator "Enabled" --virtual-network-type "Unmanaged" --single-sign-on-status "Enabled" --network-connection-name AttachedDevboxDefaultNetworkConnection
az devcenter admin pool list --project-name "Project1" --resource-group "rg-devbox-demo" -o table
az login --subscription $subscription1
# Manage Users
project_id=$(az devcenter admin project show --name Project1 -g rg-devbox-demo -o tsv --query id)
user_id=$(az ad user show --id "bob@LEBO.onmicrosoft.com" --query "id" --output tsv)
az role assignment create --assignee ${user_id} --role "DevCenter Dev Box User" --scope ${project_id}
