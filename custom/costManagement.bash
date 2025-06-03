# Get your subscription ID
SUBSCRIPTION_ID=$(az account show --query id --output tsv)

# Create a budget (adjust amount as needed)
az consumption budget create \
  --budget-name "WeatherAppBudget" \
  --amount 100 \
  --category cost \
  --time-grain "Monthly" \
  --start-date "2025-06-01" \
  --end-date "2025-12-31" \
  --resource-group "rg-weather-management"