#!/bin/bash

#############################################################################
# Create Security Roles for Nintex Tables
#############################################################################

CONFIG_FILE="$1"
PUBLISHER_PREFIX="$2"

if [[ -z "$CONFIG_FILE" ]] || [[ -z "$PUBLISHER_PREFIX" ]]; then
    echo "Usage: $0 config.json publisher_prefix"
    exit 1
fi

# Color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Load config
JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')
ROLE_NAME=$(echo "$JSON_CONFIG" | jq -r '.roleName // "Nintex API User"')

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

# Get token
print_info "Authenticating..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    print_error "Failed to get access token"
    exit 1
fi

print_success "Authenticated"

# Get business unit
print_info "Getting root business unit..."

bu_result=$(curl -s "${API_URL}/businessunits?\$select=businessunitid,parentbusinessunitid" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

BUSINESS_UNIT_ID=$(echo "$bu_result" | jq -r '.value[] | select(.parentbusinessunitid == null or ._parentbusinessunitid_value == null) | .businessunitid' | head -n 1)

if [[ -z "$BUSINESS_UNIT_ID" ]]; then
    print_error "Could not find root business unit"
    exit 1
fi

print_success "Business Unit: $BUSINESS_UNIT_ID"

# Check if role exists
print_info "Checking for existing role..."

roles_result=$(curl -s "${API_URL}/roles?\$select=roleid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

ROLE_ID=$(echo "$roles_result" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)

if [[ -n "$ROLE_ID" && "$ROLE_ID" != "null" ]]; then
    print_warning "Role already exists: $ROLE_ID"
else
    # Create role
    print_info "Creating role: $ROLE_NAME"
    
    role_payload=$(cat <<EOF
{
  "name": "$ROLE_NAME",
  "businessunitid@odata.bind": "/businessunits($BUSINESS_UNIT_ID)"
}
EOF
)
    
    role_result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/roles" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -H "Prefer: return=representation" \
        -d "$role_payload")
    
    http_code=$(echo "$role_result" | tail -n 1)
    body=$(echo "$role_result" | sed '$d')
    
    if [[ "$http_code" == "201" ]] || [[ "$http_code" == "200" ]]; then
        ROLE_ID=$(echo "$body" | jq -r '.roleid // empty')
        
        if [[ -z "$ROLE_ID" ]]; then
            sleep 2
            roles_result=$(curl -s "${API_URL}/roles?\$select=roleid,name" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Accept: application/json")
            ROLE_ID=$(echo "$roles_result" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)
        fi
        
        print_success "Role created: $ROLE_ID"
    else
        print_error "Failed to create role - HTTP $http_code"
        echo "$body" | jq '.'
        exit 1
    fi
fi

# Define Nintex tables
TABLES=(
    "envelope"
    "document"
    "signer"
    "field"
    "template"
    "authtoken"
    "webhook"
    "apirequest"
)

# Get all privileges
print_info "Retrieving privilege list..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

# Function to add privilege to role
add_privilege() {
    local priv_id=$1
    local depth=$2
    
    payload=$(cat <<EOF
{
  "PrivilegeId": "$priv_id",
  "Depth": "$depth"
}
EOF
)
    
    result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/roles($ROLE_ID)/Microsoft.Dynamics.CRM.AddPrivilegesRole" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$payload")
    
    http_code=$(echo "$result" | tail -n 1)
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "204" ]]; then
        return 0
    else
        return 1
    fi
}

# Assign privileges for each table
print_info "Assigning privileges..."

PRIV_TYPES=("Create" "Read" "Write" "Delete" "Append" "AppendTo" "Assign" "Share")

for table in "${TABLES[@]}"; do
    table_name="${PUBLISHER_PREFIX}_${table}"
    print_info "Processing: $table_name"
    
    for priv_type in "${PRIV_TYPES[@]}"; do
        priv_name="prv${priv_type}${table_name}"
        
        priv_id=$(echo "$all_privs" | jq -r --arg name "$priv_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
        
        if [[ -n "$priv_id" && "$priv_id" != "null" ]]; then
            if add_privilege "$priv_id" "3"; then
                print_success "  ✓ $priv_type"
            else
                print_warning "  ⚠ $priv_type (may already exist)"
            fi
            sleep 0.3
        else
            print_warning "  ⚠ $priv_type privilege not found"
        fi
    done
done

# Add standard privileges
print_info "Adding standard privileges..."

STANDARD_PRIVS=(
    "prvReadBusinessUnit"
    "prvReadSystemUser"
)

for priv_name in "${STANDARD_PRIVS[@]}"; do
    priv_id=$(echo "$all_privs" | jq -r --arg name "$priv_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
    
    if [[ -n "$priv_id" && "$priv_id" != "null" ]]; then
        if add_privilege "$priv_id" "3"; then
            print_success "  ✓ $priv_name"
        else
            print_warning "  ⚠ $priv_name (may already exist)"
        fi
    fi
done

print_success "Security role configuration complete!"
print_info "Role ID: $ROLE_ID"
print_info "Role Name: $ROLE_NAME"

exit 0
