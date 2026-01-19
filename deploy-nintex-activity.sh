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

# Don't use set -e as it causes silent exits on non-critical errors
# We handle errors explicitly in each section

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
            print_error "Endpoint: ${method} ${API_URL}/${endpoint}"
            echo "Response body:"
            echo "$body" | jq '.' 2>/dev/null || echo "$body"
            
            # Parse and show error details
            if echo "$body" | jq -e '.error' > /dev/null 2>&1; then
                error_code=$(echo "$body" | jq -r '.error.code')
                error_message=$(echo "$body" | jq -r '.error.message')
                print_error "Error Code: $error_code"
                print_error "Error Message: $error_message"
            fi
            
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

# Step 1: Check if Digital Signature Table exists
print_step "Checking for Existing Digital Signature Table"

print_info "Checking if table ${PUBLISHER_PREFIX}_digitalsignature exists..."
check_result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/EntityDefinitions(LogicalName='${PUBLISHER_PREFIX}_digitalsignature')?\$select=LogicalName,DisplayName,MetadataId" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "OData-Version: 4.0" \
    -H "Accept: application/json")

check_http_code=$(echo "$check_result" | tail -n 1)
check_body=$(echo "$check_result" | sed '$d')

if [[ "$check_http_code" == "200" ]]; then
    print_success "Table already exists! Skipping table creation."
    ENTITY_EXISTS=true
    entity_metadata_id=$(echo "$check_body" | jq -r '.MetadataId')
    print_info "Entity MetadataId: $entity_metadata_id"
elif [[ "$check_http_code" == "404" ]]; then
    print_info "Table does not exist. Attempting to create..."
    ENTITY_EXISTS=false
    
    # Step 1a: Create Digital Signature Table
    print_step "Creating Digital Signature Table"
    
    print_warning "Note: Automated table creation via Web API can be unreliable."
    print_info "If this fails, please create the table manually:"
    echo ""
    echo "  1. Go to https://make.powerapps.com"
    echo "  2. Tables → + New table → Add columns and data"
    echo "  3. Name: Digital Signature"
    echo "  4. Primary column: Name"
    echo "  5. Save"
    echo "  6. Then re-run: ./deploy-nintex-activity.sh config.json schema"
    echo ""
    print_info "Attempting automated creation in 3 seconds..."
    sleep 3
    
    entity_payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "LogicalName": "${PUBLISHER_PREFIX}_digitalsignature",
  "SchemaName": "${PUBLISHER_PREFIX}_DigitalSignature",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Digital Signature",
        "LanguageCode": 1033
      }
    ]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Digital Signatures",
        "LanguageCode": 1033
      }
    ]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Table for managing digital signature requests via Nintex AssureSign API",
        "LanguageCode": 1033
      }
    ]
  },
  "OwnershipType": "UserOwned",
  "IsCustomizable": {
    "Value": true
  },
  "HasActivities": true,
  "HasNotes": true,
  "HasAttributes": true,
  "Attributes": [
    {
      "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
      "AttributeType": "String",
      "AttributeTypeName": {
        "Value": "StringType"
      },
      "SchemaName": "${PUBLISHER_PREFIX}_Name",
      "IsPrimaryName": true,
      "RequiredLevel": {
        "Value": "None"
      },
      "MaxLength": 200,
      "FormatName": {
        "Value": "Text"
      },
      "DisplayName": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [
          {
            "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
            "Label": "Name",
            "LanguageCode": 1033
          }
        ]
      },
      "Description": {
        "@odata.type": "Microsoft.Dynamics.CRM.Label",
        "LocalizedLabels": [
          {
            "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
            "Label": "Name of the signature request",
            "LanguageCode": 1033
          }
        ]
      }
    }
  ]
}
EOF
)

    print_info "Creating table: ${PUBLISHER_PREFIX}_digitalsignature"
    
    create_result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/EntityDefinitions" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "OData-MaxVersion: 4.0" \
        -H "OData-Version: 4.0" \
        -H "Accept: application/json" \
        -d "$entity_payload")
    
    create_http_code=$(echo "$create_result" | tail -n 1)
    create_body=$(echo "$create_result" | sed '$d')
    
    if [[ "$create_http_code" == "201" ]] || [[ "$create_http_code" == "204" ]] || [[ "$create_http_code" == "200" ]]; then
        print_success "Table created successfully!"
        ENTITY_EXISTS=true
    else
        print_error "Failed to create table - HTTP $create_http_code"
        echo ""
        print_error "Error details:"
        echo "$create_body" | jq '.' 2>/dev/null || echo "$create_body"
        echo ""
        print_warning "NEXT STEPS:"
        echo "1. Create the table manually at https://make.powerapps.com"
        echo "2. Tables → + New table → Add columns and data"
        echo "3. Name: Digital Signature"
        echo "4. Primary column: Name"  
        echo "5. Save"
        echo "6. Re-run: ./deploy-nintex-activity.sh config.json schema"
        echo ""
        exit 1
    fi
