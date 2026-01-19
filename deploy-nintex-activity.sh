#!/bin/bash

#############################################################################
# Nintex Digital Signature Activity - Dataverse Deployment Script
# macOS/Linux compatible - Uses JSON config for authentication
#
# Usage: 
#   ./deploy-nintex-activity.sh /path/to/config.json [mode]
#
# Modes:
#   all (default)    - Create schema + security role + configure settings
#   schema           - Create schema only (tables and fields)
#   security         - Create security role only (requires schema exists)
#   configure        - Configure status reasons and enable activities only
#   role-only        - Alias for 'security'
#
# Examples:
#   ./deploy-nintex-activity.sh config.json           # Creates everything
#   ./deploy-nintex-activity.sh config.json schema    # Schema only
#   ./deploy-nintex-activity.sh config.json security  # Security role only
#   ./deploy-nintex-activity.sh config.json configure # Post-config only
#
# Config JSON format:
# {
#   "clientId": "your-client-id",
#   "tenantId": "your-tenant-id",
#   "crmInstance": "yourorg",
#   "clientSecret": "your-client-secret",
#   "publisherPrefix": "cs",
#   "publisherName": "CloudStrucc Inc",
#   "roleName": "Nintex Digital Signature API User",
#   "roleDescription": "API user for Nintex digital signature operations"
# }
#############################################################################

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_step() { echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${YELLOW}▶ $1${NC}"; echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; }

# Check prerequisites
print_step "Checking Prerequisites"

if ! command -v jq &> /dev/null; then
    print_error "jq is not installed"
    echo "Install with: brew install jq"
    exit 1
fi
print_success "jq found"

if ! command -v curl &> /dev/null; then
    print_error "curl is not installed"
    exit 1
fi
print_success "curl found"

# Load configuration
CONFIG_FILE="$1"
DEPLOYMENT_MODE="${2:-all}"  # Default to 'all' if not specified

if [[ -z "$CONFIG_FILE" ]]; then
    print_error "Configuration file required!"
    echo ""
    echo "Usage: $0 /path/to/config.json [mode]"
    echo ""
    echo "Modes:"
    echo "  all (default) - Create schema + security role + configure settings"
    echo "  schema        - Create schema only (tables and fields)"
    echo "  security      - Create security role only"
    echo "  configure     - Configure status reasons and enable activities only"
    echo "  role-only     - Alias for 'security'"
    echo ""
    echo "Examples:"
    echo "  $0 config.json              # Creates everything and configures"
    echo "  $0 config.json schema       # Schema only"
    echo "  $0 config.json security     # Security role only"
    echo "  $0 config.json configure    # Post-deployment configuration only"
    echo ""
    echo "Config JSON format:"
    cat << 'EOF'
{
  "clientId": "your-app-registration-client-id",
  "tenantId": "your-azure-tenant-id",
  "crmInstance": "yourorg",
  "clientSecret": "your-client-secret",
  "publisherPrefix": "cs",
  "publisherName": "CloudStrucc Inc",
  "roleName": "Nintex Digital Signature API User",
  "roleDescription": "API user for Nintex digital signature operations"
}
EOF
    exit 1
fi

# Normalize mode
case "$DEPLOYMENT_MODE" in
    all|ALL)
        DEPLOYMENT_MODE="all"
        ;;
    schema|SCHEMA)
        DEPLOYMENT_MODE="schema"
        ;;
    security|SECURITY|role-only|ROLE-ONLY)
        DEPLOYMENT_MODE="security"
        ;;
    configure|CONFIGURE|config|CONFIG)
        DEPLOYMENT_MODE="configure"
        ;;
    *)
        print_error "Invalid mode: $DEPLOYMENT_MODE"
        echo "Valid modes: all, schema, security, configure, role-only"
        exit 1
        ;;
esac

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

print_success "Config file loaded: $CONFIG_FILE"

# Read configuration
print_step "Reading Configuration"
JSON_CONFIG=$(cat "$CONFIG_FILE")

CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')
PUBLISHER_PREFIX=$(echo "$JSON_CONFIG" | jq -r '.publisherPrefix // "cs"')
PUBLISHER_NAME=$(echo "$JSON_CONFIG" | jq -r '.publisherName // "CloudStrucc Inc"')
ROLE_NAME=$(echo "$JSON_CONFIG" | jq -r '.roleName // "Nintex Digital Signature API User"')
ROLE_DESCRIPTION=$(echo "$JSON_CONFIG" | jq -r '.roleDescription // "API user role for Nintex digital signature operations with minimal privileges"')

