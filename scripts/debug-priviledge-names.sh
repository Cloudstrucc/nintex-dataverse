#!/bin/bash

CONFIG_FILE="$1"
TABLE_NAME="${2:-cs_useraccount}"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json [table_name]"
    echo ""
    echo "Example:"
    echo "  $0 config.json cs_useraccount"
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

echo "✅ Authenticated"
echo ""
echo "Searching for privileges for table: $TABLE_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get all privileges
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

# Try different patterns
echo "Pattern 1: prv*${TABLE_NAME}"
echo "$all_privs" | jq -r --arg table "$TABLE_NAME" '.value[] | select(.name | contains($table)) | .name'

echo ""
echo "Pattern 2: prv*cs_*"
echo "$all_privs" | jq -r '.value[] | select(.name | contains("cs_")) | .name' | head -20

echo ""
echo "Pattern 3: Looking for exact matches"
for priv_type in "Create" "Read" "Write" "Delete" "Append" "AppendTo" "Assign" "Share"; do
    # Try with underscore
    priv_with_underscore="prv${priv_type}${TABLE_NAME}"
    exists=$(echo "$all_privs" | jq -r --arg name "$priv_with_underscore" '.value[] | select(.name == $name) | .name')
    
    # Try without underscore (cs_useraccount -> csuseraccount)
    table_no_underscore=$(echo "$TABLE_NAME" | sed 's/_//')
    priv_no_underscore="prv${priv_type}${table_no_underscore}"
    exists2=$(echo "$all_privs" | jq -r --arg name "$priv_no_underscore" '.value[] | select(.name == $name) | .name')
    
    # Try with underscore preserved
    priv_preserved="prv${priv_type}cs_${TABLE_NAME#cs_}"
    exists3=$(echo "$all_privs" | jq -r --arg name "$priv_preserved" '.value[] | select(.name == $name) | .name')
    
    if [[ -n "$exists" ]]; then
        echo "✅ Found: $priv_with_underscore"
    elif [[ -n "$exists2" ]]; then
        echo "✅ Found: $priv_no_underscore"
    elif [[ -n "$exists3" ]]; then
        echo "✅ Found: $priv_preserved"
    else
        echo "❌ Not found: $priv_type (tried: $priv_with_underscore, $priv_no_underscore, $priv_preserved)"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "If no privileges found, the table may not be published yet."
echo "Run: ./publish-table.sh config.json"