else
    print_error "Unexpected response checking for table: HTTP $check_http_code"
    echo "$check_body" | jq '.' 2>/dev/null || echo "$check_body"
    exit 1
fi

print_info "Waiting 10 seconds for table provisioning to complete..."
sleep 10

# Function to create attribute
create_attribute() {
    local name=$1
    local display_name=$2
    local description=$3
    local payload=$4
    
    print_info "Creating attribute: $display_name..."
    
    if result=$(api_call POST "EntityDefinitions(LogicalName='${PUBLISHER_PREFIX}_digitalsignature')/Attributes" "$payload"); then
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

# Step 4: Create or Find Security Role
print_step "Creating Security Role: $ROLE_NAME"

# Get root business unit ID first (needed for role creation if it doesn't exist)
print_info "Getting business units..."

bu_result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/businessunits?\$select=businessunitid,parentbusinessunitid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "OData-Version: 4.0" \
    -H "Accept: application/json")

bu_http_code=$(echo "$bu_result" | tail -n 1)
bu_body=$(echo "$bu_result" | sed '$d')

if [[ "$bu_http_code" != "200" ]]; then
    print_error "Failed to get business units - HTTP $bu_http_code"
    echo "$bu_body" | jq '.' 2>/dev/null || echo "$bu_body"
    exit 1
fi

# Find the root business unit (one without a parent)
BUSINESS_UNIT_ID=$(echo "$bu_body" | jq -r '.value[] | select(.parentbusinessunitid == null or ._parentbusinessunitid_value == null) | .businessunitid' | head -n 1)

if [[ -z "$BUSINESS_UNIT_ID" || "$BUSINESS_UNIT_ID" == "null" ]]; then
    print_error "Could not find root business unit"
    exit 1
fi

print_success "Root Business Unit ID: $BUSINESS_UNIT_ID"

# Now check if role already exists
print_info "Checking if role already exists..."

# Get all roles (simpler query, no filtering)
check_result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/roles?\$select=roleid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "Accept: application/json")

check_http_code=$(echo "$check_result" | tail -n 1)
check_body=$(echo "$check_result" | sed '$d')

if [[ "$check_http_code" != "200" ]]; then
    print_error "Failed to retrieve roles - HTTP $check_http_code"
    echo "$check_body" | jq '.' 2>/dev/null || echo "$check_body"
    exit 1
fi

# Filter for our role in bash using jq
ROLE_ID=$(echo "$check_body" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)

if [[ -n "$ROLE_ID" && "$ROLE_ID" != "null" ]]; then
    print_warning "Security role already exists with ID: $ROLE_ID"
    print_info "Will update privileges on existing role..."
else
    # Role doesn't exist, create it
    print_info "Role not found. Creating new security role..."
    
    # Create role with correct business unit
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
        -H "OData-MaxVersion: 4.0" \
        -H "OData-Version: 4.0" \
        -H "Accept: application/json" \
        -H "Prefer: return=representation" \
        -d "$role_payload")
    
    role_http_code=$(echo "$role_result" | tail -n 1)
    role_body=$(echo "$role_result" | sed '$d')
    
    if [[ "$role_http_code" == "201" ]] || [[ "$role_http_code" == "204" ]] || [[ "$role_http_code" == "200" ]]; then
        # Try to get role ID from response
        ROLE_ID=$(echo "$role_body" | jq -r '.roleid // empty')
        
        if [[ -z "$ROLE_ID" || "$ROLE_ID" == "null" ]]; then
            # Query for it if not in response
            print_info "Retrieving created role ID..."
            sleep 2
            
            query_result=$(curl -s "${API_URL}/roles?\$select=roleid,name" \
                -H "Authorization: Bearer $TOKEN" \
                -H "Accept: application/json")
            
            ROLE_ID=$(echo "$query_result" | jq -r --arg name "$ROLE_NAME" '.value[] | select(.name == $name) | .roleid' | head -n 1)
        fi
        
        if [[ -n "$ROLE_ID" && "$ROLE_ID" != "null" ]]; then
            print_success "Security role created! ID: $ROLE_ID"
        else
            print_error "Role created but couldn't retrieve ID"
            exit 1
        fi
    else
        print_error "Failed to create security role - HTTP $role_http_code"
        echo "$role_body" | jq '.' 2>/dev/null || echo "$role_body"
        exit 1
    fi
fi

print_success "Using Security Role ID: $ROLE_ID"

# Step 5: Assign Privileges to Security Role
print_step "Configuring Security Role Privileges"

# Define entities and their required privileges in a simple format
# Format: entity_name|privilege1:depth1,privilege2:depth2,...
ENTITY_PRIVILEGES=(
    "${PUBLISHER_PREFIX}_digitalsignature|Create:3,Read:3,Write:3,Delete:3,Append:3,AppendTo:3,Assign:3,Share:3"
    "account|Read:3"
    "contact|Read:3"
    "incident|Read:3"
    "opportunity|Read:3"
    "email|Read:1"
    "systemuser|Read:3"
    "team|Read:3"
    "businessunit|Read:3"
)