# Validate required fields
if [[ -z "$CLIENT_ID" || "$CLIENT_ID" == "null" ]]; then
    print_error "clientId is required in config.json"
    exit 1
fi

if [[ -z "$TENANT_ID" || "$TENANT_ID" == "null" ]]; then
    print_error "tenantId is required in config.json"
    exit 1
fi

if [[ -z "$CRM_INSTANCE" || "$CRM_INSTANCE" == "null" ]]; then
    print_error "crmInstance is required in config.json"
    exit 1
fi

if [[ -z "$CLIENT_SECRET" || "$CLIENT_SECRET" == "null" ]]; then
    print_error "clientSecret is required in config.json"
    exit 1
fi

# Construct URLs
AUTHORITY="https://login.microsoftonline.com/$TENANT_ID"
RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
TOKEN_ENDPOINT="$AUTHORITY/oauth2/v2.0/token"
API_URL="${RESOURCE}/api/data/v9.2"

print_info "Tenant ID: $TENANT_ID"
print_info "CRM Instance: $CRM_INSTANCE"
print_info "Publisher Prefix: $PUBLISHER_PREFIX"
print_info "API URL: $API_URL"
print_info "Deployment Mode: $DEPLOYMENT_MODE"
if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "security" ]]; then
    print_info "Security Role: $ROLE_NAME"
fi

# Get OAuth token
print_step "Authenticating to Dataverse"
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
    print_info "Response:"
    echo "$response" | jq '.'
    exit 1
fi

print_success "Access token acquired!"

# Function to make API call with retry
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if [[ -z "$data" ]]; then
            response=$(curl -s -w "\n%{http_code}" -X "$method" "${API_URL}/${endpoint}" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -H "OData-MaxVersion: 4.0" \
                -H "OData-Version: 4.0" \
                -H "Accept: application/json")
        else
            response=$(curl -s -w "\n%{http_code}" -X "$method" "${API_URL}/${endpoint}" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Content-Type: application/json" \
                -H "OData-MaxVersion: 4.0" \
                -H "OData-Version: 4.0" \
                -H "Accept: application/json" \
                -d "$data")
        fi
        
        http_code=$(echo "$response" | tail -n 1)
        body=$(echo "$response" | sed '$d')
        
        if [[ "$http_code" == "200" ]] || [[ "$http_code" == "201" ]] || [[ "$http_code" == "204" ]]; then
            echo "$body"
            return 0
        elif [[ "$http_code" == "429" ]]; then
            retry_count=$((retry_count + 1))
            print_warning "Rate limited (429). Retry $retry_count/$max_retries in 5 seconds..."
            sleep 5
        else
            print_error "API call failed with HTTP $http_code"
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
            return 1
        fi
    done
    
    print_error "Max retries exceeded"
    return 1
}

#############################################################################
# SCHEMA CREATION SECTION
#############################################################################

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "schema" ]]; then

print_info "Starting schema creation..."

# Step 1: Create Activity Entity
print_step "Creating Digital Signature Activity Entity"

entity_payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "IsActivity": true,
  "LogicalName": "${PUBLISHER_PREFIX}_digitalsignatureactivity",
  "SchemaName": "${PUBLISHER_PREFIX}_DigitalSignatureActivity",
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

print_info "Creating activity entity: ${PUBLISHER_PREFIX}_digitalsignatureactivity"
if result=$(api_call POST "EntityDefinitions" "$entity_payload"); then
    print_success "Activity entity created successfully!"
else
    print_error "Failed to create activity entity"
    exit 1
fi

print_info "Waiting 10 seconds for entity creation to complete..."
sleep 10

# Function to create attribute
create_attribute() {
    local name=$1
    local display_name=$2
    local description=$3
    local payload=$4
    
    print_info "Creating attribute: $display_name..."
    
    if result=$(api_call POST "EntityDefinitions(LogicalName='${PUBLISHER_PREFIX}_digitalsignatureactivity')/Attributes" "$payload"); then
        print_success "✓ Created: $display_name"
        sleep 2  # Delay between attribute creation
        return 0
    else
        print_error "✗ Failed: $display_name"
        return 1
    fi
}

# Step 2: Create Custom Attributes
print_step "Creating Custom Attributes"

