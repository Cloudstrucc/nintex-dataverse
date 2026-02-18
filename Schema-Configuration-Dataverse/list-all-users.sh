#!/bin/bash

# Script to list ALL users and help identify the app user
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
echo "✅ Token acquired"
echo ""

# Try different queries to find users
echo "========================================"
echo "Method 1: Application users (applicationid not null)"
echo "========================================"
users1=$(curl -s "${API_URL}/systemusers?\$select=systemuserid,fullname,internalemailaddress,applicationid,domainname&\$filter=applicationid ne null&\$top=50" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

count1=$(echo "$users1" | jq '.value | length')
echo "Found: $count1 users"

if [[ "$count1" -gt 0 ]]; then
    echo "$users1" | jq -r '.value[] | "  • \(.fullname) (\(.internalemailaddress // .domainname // "N/A"))"'
fi

echo ""
echo "========================================"
echo "Method 2: All non-interactive users"
echo "========================================"
users2=$(curl -s "${API_URL}/systemusers?\$select=systemuserid,fullname,internalemailaddress,domainname,isdisabled&\$filter=accessmode eq 3&\$top=50" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

count2=$(echo "$users2" | jq '.value | length')
echo "Found: $count2 users"

if [[ "$count2" -gt 0 ]]; then
    echo "$users2" | jq -r '.value[] | "  • \(.fullname) (\(.internalemailaddress // .domainname // "N/A"))"'
fi

echo ""
echo "========================================"
echo "Method 3: Search for 'dataverse' or 'api' in names"
echo "========================================"
users3=$(curl -s "${API_URL}/systemusers?\$select=systemuserid,fullname,internalemailaddress,domainname,applicationid&\$top=100" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo "$users3" | jq -r '.value[] | select(.fullname | ascii_downcase | test("dataverse|api|webapi|browser")) | "  • \(.fullname) (\(.internalemailaddress // .domainname // "N/A")) [ID: \(.systemuserid)]"'

echo ""
echo "========================================"
echo "Method 4: Recent users (last 20)"
echo "========================================"
users4=$(curl -s "${API_URL}/systemusers?\$select=systemuserid,fullname,internalemailaddress,domainname&\$orderby=createdon desc&\$top=20" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo "$users4" | jq -r '.value[] | "  • \(.fullname) (\(.internalemailaddress // .domainname // "N/A"))"'

echo ""
echo "========================================"
echo "💡 Instructions:"
echo "========================================"
echo "1. Find your app user in one of the lists above"
echo "2. Copy the EXACT name (case-sensitive)"
echo "3. Update config.json:"
echo '   "appUserName": "Exact Name Here"'
echo ""
echo "If you don't see your app user, you may need to create it:"
echo "  Power Platform Admin Center → Environments → Your Env"
echo "  Settings → Users + permissions → Application users → + New app user"