#!/bin/bash
# CeruleanPay Azure Infrastructure Setup
# Run this AFTER authenticating with: az login
# Prerequisites: azure-cli v2, jq

set -euo pipefail

RESOURCE_GROUP="ceruleanpay-rg"
LOCATION="southindia"
ACR_NAME="ceruleanpaycr"
APP_SERVICE_PLAN="ceruleanpay-plan"
APP_SERVICE_NAME="ceruleanpay-api"
KEY_VAULT_NAME="ceruleanpay-kv"
APP_REG_NAME="ceruleanpay-cicd"
GH_ORG="ceruleanpay"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}[OK]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()  { echo -e "${RED}[ERR]${NC} $*"; exit 1; }

echo "=== CeruleanPay Azure Setup ==="
az account show --query "{name:name, id:id}" -o table || err "Not logged in. Run: az login"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Subscription: $SUBSCRIPTION_ID"
echo "Tenant: $TENANT_ID"
echo ""

echo "[1/8] Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" -o none
ok "Resource group: $RESOURCE_GROUP ($LOCATION)"

echo "[2/8] Creating Azure Container Registry..."
az acr create \
  --name "$ACR_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --sku Basic \
  --admin-enabled true \
  -o none
ACR_LOGIN_SERVER=$(az acr show --name "$ACR_NAME" --query loginServer -o tsv)
ok "ACR: $ACR_LOGIN_SERVER"
warn "MISCONFIGURATION: ACR admin enabled, no immutable tag policy - latest tag is mutable"

echo "[3/8] Creating App Service..."
az appservice plan create \
  --name "$APP_SERVICE_PLAN" \
  --resource-group "$RESOURCE_GROUP" \
  --sku F1 \
  --is-linux \
  -o none
az webapp create \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --plan "$APP_SERVICE_PLAN" \
  --container-image-name "nginx:latest" \
  -o none
az webapp config appsettings set \
  --name "$APP_SERVICE_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings NODE_ENV=production PORT=3000 WEBSITES_PORT=3000 \
  -o none
ok "App Service: https://${APP_SERVICE_NAME}.azurewebsites.net"

echo "[4/8] Creating Key Vault with secrets..."
az keyvault create \
  --name "$KEY_VAULT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku standard \
  -o none

DB_PASSWORD="Cerulean@$(openssl rand -hex 8)2024"
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-password"     --value "$DB_PASSWORD"                          -o none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-host"         --value "127.0.0.1"                             -o none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "db-user"         --value "cerulean_app"                          -o none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "payment-api-key" --value "cp_live_$(openssl rand -hex 24)"       -o none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "admin-api-key"   --value "admin_$(openssl rand -hex 16)"         -o none
az keyvault secret set --vault-name "$KEY_VAULT_NAME" --name "jwt-secret"      --value "$(openssl rand -hex 32)"               -o none
ok "Key Vault: $KEY_VAULT_NAME (6 secrets stored)"
echo "DB_PASSWORD=$DB_PASSWORD" > /tmp/ceruleanpay_db_creds.txt
warn "DB password saved to /tmp/ceruleanpay_db_creds.txt"

echo "[5/8] Creating Entra ID app registration for GitHub Actions OIDC..."
APP_REG_JSON=$(az ad app create --display-name "$APP_REG_NAME" --query "{appId:appId, objectId:id}" -o json)
APP_CLIENT_ID=$(echo "$APP_REG_JSON" | jq -r .appId)
APP_OBJECT_ID=$(echo "$APP_REG_JSON" | jq -r .objectId)
az ad sp create --id "$APP_CLIENT_ID" -o none
SP_OBJECT_ID=$(az ad sp show --id "$APP_CLIENT_ID" --query id -o tsv)
ok "App registration: $APP_REG_NAME (client ID: $APP_CLIENT_ID)"

echo "[6/8] Configuring OIDC federation (intentional misconfiguration)..."
# MISCONFIGURATION: sub claim is repo:ceruleanpay/* instead of
# repo:ceruleanpay/payment-api:ref:refs/heads/main
az ad app federated-credential create \
  --id "$APP_OBJECT_ID" \
  --parameters "{
    \"name\": \"github-actions-ceruleanpay\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:${GH_ORG}/*\",
    \"description\": \"GitHub Actions OIDC for ceruleanpay org\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" -o none
warn "MISCONFIGURATION: OIDC sub is repo:${GH_ORG}/* - any repo in org can assume production role"
ok "Federated credential created"

echo "[7/8] Assigning Azure roles to service principal..."
ACR_ID=$(az acr show --name "$ACR_NAME" --query id -o tsv)
az role assignment create --assignee "$SP_OBJECT_ID" --role "AcrPush" --scope "$ACR_ID" -o none
# MISCONFIGURATION: Contributor is too broad
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role "Contributor" \
  --scope "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP" \
  -o none
az role assignment create \
  --assignee "$SP_OBJECT_ID" \
  --role "Key Vault Secrets User" \
  --scope "$(az keyvault show --name "$KEY_VAULT_NAME" --query id -o tsv)" \
  -o none
ok "Roles assigned to service principal"
warn "MISCONFIGURATION: SP has Contributor on resource group - should use least-privilege custom role"

echo "[8/8] Saving credentials for GitHub secrets setup..."
cat > /tmp/ceruleanpay_github_secrets.txt << EOF
AZURE_CLIENT_ID=$APP_CLIENT_ID
AZURE_TENANT_ID=$TENANT_ID
AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID
ACR_NAME=$ACR_NAME
KEY_VAULT_NAME=$KEY_VAULT_NAME
DB_HOST=127.0.0.1
DB_PORT=5432
DB_NAME=ceruleanpay
DB_USER=cerulean_app
DB_PASSWORD=$DB_PASSWORD
EOF
ok "Credentials saved to /tmp/ceruleanpay_github_secrets.txt"

echo ""
echo "=== Azure Setup Complete ==="
echo "Resource group:  $RESOURCE_GROUP"
echo "ACR:             $ACR_LOGIN_SERVER"
echo "App Service:     https://${APP_SERVICE_NAME}.azurewebsites.net"
echo "Key Vault:       $KEY_VAULT_NAME"
echo "App Client ID:   $APP_CLIENT_ID"
echo "NEXT: Add secrets from /tmp/ceruleanpay_github_secrets.txt to GitHub org"