# Attribute 1: Recipient Email
create_attribute \
    "recipientemail" \
    "Recipient Email" \
    "Email address of the signature recipient" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "${PUBLISHER_PREFIX}_RecipientEmail",
  "LogicalName": "${PUBLISHER_PREFIX}_recipientemail",
  "MaxLength": 100,
  "Format": "Email",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Recipient Email",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Email address of the signature recipient",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 2: Recipient Name
create_attribute \
    "recipientname" \
    "Recipient Name" \
    "Full name of the signature recipient" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "${PUBLISHER_PREFIX}_RecipientName",
  "LogicalName": "${PUBLISHER_PREFIX}_recipientname",
  "MaxLength": 200,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Recipient Name",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Full name of the signature recipient",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 3: Document Content
create_attribute \
    "documentcontent" \
    "Document Content" \
    "Base64 encoded document to be signed" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.MemoAttributeMetadata",
  "AttributeType": "Memo",
  "AttributeTypeName": { "Value": "MemoType" },
  "SchemaName": "${PUBLISHER_PREFIX}_DocumentContent",
  "LogicalName": "${PUBLISHER_PREFIX}_documentcontent",
  "MaxLength": 1048576,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Document Content",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Base64 encoded document to be signed",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 4: Document Name
create_attribute \
    "documentname" \
    "Document Name" \
    "Name of the document to be signed" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "${PUBLISHER_PREFIX}_DocumentName",
  "LogicalName": "${PUBLISHER_PREFIX}_documentname",
  "MaxLength": 200,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Document Name",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Name of the document to be signed",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 5: Nintex Request ID
create_attribute \
    "nintexrequestid" \
    "Nintex Request ID" \
    "Unique identifier from Nintex AssureSign API" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "${PUBLISHER_PREFIX}_NintexRequestId",
  "LogicalName": "${PUBLISHER_PREFIX}_nintexrequestid",
  "MaxLength": 100,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Nintex Request ID",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Unique identifier from Nintex AssureSign API",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 6: Signed Document
create_attribute \
    "signaturedocument" \
    "Signed Document" \
    "Base64 encoded signed document" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.MemoAttributeMetadata",
  "AttributeType": "Memo",
  "AttributeTypeName": { "Value": "MemoType" },
  "SchemaName": "${PUBLISHER_PREFIX}_SignatureDocument",
  "LogicalName": "${PUBLISHER_PREFIX}_signaturedocument",
  "MaxLength": 1048576,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Signed Document",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Base64 encoded signed document",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 7: Signature Date
create_attribute \
    "signaturedate" \
    "Signature Date" \
    "Date and time when the document was signed" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "AttributeType": "DateTime",
  "AttributeTypeName": { "Value": "DateTimeType" },
  "SchemaName": "${PUBLISHER_PREFIX}_SignatureDate",
  "LogicalName": "${PUBLISHER_PREFIX}_signaturedate",
  "Format": "DateAndTime",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Signature Date",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Date and time when the document was signed",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 8: Request Date
create_attribute \
    "requestdate" \
    "Request Date" \
    "Date and time when the signature request was sent" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "AttributeType": "DateTime",
  "AttributeTypeName": { "Value": "DateTimeType" },
  "SchemaName": "${PUBLISHER_PREFIX}_RequestDate",
  "LogicalName": "${PUBLISHER_PREFIX}_requestdate",
  "Format": "DateAndTime",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Request Date",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Date and time when the signature request was sent",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 9: Expiry Date
create_attribute \
    "expirydate" \
    "Expiry Date" \
    "Date and time when the signature request expires" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "AttributeType": "DateTime",
  "AttributeTypeName": { "Value": "DateTimeType" },
  "SchemaName": "${PUBLISHER_PREFIX}_ExpiryDate",
  "LogicalName": "${PUBLISHER_PREFIX}_expirydate",
  "Format": "DateAndTime",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Expiry Date",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Date and time when the signature request expires",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Attribute 10: Callback URL
create_attribute \
    "callbackurl" \
    "Callback URL" \
    "Webhook URL for status update notifications" \
    "$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": { "Value": "StringType" },
  "SchemaName": "${PUBLISHER_PREFIX}_CallbackUrl",
  "LogicalName": "${PUBLISHER_PREFIX}_callbackurl",
  "MaxLength": 500,
  "Format": "Url",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Callback URL",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Webhook URL for status update notifications",
        "LanguageCode": 1033
      }
    ]
  },
  "RequiredLevel": { "Value": "None" },
  "IsCustomizable": { "Value": true }
}
EOF
)"

