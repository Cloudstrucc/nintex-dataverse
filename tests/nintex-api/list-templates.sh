#!/bin/bash
# ============================================================
# Nintex AssureSign — List All Templates
# Authenticates using credentials from root/.env
# Outputs JSON + formatted table sorted by last modified
# Usage: ./list-templates.sh
# ============================================================

set -euo pipefail

# ── Resolve .env ──────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── Required variables ────────────────────────────────────────
: "${NINTEX_API_USERNAME:?NINTEX_API_USERNAME is not set in .env}"
: "${NINTEX_API_KEY:?NINTEX_API_KEY is not set in .env}"
: "${NINTEX_CONTEXT_USERNAME:?NINTEX_CONTEXT_USERNAME is not set in .env}"
: "${NINTEX_AUTH_URL:?NINTEX_AUTH_URL is not set in .env}"
: "${NINTEX_API_BASE_URL:?NINTEX_API_BASE_URL is not set in .env}"

# Allow override via command-line arg: ./list-templates.sh [base_url]
if [[ -n "${1:-}" ]]; then
  NINTEX_API_BASE_URL="$1"
  echo "  (Override) API URL: $NINTEX_API_BASE_URL"
fi

# ── Authenticate ──────────────────────────────────────────────
echo "Authenticating to Nintex AssureSign..."
echo "  Auth URL: $NINTEX_AUTH_URL"
echo "  API URL:  $NINTEX_API_BASE_URL"
echo "  User:     $NINTEX_CONTEXT_USERNAME"
echo ""

TOKEN=$(curl -s -X POST "$NINTEX_AUTH_URL/authentication/apiUser" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{
    \"request\": {
      \"apiUsername\": \"$NINTEX_API_USERNAME\",
      \"key\": \"$NINTEX_API_KEY\",
      \"contextUsername\": \"$NINTEX_CONTEXT_USERNAME\",
      \"sessionLengthInMinutes\": 60
    }
  }" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['token'])" 2>/dev/null)

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Authentication failed. Check credentials in .env"
  exit 1
fi
echo "✓ Authenticated"
echo ""

# ── Fetch templates ───────────────────────────────────────────
echo "Fetching templates..."
RESPONSE=$(curl -s "$NINTEX_API_BASE_URL/templates" \
  -H "Authorization: bearer $TOKEN" \
  -H "X-AS-UserContext: $NINTEX_CONTEXT_USERNAME" \
  -H "Accept: application/json")

# ── Output JSON ───────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo " RAW JSON RESPONSE"
echo "════════════════════════════════════════════════════════════"
echo "$RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$RESPONSE"

# ── Output formatted table ────────────────────────────────────
echo ""
echo "════════════════════════════════════════════════════════════"
echo " TEMPLATES — sorted by Last Modified (newest first)"
echo "════════════════════════════════════════════════════════════"
echo ""

echo "$RESPONSE" | python3 -c "
import sys, json

data = json.load(sys.stdin)
templates = data.get('result', {}).get('templates', [])

if not templates:
    print('  No templates found.')
    sys.exit(0)

# Sort by 'updated' descending (newest first)
templates.sort(key=lambda t: t.get('updated', ''), reverse=True)

# Column widths
name_w = max(max(len(t.get('name', '')) for t in templates), 4)
name_w = min(name_w, 40)  # cap at 40

# Header
hdr = f\"{'Name':<{name_w}}  {'Template ID':<38}  {'Created':<20}  {'Last Modified':<20}\"
sep = '─' * len(hdr)
print(f'  {hdr}')
print(f'  {sep}')

# Rows
for t in templates:
    name = t.get('name', 'Untitled')[:name_w]
    tid = t.get('templateID', '—')
    created = t.get('created', '—')[:19].replace('T', ' ')
    updated = t.get('updated', '—')[:19].replace('T', ' ')
    print(f'  {name:<{name_w}}  {tid:<38}  {created:<20}  {updated:<20}')

print()
print(f'  Total: {len(templates)} templates')
" 2>/dev/null

echo ""
