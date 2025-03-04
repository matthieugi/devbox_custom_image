

# Prerequisites
az login

# Define the role
# https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-cli
tenantId=$(az account  show -o tsv --query "{tenantId:tenantId}")
appPassword=$(az ad sp create-for-rbac --name myServicePrincipalForDevBox -o tsv --query "{password:password}")
#az ad sp list  --filter "displayname eq 'myServicePrincipalForDevBox' and servicePrincipalType eq 'Application'"
#az ad sp list --filter "displayname eq 'myServicePrincipalForDevBox'" --query "[].{displayName:displayName, id:id, appId:appId}" --output json
appId=$(az ad sp list --display-name myServicePrincipalForDevBox --query "[].appId" -o tsv)

cat <<EOF > .env
appId=$appId"
echo "appPassword=$appPassword"
echo "tenantId=$tenantId"
EOF
echo ".env file created"

az login --service-principal -u ${appID} -p ${appPassword} -t ${tenantId}