# Step 3: Publish All Customizations
print_step "Publishing Customizations"
print_info "Publishing all changes..."

publish_payload='{"ParameterXml": "<importexportxml></importexportxml>"}'

if result=$(api_call POST "PublishAllXml" "$publish_payload"); then
    print_success "Customizations published successfully!"
else
    print_error "Failed to publish customizations"
    exit 1
fi

print_success "Schema creation complete!"

fi  # End of schema creation section

#############################################################################
# SECURITY ROLE CREATION SECTION
#############################################################################

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "security" ]]; then

print_info "Starting security role creation..."

# Function to get entity metadata ID
get_entity_id() {
    local entity_logical_name=$1
    print_info "Getting metadata ID for entity: $entity_logical_name"
    
    result=$(api_call GET "EntityDefinitions(LogicalName='$entity_logical_name')?\$select=MetadataId" "")
    if [[ $? -eq 0 ]]; then
        entity_id=$(echo "$result" | jq -r '.MetadataId')
        if [[ -n "$entity_id" && "$entity_id" != "null" ]]; then
            echo "$entity_id"
            return 0
        fi
    fi
    
    print_error "Could not retrieve entity ID for: $entity_logical_name"
    return 1
}

# Step 4: Create Security Role
print_step "Creating Security Role: $ROLE_NAME"

# Create the role first
role_payload=$(cat <<EOF
{
  "name": "$ROLE_NAME",
  "businessunitid@odata.bind": "/businessunits(BUSINESS_UNIT_ID)"
}
EOF
)

# Get root business unit ID
print_info "Getting root business unit..."
bu_result=$(api_call GET "businessunits?\$filter=parentbusinessunitid eq null&\$select=businessunitid" "")
if [[ $? -ne 0 ]]; then
    print_error "Failed to get root business unit"
    exit 1
fi

BUSINESS_UNIT_ID=$(echo "$bu_result" | jq -r '.value[0].businessunitid')
if [[ -z "$BUSINESS_UNIT_ID" || "$BUSINESS_UNIT_ID" == "null" ]]; then
    print_error "Could not determine root business unit ID"
    exit 1
fi

print_info "Business Unit ID: $BUSINESS_UNIT_ID"

# Create role with correct business unit
role_payload=$(cat <<EOF
{
  "name": "$ROLE_NAME",
  "businessunitid@odata.bind": "/businessunits($BUSINESS_UNIT_ID)"
}
EOF
)

print_info "Creating security role..."
if role_response=$(api_call POST "roles" "$role_payload"); then
    ROLE_ID=$(echo "$role_response" | jq -r '.roleid')
    print_success "Security role created! ID: $ROLE_ID"
else
    print_error "Failed to create security role"
    # Check if role already exists
    print_info "Checking if role already exists..."
    existing_role=$(api_call GET "roles?\$filter=name eq '$ROLE_NAME'&\$select=roleid" "")
    ROLE_ID=$(echo "$existing_role" | jq -r '.value[0].roleid')
    
    if [[ -n "$ROLE_ID" && "$ROLE_ID" != "null" ]]; then
        print_warning "Role already exists with ID: $ROLE_ID"
        print_info "Will update privileges on existing role..."
    else
        print_error "Could not create or find security role"
        exit 1
    fi
fi

# Step 5: Assign Privileges to Security Role
print_step "Configuring Security Role Privileges"

# Define entities and their required privileges
# Privilege Depth: Basic (0), Local (1), Deep (2), Global (3)
declare -A ENTITIES=(
    # Digital Signature Activity - Full CRUD + Append/AppendTo
    ["${PUBLISHER_PREFIX}_digitalsignatureactivity"]="Create:3,Read:3,Write:3,Delete:3,Append:3,AppendTo:3,Assign:3,Share:3"
    
    # Related standard entities - Read access for lookups and relationships
    ["account"]="Read:3"
    ["contact"]="Read:3"
    ["incident"]="Read:3"  # Case entity
    ["opportunity"]="Read:3"
    ["activitypointer"]="Read:3"  # Base activity entity
    ["email"]="Read:1"  # Basic email read for notifications
    ["systemuser"]="Read:3"  # Read users for owner lookups
    ["team"]="Read:3"  # Read teams for owner lookups
    ["businessunit"]="Read:3"  # Read business units
)

