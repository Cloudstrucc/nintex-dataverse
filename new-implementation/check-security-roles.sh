#!/bin/bash

#############################################################################
# Create/Update Security Roles for Nintex Tables
# Reads table definitions from schema file and updates role privileges
#############################################################################

CONFIG_FILE="$1"
PUBLISHER_PREFIX="$2"
SCHEMA_FILE="${3:-nintex-tables-schema.json}"

if [[ -z "$CONFIG_FILE" ]] || [[ -z "$PUBLISHER_PREFIX" ]]; then
    echo "Usage: $0 config.json publisher_prefix [schema_file]"
    echo ""
    echo "Example:"
    echo "  $0 config.json cs"
    echo "  $0 config.json cs custom-schema.json"
    exit 1
fi

# Check if schema file exists
if [[ ! -f "$SCHEMA_FILE" ]]; then
    echo "❌ Schema file not found: $SCHEMA_FILE"
    echo ""
    echo "Make sure nintex-tables-schema.json is in the same directory"
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

# Load schema
SCHEMA=$(cat "$SCHEMA_FILE")
TABLE_COUNT=$(echo "$SCHEMA" | jq '.tables | length')

print_info "Loaded schema with $TABLE_COUNT tables"

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
    print_info "Will update privileges on existing role"
    UPDATE_MODE=true
else
    # Create role
    print_info "Creating new role: $ROLE_NAME"
    
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
        UPDATE_MODE=false
    else
        print_error "Failed to create role - HTTP $http_code"
        echo "$body" | jq '.'
        exit 1
    fi
fi

# Get all privileges
print_info "Retrieving privilege list..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

# Check if privileges were retrieved
if [[ -z "$all_privs" ]] || [[ "$all_privs" == "null" ]]; then
    print_error "Failed to retrieve privileges"
    exit 1
fi

priv_count=$(echo "$all_privs" | jq '.value | length')
print_success "Retrieved $priv_count privileges"

# Get current role privileges (for update mode)
if [[ "$UPDATE_MODE" == "true" ]]; then
    print_info "Getting current role privileges..."
    # Use $expand on role instead of roleprivileges navigation property
    current_privs_result=$(curl -s -w "\n%{http_code}" "${API_URL}/roles($ROLE_ID)?\$select=name&\$expand=roleprivileges(\$select=privilegeid)" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    http_code=$(echo "$current_privs_result" | tail -n 1)
    role_data=$(echo "$current_privs_result" | sed '$d')
    
    if [[ "$http_code" == "200" ]]; then
        # Extract the roleprivileges array
        current_privs=$(echo "$role_data" | jq '{value: .roleprivileges}')
        current_priv_count=$(echo "$current_privs" | jq '.value | length')
        print_info "Role currently has $current_priv_count privileges assigned"
    else
        print_warning "Could not retrieve current privileges - HTTP $http_code"
        print_info "Will attempt to add all privileges (may see duplicate warnings)"
        current_privs='{"value":[]}'
    fi
fi

# Function to check if privilege is already assigned
has_privilege() {
    local priv_id=$1
    
    if [[ "$UPDATE_MODE" != "true" ]]; then
        return 1  # New role, no privileges yet
    fi
    
    # Handle null/empty current_privs gracefully
    if [[ -z "$current_privs" ]] || [[ "$current_privs" == "null" ]]; then
        return 1  # No privileges loaded
    fi
    
    local exists=$(echo "$current_privs" | jq -r --arg id "$priv_id" '.value[]? | select(.privilegeid == $id) | .privilegeid' 2>/dev/null)
    
    if [[ -n "$exists" && "$exists" != "null" ]]; then
        return 0  # Privilege exists
    else
        return 1  # Privilege doesn't exist
    fi
}

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
    body=$(echo "$result" | sed '$d')
    
    if [[ "$http_code" == "200" ]] || [[ "$http_code" == "204" ]]; then
        return 0
    else
        # Log error details for debugging
        if [[ "$http_code" == "400" ]]; then
            error_msg=$(echo "$body" | jq -r '.error.message // "Unknown error"' 2>/dev/null)
            if [[ -n "$error_msg" && "$error_msg" != "null" ]]; then
                print_info "     Error: $error_msg"
            fi
        fi
        return 1
    fi
}

