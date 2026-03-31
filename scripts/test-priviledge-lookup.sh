#!/bin/bash

CONFIG_FILE="$1"

JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

echo "Authenticating..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')

echo "Getting privileges..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo ""
echo "Testing privilege lookup:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

PRIV_NAME="prvCreatecs_Envelope"
echo "Looking for: $PRIV_NAME"

priv_id=$(echo "$all_privs" | jq -r --arg name "$PRIV_NAME" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)

if [[ -n "$priv_id" && "$priv_id" != "null" ]]; then
    echo "✅ FOUND: $priv_id"
else
    echo "❌ NOT FOUND"
    echo ""
    echo "Checking if privilege exists in list:"
    exists=$(echo "$all_privs" | jq -r --arg name "$PRIV_NAME" '.value[] | select(.name == $name) | .name')
    if [[ -n "$exists" ]]; then
        echo "Name exists: $exists"
    else
        echo "Name does not exist"
    fi
    
    echo ""
    echo "All privileges starting with prvCreate and containing cs_:"
    echo "$all_privs" | jq -r '.value[] | select(.name | startswith("prvCreatecs_")) | .name' | head -20
fi