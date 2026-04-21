#!/bin/bash
# ============================================================
# Targeted Web Template Deployment
# Copies a specific web template from one Dataverse environment
# to another using the Web API — without touching site settings.
#
# Usage: ./deploy-web-template.sh <template-name> [target]
#   target: dev (default) | test
#
# Examples:
#   ./deploy-web-template.sh CS-Envelope-Editor          # → EC DEV
#   ./deploy-web-template.sh CS-Envelope-Editor dev      # → EC DEV
#   ./deploy-web-template.sh CS-Envelope-Editor test     # → EC TEST
#   ./deploy-web-template.sh "CS Template Editor" test   # → EC TEST
#
# .env file: root/.env (one level up)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [[ ! -f "$ENV_FILE" ]]; then echo "ERROR: .env not found at $ENV_FILE"; exit 1; fi

set -a; source "$ENV_FILE"; set +a

# ── Arguments ─────────────────────────────────────────────────
TEMPLATE_NAME="${1:-}"
TARGET_ENV="${2:-dev}"

if [[ -z "$TEMPLATE_NAME" ]]; then
  echo "Usage: $0 <template-name> [dev|test]"
  echo ""
  echo "Examples:"
  echo "  $0 CS-Envelope-Editor          # → EC DEV"
  echo "  $0 CS-Envelope-Editor test     # → EC TEST"
  echo "  $0 \"CS Template Editor\" test   # → EC TEST"
  exit 1
fi

# ── Source environment (goc-wetv14) ───────────────────────────
: "${DATAVERSE_ENVIRONMENT_URL:?DATAVERSE_ENVIRONMENT_URL not set}"
: "${DATAVERSE_TENANT_ID:?DATAVERSE_TENANT_ID not set}"
: "${DATAVERSE_CLIENT_ID:?DATAVERSE_CLIENT_ID not set}"
: "${DATAVERSE_CLIENT_SECRET:?DATAVERSE_CLIENT_SECRET not set}"

SRC_URL="$DATAVERSE_ENVIRONMENT_URL"

# ── Target environment (resolved from argument) ──────────────
: "${EC_TENANT_ID:?EC_TENANT_ID not set}"
: "${EC_CLIENT_ID:?EC_CLIENT_ID not set}"
: "${EC_CLIENT_SECRET:?EC_CLIENT_SECRET not set}"

TGT_TENANT="${EC_TENANT_ID//\"/}"
TGT_CLIENT="${EC_CLIENT_ID//\"/}"
TGT_SECRET="${EC_CLIENT_SECRET//\"/}"

case "$TARGET_ENV" in
  dev)  TGT_URL="https://dev-ec-esign-01.crm3.dynamics.com" ;;
  test) TGT_URL="https://test-ec-esign-01.crm3.dynamics.com" ;;
  *)
    echo "ERROR: Unknown target '$TARGET_ENV'. Use 'dev' or 'test'."
    exit 1
    ;;
esac

echo ""
echo "========================================"
echo " Targeted Web Template Deployment"
echo " Template: $TEMPLATE_NAME"
echo " Source:   $SRC_URL"
echo " Target:   $TGT_URL"
echo "========================================"

# ── 1. Authenticate to source ────────────────────────────────
echo ""
echo "[1/5] Authenticating to source ($SRC_URL)..."
SRC_TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$DATAVERSE_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$DATAVERSE_CLIENT_ID" \
  -d "client_secret=$DATAVERSE_CLIENT_SECRET" \
  -d "scope=$SRC_URL/.default" \
  -d "grant_type=client_credentials" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [[ ${#SRC_TOKEN} -lt 100 ]]; then echo "ERROR: Source auth failed"; exit 1; fi
echo "  ✓ Authenticated"

# ── 2. Find and download template from source ────────────────
echo ""
echo "[2/5] Fetching '$TEMPLATE_NAME' from source..."

