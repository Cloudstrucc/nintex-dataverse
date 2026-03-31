#!/bin/bash

# Script to assign security role to application user
CONFIG_FILE="$1"
APP_USER_EMAIL="$2"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json [app-user-name]"
    echo ""
    echo "If app-user-name is not provided, will use 'appUserName' from config.json"
    echo ""
    echo "Example:"
    echo "  $0 config.json"
    echo "  $0 config.json 'Cloudstrucc API'"
    echo "  $0 config.json myapp@yourdomain.onmicrosoft.com"
    echo ""
    echo "To find your app user:"
    echo "  1. Power Platform Admin Center → Environments"
    echo "  2. Your environment → Settings → Users + permissions → Application users"
    echo "  3. Look for the 'Application User' name"
    exit 1
fi

JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')
ROLE_NAME=$(echo "$JSON_CONFIG" | jq -r '.roleName // "Nintex Digital Signature API User"')

# Get app user name from config if not provided as parameter
if [[ -z "$APP_USER_EMAIL" ]]; then
    APP_USER_EMAIL=$(echo "$JSON_CONFIG" | jq -r '.appUserName // empty')
    
    if [[ -z "$APP_USER_EMAIL" ]]; then
        echo "❌ Error: No app user specified"
        echo ""
        echo "Either:"
        echo "  1. Add 'appUserName' to config.json, OR"
        echo "  2. Provide app user name as parameter"
        echo ""
        echo "Example config.json:"
        echo '{'
        echo '  "appUserName": "Cloudstrucc API",'
        echo '  ...'
        echo '}'
        echo ""
        echo "Or run with parameter:"
        echo "  $0 config.json 'Cloudstrucc API'"
        exit 1
    fi
    
    echo "Using appUserName from config: $APP_USER_EMAIL"
fi

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

# Step 1: Find the app user by email/name
echo ""
echo "Searching for application user: $APP_USER_EMAIL"

# Try multiple search approaches
users_result=$(curl -s "${API_URL}/systemusers?\$select=systemuserid,fullname,internalemailaddress,applicationid,domainname&\$filter=applicationid ne null" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

# Try exact match first
USER_ID=$(echo "$users_result" | jq -r --arg name "$APP_USER_EMAIL" '.value[] | select(.fullname == $name) | .systemuserid' | head -n 1)
USER_NAME=$(echo "$users_result" | jq -r --arg name "$APP_USER_EMAIL" '.value[] | select(.fullname == $name) | .fullname' | head -n 1)

# If no exact match, try case-insensitive contains
if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    echo "No exact match, trying partial match..."
    USER_ID=$(echo "$users_result" | jq -r --arg name "$(echo $APP_USER_EMAIL | tr '[:upper:]' '[:lower:]')" '.value[] | select((.fullname | ascii_downcase) | contains($name)) | .systemuserid' | head -n 1)
    USER_NAME=$(echo "$users_result" | jq -r --arg name "$(echo $APP_USER_EMAIL | tr '[:upper:]' '[:lower:]')" '.value[] | select((.fullname | ascii_downcase) | contains($name)) | .fullname' | head -n 1)
fi

# If still not found, try email match
if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    echo "Trying email/domain match..."
    USER_ID=$(echo "$users_result" | jq -r --arg name "$APP_USER_EMAIL" '.value[] | select(.internalemailaddress == $name or .domainname == $name) | .systemuserid' | head -n 1)
    USER_NAME=$(echo "$users_result" | jq -r --arg name "$APP_USER_EMAIL" '.value[] | select(.internalemailaddress == $name or .domainname == $name) | .fullname' | head -n 1)
fi

if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    echo "❌ Could not find app user: '$APP_USER_EMAIL'"
    echo ""
    echo "Available application users:"
    echo "======================================"
    echo "$users_result" | jq -r '.value[] | "Name: \(.fullname)\nEmail: \(.internalemailaddress // "N/A")\nDomain: \(.domainname // "N/A")\nUser ID: \(.systemuserid)\n"'
    echo ""
    echo "💡 Tip: Copy the exact 'Name' from above and update config.json:"
    echo '   "appUserName": "Exact Name From Above"'
    exit 1
fi

echo "✅ Found user: $USER_NAME"
echo "   User ID: $USER_ID"

# Step 2: Find the security role
echo ""
echo "Finding security role: $ROLE_NAME"

roles_result=$(curl -s "${API_URL}/roles?\$select=roleid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

ROLE_ID=$(echo "$roles_result" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)

if [[ -z "$ROLE_ID" || "$ROLE_ID" == "null" ]]; then
    echo "❌ Could not find security role: $ROLE_NAME"
    exit 1
fi

echo "✅ Found role: $ROLE_NAME"
echo "   Role ID: $ROLE_ID"

# Step 3: Check if role is already assigned
echo ""
echo "Checking current role assignments..."

current_roles=$(curl -s "${API_URL}/systemusers($USER_ID)/systemuserroles_association?\$select=name,roleid" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

already_assigned=$(echo "$current_roles" | jq -r --arg roleid "$ROLE_ID" '.value[] | select(.roleid == $roleid) | .name')

if [[ -n "$already_assigned" ]]; then
    echo "✅ Role '$ROLE_NAME' is already assigned to $USER_NAME"
    exit 0
fi

echo "Role not currently assigned. Assigning now..."

# Step 4: Assign the role
assignment_result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/systemusers($USER_ID)/systemuserroles_association/\$ref" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "{\"@odata.id\": \"${API_URL}/roles($ROLE_ID)\"}")

http_code=$(echo "$assignment_result" | tail -n 1)
body=$(echo "$assignment_result" | sed '$d')

echo ""
if [[ "$http_code" == "204" ]] || [[ "$http_code" == "200" ]]; then
    echo "✅ SUCCESS! Role assigned successfully!"
    echo ""
    echo "User: $USER_NAME"
    echo "Role: $ROLE_NAME"
    echo ""
    echo "You can now:"
    echo "1. Remove the System Administrator role if it's still assigned"
    echo "2. Test API access with the new minimal-privilege role"
else
    echo "❌ Failed to assign role - HTTP $http_code"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
fi
