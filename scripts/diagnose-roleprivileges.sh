#!/bin/bash

CONFIG_FILE="$1"

JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')
ROLE_NAME=$(echo "$JSON_CONFIG" | jq -r '.roleName // "Nintex API User"')

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

echo "Authenticating..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')

echo "Getting role..."
roles_result=$(curl -s "${API_URL}/roles?\$select=roleid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

ROLE_ID=$(echo "$roles_result" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)

echo "Role ID: $ROLE_ID"
echo "Role Name: $ROLE_NAME"
echo ""
echo "Fetching role privileges..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

current_privs_result=$(curl -s -w "\n%{http_code}" "${API_URL}/roles($ROLE_ID)/roleprivileges?\$select=privilegeid" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

http_code=$(echo "$current_privs_result" | tail -n 1)
current_privs=$(echo "$current_privs_result" | sed '$d')

echo "HTTP Code: $http_code"
echo ""
echo "Response:"
echo "$current_privs" | jq '.' 2>&1 || echo "$current_privs"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$http_code" == "200" ]]; then
    count=$(echo "$current_privs" | jq '.value | length')
    echo "✅ Successfully retrieved $count privileges"
else
    echo "❌ Failed to retrieve privileges - HTTP $http_code"
fi