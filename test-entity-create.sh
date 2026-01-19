#!/bin/bash

# Final attempt - using exact Microsoft format
CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
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

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

# Get token
echo "Getting token..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')
echo "Token: ${TOKEN:0:50}..."

echo ""
echo "================================================================"
echo "RECOMMENDATION: Create the table manually via Power Apps UI"
echo "================================================================"
echo ""
echo "The Dataverse Web API has inconsistent requirements for entity creation."
echo "It's much simpler to create the table via the UI, then use this script"
echo "to add all the custom fields."
echo ""
echo "Steps:"
echo "1. Go to https://make.powerapps.com"
echo "2. Tables → + New table → Add columns and data"
echo "3. Name: Digital Signature"
echo "4. Primary column: Name"
echo "5. Save"
echo "6. Then run this script to add all custom fields: ./deploy-nintex-activity.sh config.json"
echo ""
echo "Press Enter to try automated creation anyway, or Ctrl+C to cancel..."
read

echo ""
echo "Attempting automated creation with HasAttributes..."

# Try using HasAttributes property
payload='{
  "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata",
  "LogicalName": "'${PUBLISHER_PREFIX}'_digitalsignature",
  "SchemaName": "'${PUBLISHER_PREFIX}'_DigitalSignature",
  "DisplayName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Digital Signature",
      "LanguageCode": 1033
    }]
  },
  "DisplayCollectionName": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Digital Signatures",
      "LanguageCode": 1033
    }]
  },
  "Description": {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    "LocalizedLabels": [{
      "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
      "Label": "Table for managing digital signature requests via Nintex AssureSign API",
      "LanguageCode": 1033
    }]
  },
  "OwnershipType": "UserOwned",
  "IsCustomizable": {"Value": true},
  "HasActivities": true,
  "HasNotes": true,
  "HasAttributes": true,
  "Attributes": [{
    "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata",
    "AttributeType": "String",
    "AttributeTypeName": {"Value": "StringType"},
    "SchemaName": "'${PUBLISHER_PREFIX}'_Name",
    "IsPrimaryName": true,
    "RequiredLevel": {"Value": "None"},
    "MaxLength": 200,
    "FormatName": {"Value": "Text"},
    "DisplayName": {
      "@odata.type": "Microsoft.Dynamics.CRM.Label",
      "LocalizedLabels": [{
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        "Label": "Name",
        "LanguageCode": 1033
      }]
    }
  }]
}'

response=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/EntityDefinitions" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "OData-MaxVersion: 4.0" \
    -H "OData-Version: 4.0" \
    -H "Accept: application/json" \
    -d "$payload")

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"

if [[ "$http_code" == "201" ]] || [[ "$http_code" == "204" ]]; then
    echo ""
    echo "✅ SUCCESS! Table created!"
    echo "$body" | jq '.'
else
    echo ""
    echo "❌ FAILED (as expected)"
    echo "$body" | jq '.' 2>/dev/null || echo "$body"
    echo ""
    echo "================================================================"
    echo "RECOMMENDED PATH: Manual Creation + Automated Fields"
    echo "================================================================"
    echo ""
    echo "Please create the table manually:"
    echo "1. https://make.powerapps.com → Tables → + New table"
    echo "2. Name: Digital Signature"  
    echo "3. Primary column name: Name"
    echo "4. Save"
    echo ""
    echo "Then run to add all fields automatically:"
    echo "./deploy-nintex-activity.sh config.json schema"
    echo ""
    echo "The script will detect the existing table and add all 10 custom fields."
fi