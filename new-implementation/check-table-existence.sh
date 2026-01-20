#!/bin/bash

CONFIG_FILE="$1"
PUBLISHER_PREFIX="${2:-cs}"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json [publisher_prefix]"
    exit 1
fi

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

echo "Getting token..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')
echo "✅ Authenticated"
echo ""

# Expected tables from schema
EXPECTED_TABLES=(
    "envelope"
    "document"
    "signer"
    "field"
    "template"
    "senderinput"
    "emailnotification"
    "authtoken"
    "webhook"
    "apirequest"
    "envelopehistory"
    "accesslink"
    "useraccount"
)

echo "Checking table existence..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

EXISTING=()
MISSING=()

for table in "${EXPECTED_TABLES[@]}"; do
    table_name="${PUBLISHER_PREFIX}_${table}"
    
    result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/EntityDefinitions(LogicalName='$table_name')?\$select=LogicalName" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    http_code=$(echo "$result" | tail -n 1)
    
    if [[ "$http_code" == "200" ]]; then
        echo -e "${GREEN}✅ EXISTS:${NC} $table_name"
        EXISTING+=("$table")
    else
        echo -e "${RED}❌ MISSING:${NC} $table_name"
        MISSING+=("$table")
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  • Existing: ${#EXISTING[@]}"
echo "  • Missing: ${#MISSING[@]}"
echo ""

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Missing tables:${NC}"
    for table in "${MISSING[@]}"; do
        echo "  • ${PUBLISHER_PREFIX}_${table}"
    done
    echo ""
    echo "To create missing tables, run:"
    echo "  ./deploy-nintex-all.sh config.json tables-only"
fi