# powerpagecomponent type 8 = web template source HTML
ENCODED_NAME=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${TEMPLATE_NAME}'))" 2>/dev/null)
SRC_FILTER="\$filter=name%20eq%20'${ENCODED_NAME}'%20and%20powerpagecomponenttype%20eq%208&\$select=name,content,powerpagecomponentid&\$top=1"
SRC_DATA=$(curl -s "${SRC_URL}/api/data/v9.2/powerpagecomponents?${SRC_FILTER}" \
  -H "Authorization: Bearer $SRC_TOKEN" \
  -H "Accept: application/json" \
  -H "OData-MaxVersion: 4.0")

SRC_ID=$(echo "$SRC_DATA" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
v = d.get('value',[])
if v:
    print(v[0].get('powerpagecomponentid',''))
else:
    print('')
" 2>/dev/null)

if [[ -z "$SRC_ID" ]]; then
  echo "  ERROR: Template '$TEMPLATE_NAME' (type 8) not found in source."
  exit 1
fi

# Save content to temp file
TEMP_CONTENT="/tmp/webtemplate_${TEMPLATE_NAME}_content.json"
echo "$SRC_DATA" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
content = d['value'][0]['content']
print(content)
" > "$TEMP_CONTENT" 2>/dev/null

CONTENT_SIZE=$(wc -c < "$TEMP_CONTENT" | tr -d ' ')
echo "  ✓ Found: ID=$SRC_ID  Content: ${CONTENT_SIZE} bytes"

# ── 3. Authenticate to target ────────────────────────────────
echo ""
echo "[3/5] Authenticating to target ($TGT_URL)..."
TGT_TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$TGT_TENANT/oauth2/v2.0/token" \
  -d "client_id=$TGT_CLIENT" \
  -d "client_secret=$TGT_SECRET" \
  -d "scope=$TGT_URL/.default" \
  -d "grant_type=client_credentials" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [[ ${#TGT_TOKEN} -lt 100 ]]; then echo "ERROR: Target auth failed"; exit 1; fi
echo "  ✓ Authenticated"

# ── 4. Find matching template in target ──────────────────────
echo ""
echo "[4/5] Finding '$TEMPLATE_NAME' in target..."

TGT_FILTER="\$filter=name%20eq%20'${ENCODED_NAME}'%20and%20powerpagecomponenttype%20eq%208&\$select=powerpagecomponentid&\$top=1"
TGT_ID=$(curl -s "${TGT_URL}/api/data/v9.2/powerpagecomponents?${TGT_FILTER}" \
  -H "Authorization: Bearer $TGT_TOKEN" \
  -H "Accept: application/json" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
v = d.get('value',[])
print(v[0]['powerpagecomponentid'] if v else '')
" 2>/dev/null)

if [[ -z "$TGT_ID" ]]; then
  echo "  ERROR: Template '$TEMPLATE_NAME' (type 8) not found in target."
  echo "  The template must already exist in the target environment."
  exit 1
fi
echo "  ✓ Found: ID=$TGT_ID"

# ── 5. Update target template content ────────────────────────
echo ""
echo "[5/5] Updating '$TEMPLATE_NAME' in target..."

# Build the PATCH payload — only update the content field
PATCH_PAYLOAD=$(python3 -c "
import json, sys
with open('$TEMP_CONTENT', 'r') as f:
    content = f.read().strip()
print(json.dumps({'content': content}))
" 2>/dev/null)

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
  "$TGT_URL/api/data/v9.2/powerpagecomponents($TGT_ID)" \
  -H "Authorization: Bearer $TGT_TOKEN" \
  -H "Content-Type: application/json" \
  -H "OData-MaxVersion: 4.0" \
  -H "If-Match: *" \
  -d "$PATCH_PAYLOAD")

if [[ "$HTTP_CODE" == "204" ]]; then
  echo "  ✓ Updated successfully (HTTP 204)"
else
  echo "  ERROR: Update failed (HTTP $HTTP_CODE)"
  exit 1
fi

# Cleanup
rm -f "$TEMP_CONTENT"

echo ""
echo "========================================"
echo " Deployment complete."
echo " '$TEMPLATE_NAME' copied from"
echo "   $SRC_URL → $TGT_URL"
echo " Site settings were NOT touched."
echo "========================================"
