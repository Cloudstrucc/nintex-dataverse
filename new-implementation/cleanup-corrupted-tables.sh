#!/bin/bash

#############################################################################
# Cleanup Corrupted Nintex Tables
# Deletes tables with malformed names
#############################################################################

CONFIG_FILE="$1"
PUBLISHER_PREFIX="$2"

if [[ -z "$CONFIG_FILE" ]] || [[ -z "$PUBLISHER_PREFIX" ]]; then
    echo "Usage: $0 config.json publisher_prefix"
    echo ""
    echo "Example:"
    echo "  $0 config.json cs"
    exit 1
fi

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

print_warning "⚠️  TABLE CLEANUP UTILITY ⚠️"
echo ""
print_info "This will DELETE tables with corrupted names"
echo ""

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

# Get all custom entities with our prefix
print_info "Searching for tables with prefix: ${PUBLISHER_PREFIX}_"

# Query without filter first, then filter locally
entities_result=$(curl -s "${API_URL}/EntityDefinitions?\$select=LogicalName,DisplayName,MetadataId" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

# Filter for our prefix using jq
filtered_entities=$(echo "$entities_result" | jq --arg prefix "${PUBLISHER_PREFIX}_" '{value: [.value[] | select(.LogicalName | startswith($prefix))]}')

# List all found tables
echo ""
print_info "Found tables:"
echo "$filtered_entities" | jq -r '.value[] | "  • \(.LogicalName) - \(.DisplayName.UserLocalizedLabel.Label // .DisplayName.LocalizedLabels[0].Label // "No name")"'

# Define corrupted patterns to delete
CORRUPTED_TABLES=(
    "${PUBLISHER_PREFIX}_uapirequestpirequest"
    "${PUBLISHER_PREFIX}_uauthtokenuthtoken"
    "${PUBLISHER_PREFIX}_udocumentocument"
    "${PUBLISHER_PREFIX}_uenvelopenenvelope"
    "${PUBLISHER_PREFIX}_ufieldield"
    "${PUBLISHER_PREFIX}_usignerigner"
    "${PUBLISHER_PREFIX}_utemplateemplate"
    "${PUBLISHER_PREFIX}_uwebhookebhook"
)

echo ""
print_warning "The following corrupted tables will be DELETED:"
for table in "${CORRUPTED_TABLES[@]}"; do
    # Check if table exists
    exists=$(echo "$filtered_entities" | jq -r --arg name "$table" '.value[] | select(.LogicalName == $name) | .LogicalName')
    if [[ -n "$exists" ]]; then
        echo "  • $table"
    fi
done

echo ""
read -p "Are you sure you want to DELETE these tables? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    print_info "Cleanup cancelled"
    exit 0
fi

echo ""
print_info "Starting cleanup..."

# Delete each corrupted table
for table in "${CORRUPTED_TABLES[@]}"; do
    # Get metadata ID
    metadata_id=$(echo "$filtered_entities" | jq -r --arg name "$table" '.value[] | select(.LogicalName == $name) | .MetadataId')
    
    if [[ -n "$metadata_id" && "$metadata_id" != "null" ]]; then
        print_info "Deleting: $table"
        
        result=$(curl -s -w "\n%{http_code}" -X DELETE "${API_URL}/EntityDefinitions($metadata_id)" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/json")
        
        http_code=$(echo "$result" | tail -n 1)
        
        if [[ "$http_code" == "204" ]] || [[ "$http_code" == "200" ]]; then
            print_success "  ✓ Deleted: $table"
        else
            print_error "  ✗ Failed to delete: $table (HTTP $http_code)"
        fi
        
        sleep 1
    fi
done

# Publish deletions
echo ""
print_info "Publishing deletions..."

publish_result=$(curl -s -w "\n%{http_code}" -X POST "${API_URL}/PublishAllXml" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d '{}')

http_code=$(echo "$publish_result" | tail -n 1)

if [[ "$http_code" == "200" ]] || [[ "$http_code" == "204" ]]; then
    print_success "Changes published!"
else
    print_warning "Publish may have failed - HTTP $http_code"
fi

echo ""
print_success "Cleanup complete!"
print_info "You can now redeploy tables with correct names"
echo ""
print_info "Run: ./deploy-nintex-all.sh $CONFIG_FILE tables-only"