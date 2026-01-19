#!/bin/bash

# Debug script for Nintex Digital Signature Activity deployment
# This will show detailed error messages

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
    print_error "Config file required!"
    echo "Usage: $0 config.json"
    exit 1
fi

# Read config
JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')
PUBLISHER_PREFIX=$(echo "$JSON_CONFIG" | jq -r '.publisherPrefix // "cs"')

AUTHORITY="https://login.microsoftonline.com/$TENANT_ID"
RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
TOKEN_ENDPOINT="$AUTHORITY/oauth2/v2.0/token"
API_URL="${RESOURCE}/api/data/v9.2"

print_info "Getting OAuth token..."
response=$(curl -s -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    print_error "Failed to get access token!"
    echo "$response" | jq '.'
    exit 1
fi

print_success "Token acquired!"

# Test 1: Check if entity already exists
print_info "Checking if entity already exists..."
existing_entity=$(curl -s "${API_URL}/EntityDefinitions(LogicalName='${PUBLISHER_PREFIX}_digitalsignatureactivity')" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "OData-Version: 4.0" \
    -H "Accept: application/json")

if echo "$existing_entity" | jq -e '.error' > /dev/null 2>&1; then
    error_code=$(echo "$existing_entity" | jq -r '.error.code')
    if [[ "$error_code" != "0x80060891" ]] && [[ "$error_code" != "ResourceNotFound" ]]; then
        print_error "Unexpected error checking for existing entity:"
        echo "$existing_entity" | jq '.'
    else
        print_info "Entity does not exist (good - we can create it)"
    fi
else
    print_error "Entity already exists!"
    echo "$existing_entity" | jq '{LogicalName, DisplayName, IsActivity}'
    echo ""
    print_info "To delete and recreate:"
    echo "1. Go to https://make.powerapps.com"
    echo "2. Tables → Find 'Digital Signature Activity'"
    echo "3. Delete the table"
    echo "4. Re-run this script"
    exit 1
fi

# Test 2: Try to create the entity with detailed error output
print_info "Attempting to create activity entity..."

entity_payload=$(cat <<'EOF'
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "IsActivity": true,
  "LogicalName": "PUBLISHER_PREFIX_digitalsignatureactivity",
  "SchemaName": "PUBLISHER_PREFIX_DigitalSignatureActivity",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Digital Signature Activity",
        "LanguageCode": 1033
      }
    ]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Digital Signature Activities",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Activity for managing digital signature requests via Nintex AssureSign API",
        "LanguageCode": 1033
      }
    ]
  },
  "OwnershipType": "UserOwned",
  "IsCustomizable": {
    "Value": true
  },
  "HasActivities": false,
  "HasNotes": true,
  "CanCreateAttributes": {
    "Value": true
  }
}
EOF
)

# Replace placeholder
entity_payload="${entity_payload//PUBLISHER_PREFIX/$PUBLISHER_PREFIX}"

print_info "Payload:"
echo "$entity_payload" | jq '.'

print_info "Sending request to: ${API_URL}/EntityDefinitions"

response=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/EntityDefinitions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "OData-MaxVersion: 4.0" \
    -H "OData-Version: 4.0" \
    -H "Accept: application/json" \
    -d "$entity_payload")

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

print_info "HTTP Status Code: $http_code"

if [[ "$http_code" == "201" ]] || [[ "$http_code" == "204" ]]; then
    print_success "Entity created successfully!"
    echo "$body" | jq '.'
else
    print_error "Entity creation failed!"
    echo "Response body:"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    
    # Parse common errors
    if echo "$body" | jq -e '.error' > /dev/null 2>&1; then
        error_code=$(echo "$body" | jq -r '.error.code')
        error_message=$(echo "$body" | jq -r '.error.message')
        
        print_error "Error Code: $error_code"
        print_error "Error Message: $error_message"
        
        echo ""
        print_info "Common solutions:"
        
        case "$error_code" in
            "0x80040217")
                echo "• Principal user is missing Security Role assignment"
                echo "• Solution: Ensure your app user has System Administrator or System Customizer role"
                ;;
            "0x80048306")
                echo "• Publisher prefix already in use or invalid"
                echo "• Solution: Check if another solution uses prefix '$PUBLISHER_PREFIX'"
                ;;
            "0x8004F00A")
                echo "• Insufficient privileges"
                echo "• Solution: Grant System Administrator role to the application user"
                ;;
            "0x80040203")
                echo "• Principal user does not exist or is disabled"
                echo "• Solution: Check application user status in Power Platform Admin Center"
                ;;
        esac
    fi
fi

# Test 3: Check user permissions
print_info "Checking current user context..."
whoami=$(curl -s "${API_URL}/WhoAmI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "Accept: application/json")

echo "$whoami" | jq '.'

user_id=$(echo "$whoami" | jq -r '.UserId')

if [[ -n "$user_id" && "$user_id" != "null" ]]; then
    print_info "Checking user roles..."
    user_roles=$(curl -s "${API_URL}/systemusers($user_id)/systemuserroles_association?\$select=name" \
        -H "Authorization: Bearer $TOKEN" \
        -H "OData-MaxVersion: 4.0" \
        -H "Accept: application/json")
    
    echo "User roles:"
    echo "$user_roles" | jq '.value[] | .name'
    
    # Check if System Administrator
    has_sysadmin=$(echo "$user_roles" | jq -r '.value[] | select(.name == "System Administrator") | .name')
    
    if [[ -z "$has_sysadmin" ]]; then
        print_error "User does not have System Administrator role!"
        echo ""
        print_info "To grant System Administrator:"
        echo "1. Power Platform Admin Center → Environments"
        echo "2. Your environment → Settings → Users + permissions → Users"
        echo "3. Find your application user"
        echo "4. Manage Roles → Add 'System Administrator'"
    else
        print_success "User has System Administrator role"
    fi
fi