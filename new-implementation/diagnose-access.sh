#!/bin/bash

# Script to diagnose API access and permissions
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

echo "========================================"
echo "WHO AM I?"
echo "========================================"
whoami=$(curl -s "${API_URL}/WhoAmI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

echo "Response:"
echo "$whoami" | jq '.'

USER_ID=$(echo "$whoami" | jq -r '.UserId')
BU_ID=$(echo "$whoami" | jq -r '.BusinessUnitId')

if [[ -n "$USER_ID" && "$USER_ID" != "null" ]]; then
    echo ""
    echo "✅ Authenticated as User ID: $USER_ID"
    echo "✅ Business Unit: $BU_ID"
    
    echo ""
    echo "========================================"
    echo "MY USER DETAILS"
    echo "========================================"
    my_user=$(curl -s "${API_URL}/systemusers($USER_ID)?\$select=fullname,domainname,internalemailaddress,systemuserid" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    echo "$my_user" | jq '.'
    
    MY_NAME=$(echo "$my_user" | jq -r '.fullname')
    echo ""
    echo "✅ Authenticated as: $MY_NAME"
    
    echo ""
    echo "========================================"
    echo "MY SECURITY ROLES"
    echo "========================================"
    my_roles=$(curl -s "${API_URL}/systemusers($USER_ID)/systemuserroles_association?\$select=name,roleid" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    echo "$my_roles" | jq -r '.value[] | "  • \(.name)"'
    
    role_count=$(echo "$my_roles" | jq '.value | length')
    
    if [[ "$role_count" -eq 0 ]]; then
        echo ""
        echo "⚠️  WARNING: This app user has NO security roles assigned!"
        echo "   This is why you can't see other users."
        echo ""
        echo "   You need to assign a role with permissions to:"
        echo "   1. Read User records (prvReadSystemUser)"
        echo "   2. Or assign System Administrator temporarily"
    fi
    
    echo ""
    echo "========================================"
    echo "WHAT I CAN ACCESS"
    echo "========================================"
    
    # Test various entities
    entities=("account" "contact" "systemuser" "role" "privilege")
    
    for entity in "${entities[@]}"; do
        test_result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/${entity}s?\$top=1" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/json")
        
        http_code=$(echo "$test_result" | tail -n 1)
        
        if [[ "$http_code" == "200" ]]; then
            echo "  ✅ Can read $entity"
        else
            echo "  ❌ Cannot read $entity (HTTP $http_code)"
        fi
    done
    
else
    echo "❌ Could not determine user identity"
    echo ""
    echo "This might indicate:"
    echo "  1. App registration is not properly set up"
    echo "  2. App user doesn't exist in this environment"
    echo "  3. Authentication issue"
fi

echo ""
echo "========================================"
echo "NEXT STEPS"
echo "========================================"
echo "If you see 'no security roles' above:"
echo "  1. Go to Power Platform Admin Center"
echo "  2. Your environment → Settings → Users + permissions"
echo "  3. Application users → Find your app"
echo "  4. Manage roles → Assign 'System Administrator' (temporarily)"
echo "  5. Then run this script again"
echo ""
echo "Then you can:"
echo "  1. Use ./assign-role-to-user.sh to assign the custom role"
echo "  2. Remove System Administrator"
