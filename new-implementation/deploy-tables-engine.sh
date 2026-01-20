#!/bin/bash

#############################################################################
# Nintex Table Deployment Engine
# Creates or updates Dataverse tables from JSON schema definition
#############################################################################

CONFIG_FILE="$1"
SCHEMA_FILE="$2"
PUBLISHER_PREFIX="$3"

if [[ -z "$CONFIG_FILE" ]] || [[ -z "$SCHEMA_FILE" ]] || [[ -z "$PUBLISHER_PREFIX" ]]; then
    echo "Usage: $0 config.json schema.json publisher_prefix"
    echo ""
    echo "Example:"
    echo "  $0 config.json nintex-tables-schema.json cs"
    exit 1
fi

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
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

# Load schema
SCHEMA=$(cat "$SCHEMA_FILE")
TABLE_COUNT=$(echo "$SCHEMA" | jq '.tables | length')

print_info "Found $TABLE_COUNT tables to deploy"
echo ""

# Function to check if table exists
table_exists() {
    local logical_name=$1
    local full_name="${PUBLISHER_PREFIX}_${logical_name}"
    
    result=$(curl -s -w "\n%{http_code}" -X GET "${API_URL}/EntityDefinitions(LogicalName='$full_name')?\$select=LogicalName" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/json")
    
    http_code=$(echo "$result" | tail -n 1)
    
    if [[ "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to create table
create_table() {
    local table_json=$1
    local logical_name=$(echo "$table_json" | jq -r '.logicalName')
    local full_name="${PUBLISHER_PREFIX}_${logical_name}"
    
    print_info "Creating table: $full_name"
    
    # Build primary attribute
    local primary_attr=$(echo "$table_json" | jq -r '.primaryAttribute')
    local primary_schema=$(echo "$primary_attr" | jq -r '.schemaName')
    local primary_display=$(echo "$primary_attr" | jq -r '.displayName')
    local primary_desc=$(echo "$primary_attr" | jq -r '.description')
    local primary_max=$(echo "$primary_attr" | jq -r '.maxLength')
    
    # Capitalize first letter for SchemaName
    # Convert "envelope" to "Envelope"
    local first_char=$(echo "$logical_name" | cut -c1 | tr '[:lower:]' '[:upper:]')
    local rest_chars=$(echo "$logical_name" | cut -c2-)
    local capitalized="${first_char}${rest_chars}"
    local schema_name="${PUBLISHER_PREFIX}_${capitalized}"
    
    # Get display names
    local display_name=$(echo "$table_json" | jq -r '.displayName')
    local display_plural=$(echo "$table_json" | jq -r '.displayNamePlural')
    local description=$(echo "$table_json" | jq -r '.description')
    
    print_info "  LogicalName: $full_name"
    print_info "  SchemaName: $schema_name"
    
    # Build entity payload
    local entity_payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "LogicalName": "$full_name",
  "SchemaName": "$schema_name",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_plural}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "OwnershipType": "UserOwned",
  "IsCustomizable": {"Value": true},
  "HasActivities": true,
  "HasNotes": true,
  "Attributes": [{
    "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
    "AttributeType": "String",
    "AttributeTypeName": {"Value": "StringType"},
    "SchemaName": "${PUBLISHER_PREFIX}_${primary_schema}",
    "IsPrimaryName": true,
    "RequiredLevel": {"Value": "None"},
    "MaxLength": ${primary_max},
    "FormatName": {"Value": "Text"},
    "DisplayName": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "${primary_display}",
        "LanguageCode": 1033
      }]
    },
    "Description": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "${primary_desc}",
        "LanguageCode": 1033
      }]
    }
  }]
}
EOF
)
    
    result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/EntityDefinitions" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$entity_payload")
    
    http_code=$(echo "$result" | tail -n 1)
    body=$(echo "$result" | sed '$d')
    
    if [[ "$http_code" == "201" ]] || [[ "$http_code" == "204" ]] || [[ "$http_code" == "200" ]]; then
        print_success "Created: $full_name"
        sleep 3
        return 0
    else
        print_error "Failed to create $full_name - HTTP $http_code"
        echo "$body" | jq '.'
        return 1
    fi
}