# Privilege type GUIDs (these are standard in all Dataverse environments)
declare -A PRIVILEGE_TYPES=(
    ["Create"]="Create"
    ["Read"]="Read"
    ["Write"]="Write"
    ["Delete"]="Delete"
    ["Append"]="Append"
    ["AppendTo"]="AppendTo"
    ["Assign"]="Assign"
    ["Share"]="Share"
)

# Function to add privilege to role
add_privilege_to_role() {
    local role_id=$1
    local privilege_id=$2
    local depth=$3
    
    privilege_payload=$(cat <<EOF
{
  "PrivilegeId": "$privilege_id",
  "Depth": "$depth"
}
EOF
)
    
    # Add privilege using AddPrivilegesRole action
    if result=$(api_call POST "roles($role_id)/Microsoft.Dynamics.CRM.AddPrivilegesRole" "$privilege_payload"); then
        return 0
    else
        return 1
    fi
}

# Function to get privilege ID for entity and type
get_privilege_id() {
    local entity_name=$1
    local privilege_type=$2
    
    # Query for the privilege
    filter="Name eq '${privilege_type}${entity_name}'"
    result=$(api_call GET "privileges?\$filter=$filter&\$select=privilegeid,name" "")
    
    if [[ $? -eq 0 ]]; then
        privilege_id=$(echo "$result" | jq -r '.value[0].privilegeid')
        if [[ -n "$privilege_id" && "$privilege_id" != "null" ]]; then
            echo "$privilege_id"
            return 0
        fi
    fi
    
    return 1
}

# Process each entity and assign privileges
for entity in "${!ENTITIES[@]}"; do
    print_info "Configuring privileges for: $entity"
    
    # Parse privilege requirements
    IFS=',' read -ra PRIVS <<< "${ENTITIES[$entity]}"
    
    for priv in "${PRIVS[@]}"; do
        IFS=':' read -r priv_type priv_depth <<< "$priv"
        
        print_info "  Adding $priv_type privilege (depth: $priv_depth)..."
        
        # Get privilege ID
        if privilege_id=$(get_privilege_id "$entity" "$priv_type"); then
            # Add to role
            if add_privilege_to_role "$ROLE_ID" "$privilege_id" "$priv_depth"; then
                print_success "    ✓ Added $priv_type privilege"
            else
                print_warning "    ⚠ Could not add $priv_type privilege (may already exist)"
            fi
        else
            print_warning "    ⚠ Privilege not found: $priv_type$entity"
        fi
        
        sleep 0.5  # Small delay between privilege additions
    done
done

# Add miscellaneous required privileges
print_step "Adding Miscellaneous Privileges"

# These are common privileges needed for API users
MISC_PRIVILEGES=(
    "prvReadUserId"  # Read own user record
    "prvReadBusinessUnit"  # Read business units
    "prvReadQuery"  # Execute queries
)

for priv_name in "${MISC_PRIVILEGES[@]}"; do
    print_info "Adding privilege: $priv_name..."
    
    result=$(api_call GET "privileges?\$filter=Name eq '$priv_name'&\$select=privilegeid" "")
    privilege_id=$(echo "$result" | jq -r '.value[0].privilegeid')
    
    if [[ -n "$privilege_id" && "$privilege_id" != "null" ]]; then
        if add_privilege_to_role "$ROLE_ID" "$privilege_id" "3"; then
            print_success "  ✓ Added $priv_name"
        else
            print_warning "  ⚠ Could not add $priv_name (may already exist)"
        fi
    fi
done

print_success "Security role configuration complete!"
print_info "Role ID: $ROLE_ID"
print_info "Role Name: $ROLE_NAME"

fi  # End of security role creation section

#############################################################################
# STATUS REASON CONFIGURATION SECTION
#############################################################################