# Extract table names from schema
print_info "Extracting table definitions from schema..."

TABLES=()
for ((i=0; i<$TABLE_COUNT; i++)); do
    table_logical_name=$(echo "$SCHEMA" | jq -r ".tables[$i].logicalName")
    TABLES+=("$table_logical_name")
done

print_info "Found ${#TABLES[@]} tables in schema"

# Assign privileges for each table
echo ""
print_info "Assigning privileges for tables..."

PRIV_TYPES=("Create" "Read" "Write" "Delete" "Append" "AppendTo" "Assign" "Share")

ADDED_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

for table in "${TABLES[@]}"; do
    table_name="${PUBLISHER_PREFIX}_${table}"
    
    # Dataverse capitalizes the first letter after underscore
    # cs_useraccount becomes cs_Useraccount in privilege names
    first_char=$(echo "$table" | cut -c1 | tr '[:lower:]' '[:upper:]')
    rest_chars=$(echo "$table" | cut -c2-)
    capitalized_table="${first_char}${rest_chars}"
    
    print_info "Processing: $table_name"
    
    for priv_type in "${PRIV_TYPES[@]}"; do
        # Privilege names: prv + Type + cs_ + Capitalizedtablename
        priv_name="prv${priv_type}${PUBLISHER_PREFIX}_${capitalized_table}"
        
        priv_id=$(echo "$all_privs" | jq -r --arg name "$priv_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
        
        if [[ -n "$priv_id" && "$priv_id" != "null" ]]; then
            # Check if already assigned
            if has_privilege "$priv_id"; then
                print_info "  ↻ $priv_type (already assigned)"
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            else
                if add_privilege "$priv_id" "3"; then
                    print_success "  ✓ $priv_type"
                    ADDED_COUNT=$((ADDED_COUNT + 1))
                else
                    print_warning "  ⚠ $priv_type (failed to add)"
                    FAILED_COUNT=$((FAILED_COUNT + 1))
                fi
            fi
            sleep 0.2
        else
            print_warning "  ⚠ $priv_type privilege not found"
            print_info "     Looking for: $priv_name"
        fi
    done
done

# Add standard privileges
echo ""
print_info "Adding standard privileges..."

STANDARD_PRIVS=(
    "prvReadBusinessUnit"
    "prvReadSystemUser"
)

for priv_name in "${STANDARD_PRIVS[@]}"; do
    priv_id=$(echo "$all_privs" | jq -r --arg name "$priv_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
    
    if [[ -n "$priv_id" && "$priv_id" != "null" ]]; then
        if has_privilege "$priv_id"; then
            print_info "  ↻ $priv_name (already assigned)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        else
            if add_privilege "$priv_id" "3"; then
                print_success "  ✓ $priv_name"
                ADDED_COUNT=$((ADDED_COUNT + 1))
            else
                print_warning "  ⚠ $priv_name (failed to add)"
                FAILED_COUNT=$((FAILED_COUNT + 1))
            fi
        fi
    fi
done

echo ""
print_success "Security role configuration complete!"
echo ""
print_info "Summary:"
echo "  • Role ID: $ROLE_ID"
echo "  • Role Name: $ROLE_NAME"
echo "  • Tables processed: ${#TABLES[@]}"
echo "  • Privileges added: $ADDED_COUNT"
echo "  • Already assigned: $SKIPPED_COUNT"
echo "  • Failed: $FAILED_COUNT"

if [[ "$UPDATE_MODE" == "true" ]]; then
    echo ""
    print_success "Role updated successfully!"
    print_info "All new tables from schema have been added to the role"
else
    echo ""
    print_success "Role created successfully!"
fi

exit 0