# Function to create attribute
create_attribute() {
    local table_name=$1
    local attr_json=$2
    
    local attr_type=$(echo "$attr_json" | jq -r '.type')
    local logical_name=$(echo "$attr_json" | jq -r '.logicalName')
    local schema_name=$(echo "$attr_json" | jq -r '.schemaName')
    local display_name=$(echo "$attr_json" | jq -r '.displayName')
    local description=$(echo "$attr_json" | jq -r '.description')
    
    # Build attribute payload based on type
    local payload=""
    
    case "$attr_type" in
        "String")
            local max_length=$(echo "$attr_json" | jq -r '.maxLength // 100')
            local format=$(echo "$attr_json" | jq -r '.format // "Text"')
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
  "AttributeType": "String",
  "AttributeTypeName": {"Value": "StringType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "MaxLength": ${max_length},
  "Format": "${format}",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
        "Memo")
            local max_length=$(echo "$attr_json" | jq -r '.maxLength // 10000')
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.MemoAttributeMetadata",
  "AttributeType": "Memo",
  "AttributeTypeName": {"Value": "MemoType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "MaxLength": ${max_length},
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
        "DateTime")
            local format=$(echo "$attr_json" | jq -r '.format // "DateAndTime"')
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
  "AttributeType": "DateTime",
  "AttributeTypeName": {"Value": "DateTimeType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "Format": "${format}",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
        "Integer")
            local min_value=$(echo "$attr_json" | jq -r '.minValue // -2147483648')
            local max_value=$(echo "$attr_json" | jq -r '.maxValue // 2147483647')
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.IntegerAttributeMetadata",
  "AttributeType": "Integer",
  "AttributeTypeName": {"Value": "IntegerType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "MinValue": ${min_value},
  "MaxValue": ${max_value},
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
        "Boolean")
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.BooleanAttributeMetadata",
  "AttributeType": "Boolean",
  "AttributeTypeName": {"Value": "BooleanType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
        "Decimal")
            local precision=$(echo "$attr_json" | jq -r '.precision // 10')
            local scale=$(echo "$attr_json" | jq -r '.scale // 2')
            payload=$(cat <<EOF
{
  "@odata.type": "Microsoft.Dynamics.CRM.DecimalAttributeMetadata",
  "AttributeType": "Decimal",
  "AttributeTypeName": {"Value": "DecimalType"},
  "SchemaName": "${PUBLISHER_PREFIX}_${schema_name}",
  "LogicalName": "${PUBLISHER_PREFIX}_${logical_name}",
  "Precision": ${precision},
  "MinValue": -100000000000,
  "MaxValue": 100000000000,
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${display_name}",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "${description}",
      "LanguageCode": 1033
    }]
  },
  "RequiredLevel": {"Value": "None"},
  "IsCustomizable": {"Value": true}
}
EOF
)
            ;;
    esac
    
    if [[ -n "$payload" ]]; then
        result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/EntityDefinitions(LogicalName='$table_name')/Attributes" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d "$payload")
        
        http_code=$(echo "$result" | tail -n 1)
        
        if [[ "$http_code" == "201" ]] || [[ "$http_code" == "204" ]]; then
            print_success "  ✓ ${display_name}"
            sleep 1
            return 0
        else
            print_warning "  ⚠ ${display_name} (may already exist)"
            return 1
        fi
    fi
}

# Process each table
for ((i=0; i<$TABLE_COUNT; i++)); do
    table=$(echo "$SCHEMA" | jq ".tables[$i]")
    logical_name=$(echo "$table" | jq -r '.logicalName')
    full_name="${PUBLISHER_PREFIX}_${logical_name}"
    display_name=$(echo "$table" | jq -r '.displayName')
    
    echo ""
    print_info "Processing: $display_name ($full_name)"
    
    # Check if table exists
    if table_exists "$logical_name"; then
        print_warning "Table already exists, will update attributes"
    else
        # Create table
        if ! create_table "$table"; then
            print_error "Skipping attributes for $full_name due to table creation failure"
            continue
        fi
        
        # Wait for table provisioning
        print_info "Waiting for table provisioning..."
        sleep 10
    fi
    
    # Create attributes
    attr_count=$(echo "$table" | jq '.attributes | length')
    print_info "Creating $attr_count attributes..."
    
    for ((j=0; j<$attr_count; j++)); do
        attr=$(echo "$table" | jq ".attributes[$j]")
        create_attribute "$full_name" "$attr"
    done
done

# Publish all customizations
echo ""
print_info "Publishing all customizations..."

result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/PublishAllXml" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{}')

http_code=$(echo "$result" | tail -n 1)

if [[ "$http_code" == "200" ]] || [[ "$http_code" == "204" ]]; then
    print_success "Customizations published!"
else
    print_warning "Publish may have failed - HTTP $http_code"
fi

echo ""
print_success "Deployment complete!"
print_info "Created/Updated $TABLE_COUNT tables"