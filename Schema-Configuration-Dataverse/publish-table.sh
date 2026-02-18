#!/bin/bash

# Publish customizations for cs_digitalsignature table
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

echo "Publishing all customizations..."

result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/PublishAllXml" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "OData-MaxVersion: 4.0" \
    -H "Accept: application/json" \
    -d '{}')

http_code=$(echo "$result" | tail -n 1)
body=$(echo "$result" | sed '$d')

echo "HTTP Status: $http_code"

if [[ "$http_code" == "200" ]] || [[ "$http_code" == "204" ]]; then
    echo "✅ Customizations published successfully!"
    echo ""
    echo "Wait 30 seconds for privilege generation..."
    sleep 30
    
    echo ""
    echo "Checking for privileges now..."
    all_privs=$(curl -s "${API_URL}/privileges?\$select=name" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    echo "Privileges for cs_digitalsignature:"
    echo "$all_privs" | jq -r '.value[] | select(.name | contains("cs_digitalsignature")) | .name'
    
    priv_count=$(echo "$all_privs" | jq -r '.value[] | select(.name | contains("cs_digitalsignature")) | .name' | wc -l)
    
    if [[ "$priv_count" -gt 0 ]]; then
        echo ""
        echo "✅ SUCCESS! Found $priv_count privileges for cs_digitalsignature"
        echo ""
        echo "Now you can run:"
        echo "./deploy-nintex-activity.sh config.json security"
    else
        echo ""
        echo "⚠️  No privileges found yet. This might mean:"
        echo "1. The table needs more time to process (wait another minute)"
        echo "2. The table was created in a solution that needs to be published"
        echo "3. Try publishing again from the UI:"
        echo "   Power Apps → Solutions → Default Solution → Publish All Customizations"
    fi
else
    echo "❌ Failed to publish - HTTP $http_code"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
fi