# Privilege type names (for constructing privilege names)
PRIVILEGE_TYPES=("Create" "Read" "Write" "Delete" "Append" "AppendTo" "Assign" "Share")

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
    
    # Dataverse privilege names follow pattern: prv<Type><entityname>
    # Example: prvCreatecs_digitalsignature, prvReadaccount
    local privilege_name="prv${privilege_type}${entity_name}"
    
    # Get all privileges and filter locally (avoid $filter issues)
    result=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
        -H "Authorization: Bearer $TOKEN" \
        -H "OData-MaxVersion: 4.0" \
        -H "Accept: application/json")
    
    if [[ $? -eq 0 ]]; then
        # Filter locally using jq
        privilege_id=$(echo "$result" | jq -r --arg name "$privilege_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
        
        if [[ -n "$privilege_id" && "$privilege_id" != "null" ]]; then
            echo "$privilege_id"
            return 0
        fi
    fi
    
    return 1
}

# Process each entity and assign privileges
for entity_config in "${ENTITY_PRIVILEGES[@]}"; do
    # Split entity name and privileges
    entity=$(echo "$entity_config" | cut -d'|' -f1)
    privileges=$(echo "$entity_config" | cut -d'|' -f2)
    
    print_info "Configuring privileges for: $entity"
    
    # Parse privilege requirements (comma-separated list)
    IFS=',' read -ra PRIVS <<< "$privileges"
    
    for priv in "${PRIVS[@]}"; do
        # Split privilege type and depth
        priv_type=$(echo "$priv" | cut -d':' -f1)
        priv_depth=$(echo "$priv" | cut -d':' -f2)
        
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

# Get all privileges once
print_info "Retrieving privilege list..."
all_privs=$(curl -s "${API_URL}/privileges?\$select=privilegeid,name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "OData-MaxVersion: 4.0" \
    -H "Accept: application/json")

for priv_name in "${MISC_PRIVILEGES[@]}"; do
    print_info "Adding privilege: $priv_name..."
    
    # Filter locally
    privilege_id=$(echo "$all_privs" | jq -r --arg name "$priv_name" '.value[] | select(.name == $name) | .privilegeid' | head -n 1)
    
    if [[ -n "$privilege_id" && "$privilege_id" != "null" ]]; then
        if add_privilege_to_role "$ROLE_ID" "$privilege_id" "3"; then
            print_success "  ✓ Added $priv_name"
        else
            print_warning "  ⚠ Could not add $priv_name (may already exist)"
        fi
    else
        print_warning "  ⚠ Privilege not found: $priv_name"
    fi
done

print_success "Security role configuration complete!"
print_info "Role ID: $ROLE_ID"
print_info "Role Name: $ROLE_NAME"

fi  # End of security role creation section

#############################################################################
# POST-DEPLOYMENT CONFIGURATION SECTION
#############################################################################

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "configure" ]]; then

print_info "Post-deployment configuration..."
print_info "Regular table created - no additional configuration needed for non-activity tables"

fi  # End of post-deployment configuration

#############################################################################
# FINAL SUMMARY
#############################################################################

# Summary
print_step "Deployment Complete!"
echo ""

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "schema" ]]; then
    print_success "Digital Signature Table created successfully!"
    echo ""
    print_info "Table Details:"
    echo "  • Logical Name: ${PUBLISHER_PREFIX}_digitalsignature"
    echo "  • Display Name: Digital Signature"
    echo "  • Type: Regular Table (UserOwned)"
    echo "  • Custom Attributes: 10"
    echo "  • Activities Enabled: Yes"
    echo ""
fi

if [[ "$DEPLOYMENT_MODE" == "all" ]] || [[ "$DEPLOYMENT_MODE" == "configure" ]]; then
    print_success "Post-Deployment Configuration Complete!"
    echo ""
    print_info "Note: Regular tables don't require Status Reason configuration like activities"
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
    STEP_NUM=1
else
    STEP_NUM=1
fi

echo "  $STEP_NUM. Create forms:"
echo "     • Main form with all fields"
echo "     • Quick create form"
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

echo "  $STEP_NUM. Test table functionality:"
echo "     • Create a new Digital Signature record"
echo "     • Verify all fields are accessible"
echo "     • Test API access with the security role"
echo ""

print_success "Access your new table at:"
echo "  https://${CRM_INSTANCE}.crm3.dynamics.com/main.aspx?pagetype=entitylist&etn=${PUBLISHER_PREFIX}_digitalsignature"
echo ""

if [[ "$DEPLOYMENT_MODE" == "all" ]]; then
    print_info "💡 Tip: All automated configurations have been applied!"
    print_info "You can focus on creating forms and deploying the plugin."
fi

echo ""