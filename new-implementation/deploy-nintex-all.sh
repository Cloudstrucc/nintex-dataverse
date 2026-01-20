#!/bin/bash

#############################################################################
# Nintex Dataverse Integration - Master Deployment Script
# Orchestrates deployment of all tables and security roles
#############################################################################

set -e  # Exit on error

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_header() { 
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

CONFIG_FILE="$1"
MODE="${2:-full}"  # full, tables-only, security-only

if [[ -z "$CONFIG_FILE" ]]; then
    echo "Usage: $0 config.json [mode]"
    echo ""
    echo "Modes:"
    echo "  full (default)    - Deploy all tables and security"
    echo "  tables-only       - Deploy tables only"
    echo "  security-only     - Deploy security role only"
    echo ""
    echo "Example:"
    echo "  $0 config.json full"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    print_error "Config file not found: $CONFIG_FILE"
    exit 1
fi

# Read publisher prefix from config
PUBLISHER_PREFIX=$(cat "$CONFIG_FILE" | jq -r '.publisherPrefix // "cs"')

print_header "🚀 Nintex Dataverse Integration Deployment"
print_info "Config: $CONFIG_FILE"
print_info "Mode: $MODE"
print_info "Publisher Prefix: $PUBLISHER_PREFIX"
echo ""

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check required files
REQUIRED_FILES=(
    "deploy-tables-engine.sh"
    "nintex-tables-schema.json"
    "create-security-roles.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
        print_error "Required file not found: $file"
        exit 1
    fi
done

print_success "All required files present"

# Make scripts executable
chmod +x "$SCRIPT_DIR/deploy-tables-engine.sh"
chmod +x "$SCRIPT_DIR/create-security-roles.sh"

#############################################################################
# STEP 1: Deploy Tables
#############################################################################

if [[ "$MODE" == "full" ]] || [[ "$MODE" == "tables-only" ]]; then
    print_header "📊 Step 1: Deploying Nintex Tables"
    
    "$SCRIPT_DIR/deploy-tables-engine.sh" \
        "$CONFIG_FILE" \
        "$SCRIPT_DIR/nintex-tables-schema.json" \
        "$PUBLISHER_PREFIX"
    
    if [[ $? -eq 0 ]]; then
        print_success "Tables deployed successfully!"
    else
        print_error "Table deployment failed!"
        exit 1
    fi
    
    # Wait for provisioning
    print_info "Waiting 30 seconds for Dataverse to generate privileges..."
    sleep 30
fi

#############################################################################
# STEP 2: Create Security Roles
#############################################################################

if [[ "$MODE" == "full" ]] || [[ "$MODE" == "security-only" ]]; then
    print_header "🔐 Step 2: Creating Security Roles"
    
    "$SCRIPT_DIR/create-security-roles.sh" \
        "$CONFIG_FILE" \
        "$PUBLISHER_PREFIX"
    
    if [[ $? -eq 0 ]]; then
        print_success "Security roles created successfully!"
    else
        print_warning "Security role creation had issues (not critical)"
    fi
fi

#############################################################################
# FINAL SUMMARY
#############################################################################

print_header "✨ Deployment Complete!"

CRM_INSTANCE=$(cat "$CONFIG_FILE" | jq -r '.crmInstance')

echo ""
print_info "📋 Summary:"
echo ""

if [[ "$MODE" == "full" ]] || [[ "$MODE" == "tables-only" ]]; then
    print_success "Tables Deployed:"
    echo "  • ${PUBLISHER_PREFIX}_envelope - Signature request containers"
    echo "  • ${PUBLISHER_PREFIX}_document - Documents within envelopes"
    echo "  • ${PUBLISHER_PREFIX}_signer - Recipients and their status"
    echo "  • ${PUBLISHER_PREFIX}_field - Signature fields and JotBlocks"
    echo "  • ${PUBLISHER_PREFIX}_template - Reusable templates"
    echo "  • ${PUBLISHER_PREFIX}_authtoken - API authentication tokens"
    echo "  • ${PUBLISHER_PREFIX}_webhook - Event notifications"
    echo "  • ${PUBLISHER_PREFIX}_apirequest - API request logs"
    echo ""
fi

if [[ "$MODE" == "full" ]] || [[ "$MODE" == "security-only" ]]; then
    ROLE_NAME=$(cat "$CONFIG_FILE" | jq -r '.roleName // "Nintex API User"')
    print_success "Security Role Created:"
    echo "  • Role: $ROLE_NAME"
    echo "  • Privileges: Full CRUD on all Nintex tables"
    echo ""
fi

print_warning "⚠️  Next Steps:"
echo ""
echo "1. Publish customizations (if not auto-published):"
echo "   Power Apps → Solutions → Default Solution → Publish All"
echo ""
echo "2. Assign security role to your API user:"
echo "   Run: ./assign-role-to-user.sh $CONFIG_FILE"
echo ""
echo "3. Create forms for tables (optional):"
echo "   Power Apps → Tables → [Table] → Forms → + New form"
echo ""
echo "4. Test your middleware API:"
echo "   • Create an envelope via Dataverse OData API"
echo "   • Verify it calls Nintex API"
echo "   • Check webhook responses"
echo ""

print_info "📚 Access your tables at:"
echo "  https://${CRM_INSTANCE}.crm3.dynamics.com/main.aspx"
echo ""

print_success "🎉 Deployment successful!"