configure_status_reasons() {
    local entity_logical_name="${PUBLISHER_PREFIX}_digitalsignatureactivity"
    
    print_step "Configuring Status Reason Values"
    print_info "Adding custom status reason options for digital signature workflow..."
    
    # Get the StatusCode attribute metadata ID
    print_info "Retrieving StatusCode attribute metadata..."
    result=$(api_call GET "EntityDefinitions(LogicalName='$entity_logical_name')/Attributes(LogicalName='statuscode')?\$select=MetadataId" "")
    
    if [[ $? -ne 0 ]]; then
        print_error "Failed to retrieve StatusCode attribute"
        return 1
    fi
    
    STATUS_ATTR_ID=$(echo "$result" | jq -r '.MetadataId')
    
    if [[ -z "$STATUS_ATTR_ID" || "$STATUS_ATTR_ID" == "null" ]]; then
        print_error "Could not get StatusCode attribute ID"
        return 1
    fi
    
    print_info "StatusCode Attribute ID: $STATUS_ATTR_ID"
    
    # Define status reasons to add
    # Format: State,Value,Label
    declare -a STATUS_REASONS=(
        "0,1,Draft"
        "0,2,Pending Signature"
        "0,3,Failed to Send"
        "1,4,Signed"
        "2,5,Declined"
        "2,6,Expired"
    )
    
    # Function to add status reason option
    add_status_reason() {
        local state=$1
        local value=$2
        local label=$3
        
        print_info "Adding: $label (State: $state, Value: $value)"
        
        # Insert new option
        insert_payload=$(cat <<EOF
{
  "AttributeLogicalName": "statuscode",
  "EntityLogicalName": "$entity_logical_name",
  "Value": $value,
  "Label": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "$label",
        "LanguageCode": 1033
      }
    ]
  },
  "State": $state
}
EOF
)
        
        # Use InsertOptionValue action
        if result=$(api_call POST "InsertOptionValue" "$insert_payload"); then
            print_success "  ✓ Added: $label"
            return 0
        else
            print_warning "  ⚠ Could not add $label (may already exist)"
            return 1
        fi
    }
    
    # Add each status reason
    for status_reason in "${STATUS_REASONS[@]}"; do
        IFS=',' read -r state value label <<< "$status_reason"
        add_status_reason "$state" "$value" "$label"
        sleep 1  # Delay between additions
    done
    
    print_success "Status Reason configuration complete!"
    
    # Publish changes
    print_info "Publishing status reason changes..."
    publish_payload='{"ParameterXml": "<importexportxml></importexportxml>"}'
    
    if result=$(api_call POST "PublishAllXml" "$publish_payload"); then
        print_success "Status reasons published successfully!"
    else
        print_warning "Failed to publish status reasons (they may still be applied)"
    fi
    
    return 0
}

#############################################################################
# ENABLE ACTIVITIES ON ENTITIES SECTION
#############################################################################

enable_activities_on_entities() {
    print_step "Enabling Activities on Target Entities"
    print_info "Configuring Account, Contact, and Case entities for activities..."
    
    # Entities to enable activities on
    declare -a TARGET_ENTITIES=(
        "account"
        "contact"
        "incident"  # This is the logical name for Case
    )
    
    # Function to enable activities on an entity
    enable_activities() {
        local entity_name=$1
        local display_name=$2
        
        print_info "Enabling activities on: $display_name ($entity_name)"
        
        # Get current entity metadata
        result=$(api_call GET "EntityDefinitions(LogicalName='$entity_name')?\$select=IsActivityParty,HasActivities,MetadataId" "")
        
        if [[ $? -ne 0 ]]; then
            print_error "Failed to retrieve entity metadata for: $entity_name"
            return 1
        fi
        
        current_has_activities=$(echo "$result" | jq -r '.HasActivities')
        entity_id=$(echo "$result" | jq -r '.MetadataId')
        
        if [[ "$current_has_activities" == "true" ]]; then
            print_success "  ✓ Activities already enabled on $display_name"
            return 0
        fi
        
        # Update entity to enable activities
        update_payload=$(cat <<EOF
{
  "HasActivities": true,
  "IsActivityParty": true
}
EOF
)
        
        if result=$(api_call PATCH "EntityDefinitions($entity_id)" "$update_payload"); then
            print_success "  ✓ Enabled activities on $display_name"
            return 0
        else
            print_error "  ✗ Failed to enable activities on $display_name"
            return 1
        fi
    }
    
    # Enable activities on each entity
    for entity in "${TARGET_ENTITIES[@]}"; do
        case $entity in
            account)
                enable_activities "$entity" "Account"
                ;;
            contact)
                enable_activities "$entity" "Contact"
                ;;
            incident)
                enable_activities "$entity" "Case"
                ;;
        esac
        sleep 1
    done
    
    # Publish changes
    print_info "Publishing entity changes..."
    publish_payload='{"ParameterXml": "<importexportxml></importexportxml>"}'
    
    if result=$(api_call POST "PublishAllXml" "$publish_payload"); then
        print_success "Entity configurations published successfully!"
    else
        print_warning "Failed to publish entity changes"
    fi
    
    print_success "Activity enablement complete!"
    return 0
}

