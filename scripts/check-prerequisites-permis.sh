#!/bin/bash

#############################################################################
# Prerequisite Checker for Nintex Deployment
# Verifies you have necessary permissions
#############################################################################

CONFIG_FILE="$1"

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json"
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

JSON_CONFIG=$(cat "$CONFIG_FILE")
CLIENT_ID=$(echo "$JSON_CONFIG" | jq -r '.clientId')
TENANT_ID=$(echo "$JSON_CONFIG" | jq -r '.tenantId')
CRM_INSTANCE=$(echo "$JSON_CONFIG" | jq -r '.crmInstance')
CLIENT_SECRET=$(echo "$JSON_CONFIG" | jq -r '.clientSecret')

RESOURCE="https://${CRM_INSTANCE}.api.crm3.dynamics.com"
API_URL="${RESOURCE}/api/data/v9.2"

print_info "Checking prerequisites for Nintex deployment..."
echo ""

# Get token
print_info "Getting authentication token..."
response=$(curl -s -X POST "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" \
    -d "client_id=$CLIENT_ID" \
    -d "scope=${RESOURCE}/.default" \
    -d "grant_type=client_credentials" \
    -d "client_secret=$CLIENT_SECRET")

TOKEN=$(echo "$response" | jq -r '.access_token')

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
    print_error "Failed to get access token"
    echo "Check your config.json credentials"
    exit 1
fi

print_success "Authenticated successfully"

# Who am I?
print_info "Checking current user identity..."
whoami=$(curl -s "${API_URL}/WhoAmI" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

USER_ID=$(echo "$whoami" | jq -r '.UserId')

if [[ -z "$USER_ID" || "$USER_ID" == "null" ]]; then
    print_error "Could not determine user identity"
    exit 1
fi

# Get user details
user_details=$(curl -s "${API_URL}/systemusers($USER_ID)?\$select=fullname,domainname" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

USER_NAME=$(echo "$user_details" | jq -r '.fullname')
print_success "Authenticated as: $USER_NAME"

# Check security roles
print_info "Checking security roles..."
roles=$(curl -s "${API_URL}/systemusers($USER_ID)/systemuserroles_association?\$select=name" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/json")

role_count=$(echo "$roles" | jq '.value | length')
has_sysadmin=$(echo "$roles" | jq -r '.value[] | select(.name == "System Administrator") | .name')

echo ""
print_info "Current roles assigned:"
echo "$roles" | jq -r '.value[] | "  • \(.name)"'

echo ""

if [[ -n "$has_sysadmin" ]]; then
    print_success "You have System Administrator role - READY TO DEPLOY!"
    echo ""
    print_info "You can now run:"
    echo "  ./deploy-nintex-all.sh $CONFIG_FILE full"
    echo ""
    exit 0
else
    print_error "Missing System Administrator role"
    echo ""
    print_warning "You need System Administrator to create tables"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "HOW TO FIX:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Go to Power Platform Admin Center:"
    echo "   https://admin.powerplatform.microsoft.com/"
    echo ""
    echo "2. Navigate to:"
    echo "   Environments → ${CRM_INSTANCE}"
    echo "   → Settings → Users + permissions → Application users"
    echo ""
    echo "3. Find your app user:"
    echo "   Name: $USER_NAME"
    echo "   User ID: $USER_ID"
    echo ""
    echo "4. Click on the user → Manage roles"
    echo ""
    echo "5. Check 'System Administrator'"
    echo ""
    echo "6. Save"
    echo ""
    echo "7. Re-run this check:"
    echo "   ./check-prerequisites.sh $CONFIG_FILE"
    echo ""
    echo "8. Then deploy:"
    echo "   ./deploy-nintex-all.sh $CONFIG_FILE full"
    echo ""
    echo "9. After deployment, remove System Administrator:"
    echo "   ./assign-role-to-user.sh $CONFIG_FILE"
    echo "   (This assigns the minimal Nintex role instead)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    exit 1
fi
