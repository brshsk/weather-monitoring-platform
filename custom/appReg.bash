# Create the App Registration
APP_ID=$(az ad app create \
  --display-name "Weather-Monitoring-GitHub-Actions" \
  --query appId \
  --output tsv)

echo "App Registration ID: $APP_ID"

# Get the Object ID (needed for federated credentials)
OBJECT_ID=$(az ad app show --id $APP_ID --query id --output tsv)
echo "Object ID: $OBJECT_ID"

# Create a service principal for the app
az ad sp create --id $APP_ID

# Get your subscription and tenant IDs
SUBSCRIPTION_ID=$(az account show --query id --output tsv)
TENANT_ID=$(az account show --query tenantId --output tsv)

echo "Subscription ID: $SUBSCRIPTION_ID"
echo "Tenant ID: $TENANT_ID"

# Assign Contributor role to the service principal
az role assignment create \
  --assignee $APP_ID \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID"


  # Create federated credential for main branch
az ad app federated-credential create \
  --id $OBJECT_ID \
  --parameters '{
    "name": "GitHubActions-Main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:brshsk/weather-monitoring-platform:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for develop branch
az ad app federated-credential create \
  --id $OBJECT_ID \
  --parameters '{
    "name": "GitHubActions-Develop", 
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:brshsk/weather-monitoring-platform:ref:refs/heads/develop",
    "audiences": ["api://AzureADTokenExchange"]
  }'

# Create federated credential for pull requests
az ad app federated-credential create \
  --id $OBJECT_ID \
  --parameters '{
    "name": "GitHubActions-PR",
    "issuer": "https://token.actions.githubusercontent.com", 
    "subject": "repo:brshsk/weather-monitoring-platform:pull_request",
    "audiences": ["api://AzureADTokenExchange"]
  }'