#############################################################################
# POST-DEPLOYMENT CONFIGURATION SECTION
#############################################################################

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "configure" ]]; then

print_info "Starting post-deployment configuration..."

# Configure status reasons
if ! configure_status_reasons; then
    print_warning "Status reason configuration had issues (not critical)"
fi

echo ""

# Enable activities on entities
if ! enable_activities_on_entities; then
    print_warning "Activity enablement had issues (not critical)"
fi

print_success "Post-deployment configuration complete!"

fi  # End of post-deployment configuration

#############################################################################
# FINAL SUMMARY
#############################################################################

# Summary
print_step "Deployment Complete!"
echo ""

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "schema" ]]; then
    print_success "Digital Signature Activity created successfully!"
    echo ""
    print_info "Entity Details:"
    echo "  • Logical Name: ${PUBLISHER_PREFIX}_digitalsignatureactivity"
    echo "  • Display Name: Digital Signature Activity"
    echo "  • Type: Activity (Timeline-enabled)"
    echo "  • Custom Attributes: 10"
    echo ""
fi

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "configure" ]]; then
    print_success "Post-Deployment Configuration Applied!"
    echo ""
    print_info "Configuration Details:"
    echo "  • Status Reasons: Configured (Draft, Pending, Signed, Declined, Expired, Failed)"
    echo "  • Activities Enabled: Account, Contact, Case"
    echo ""
fi

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "security" ]]; then
    print_success "Security Role configured successfully!"
    echo ""
    print_info "Security Role Details:"
    echo "  • Role Name: $ROLE_NAME"
    echo "  • Role ID: $ROLE_ID"
    echo "  • Privileges: Full CRUD on Digital Signature Activity"
    echo "  • Additional Access: Read on Account, Contact, Case, Opportunity"
    echo ""
    print_warning "To assign this role to your API user:"
    echo "  1. Go to: https://${CRM_INSTANCE}.crm3.dynamics.com"
    echo "  2. Settings → Security → Users"
    echo "  3. Find your API application user"
    echo "  4. Click 'Manage Roles'"
    echo "  5. Assign role: '$ROLE_NAME'"
    echo "  6. Remove 'System Administrator' role"
    echo ""
fi

print_warning "Remaining Manual Steps:"

if [[ "$DEPLOYMENT_MODE" != "all" ]] && [[ "$DEPLOYMENT_MODE" != "configure" ]]; then
    echo "  1. Configure Status Reason values (run with 'configure' mode or manually):"
    echo "     • State Open (0): Draft (1), Pending Signature (2), Failed to Send (3)"
    echo "     • State Completed (1): Signed (4)"
    echo "     • State Cancelled (2): Declined (5), Expired (6)"
    echo ""
    echo "  2. Enable activities on target entities (run with 'configure' mode or manually):"
    echo "     • Account, Contact, Case"
    echo ""
    STEP_NUM=3
else
    STEP_NUM=1
fi

echo "  $STEP_NUM. Create forms:"
echo "     • Quick Create form (for Timeline)"
echo "     • Main form (for full details)"
echo ""
STEP_NUM=$((STEP_NUM + 1))

echo "  $STEP_NUM. Deploy C# plugin for Nintex API integration"
echo ""
STEP_NUM=$((STEP_NUM + 1))

if [[ "$DEPLOYMENT_MODE" == "security" ]]; then
    echo "  $STEP_NUM. Assign security role to API user (see instructions above)"
    echo ""
    STEP_NUM=$((STEP_NUM + 1))
fi

echo "  $STEP_NUM. Test timeline integration:"
echo "     • Open an Account record"
echo "     • Navigate to Timeline"
echo "     • Create a new Digital Signature Activity"
echo "     • Verify it saves and appears correctly"
echo ""

print_success "Access your new activity at:"
echo "  https://${CRM_INSTANCE}.crm3.dynamics.com/main.aspx?pagetype=entitylist&etn=${PUBLISHER_PREFIX}_digitalsignatureactivity"
echo ""

if [[ "$DEPLOYMENT_MODE" == "all" ]]; then
    print_info "💡 Tip: All automated configurations have been applied!"
    print_info "You can focus on creating forms and deploying the plugin."
fi

echo ""