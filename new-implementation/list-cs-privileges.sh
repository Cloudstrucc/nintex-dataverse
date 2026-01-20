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
echo "✅ Authenticated"
echo ""

echo "Fetching ALL privileges matching cs_..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name&\$filter=contains(name,'cs_')" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

count=$(echo "$all_privs" | jq '.value | length')
echo "Found $count privileges with 'cs_' in the name"
echo ""
echo "Privileges:"
echo "$all_privs" | jq -r '.value[] | .name' | sort