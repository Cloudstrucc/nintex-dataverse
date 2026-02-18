#!/bin/bash

# Debug script to see what privileges exist for entities
CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json"
    exit 1
fi

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

echo "Checking for cs_digitalsignature privileges..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo ""
echo "Privileges containing 'cs_digitalsignature':"
echo "$all_privs" | jq -r '.value[] | select(.name | contains("cs_digitalsignature")) | .name'

echo ""
echo "Privileges containing 'account' (first 10):"
echo "$all_privs" | jq -r '.value[] | select(.name | contains("account")) | .name' | head -10

echo ""
echo "Privileges containing 'Read' (first 10):"
echo "$all_privs" | jq -r '.value[] | select(.name | contains("Read")) | .name' | head -10

echo ""
echo "Check if table exists..."
table_check=$(curl -s "${API_URL}/EntityDefinitions(LogicalName='cs_digitalsignature')?\$select=LogicalName,DisplayName" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo "$table_check" | jq '.'