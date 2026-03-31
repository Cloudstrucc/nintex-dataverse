#!/usr/bin/env bash
# Nintex AssureSign API v3.7 - Endpoint Test Script
# Reads credentials from .env file in the same directory
# Usage: ./test-nintex-api.sh [template_id]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  echo "Required variables: NINTEX_API_USERNAME, NINTEX_API_KEY, NINTEX_CONTEXT_USERNAME, NINTEX_AUTH_URL, NINTEX_API_BASE_URL"
  exit 1
fi

source "$ENV_FILE"

for var in NINTEX_API_USERNAME NINTEX_API_KEY NINTEX_CONTEXT_USERNAME NINTEX_AUTH_URL NINTEX_API_BASE_URL; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: $var is not set in .env"
    exit 1
  fi
done

TEMPLATE_ID="${1:-}"
PASS=0
FAIL=0

log_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
log_fail() { echo "  FAIL: $1"; echo "        $2"; FAIL=$((FAIL + 1)); }

echo "============================================"
echo "Nintex AssureSign API v3.7 - Endpoint Tests"
echo "============================================"
echo "Auth URL:  $NINTEX_AUTH_URL"
echo "API URL:   $NINTEX_API_BASE_URL"
echo "User:      $NINTEX_CONTEXT_USERNAME"
echo ""

# ── 1. Authenticate ──────────────────────────────────────────────────
echo "── 1. Authentication ──"
AUTH_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$NINTEX_AUTH_URL/authentication/apiUser" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "{\"request\":{\"apiUsername\":\"$NINTEX_API_USERNAME\",\"key\":\"$NINTEX_API_KEY\",\"contextUsername\":\"$NINTEX_CONTEXT_USERNAME\",\"sessionLengthInMinutes\":1440}}")

HTTP_CODE=$(echo "$AUTH_RESPONSE" | tail -1)
AUTH_BODY=$(echo "$AUTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  TOKEN=$(echo "$AUTH_BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['token'])" 2>/dev/null)
  if [ -n "$TOKEN" ]; then
    log_pass "POST /authentication/apiUser (HTTP $HTTP_CODE, token received)"
  else
    log_fail "POST /authentication/apiUser" "HTTP 200 but no token in response"
    exit 1
  fi
else
  log_fail "POST /authentication/apiUser" "HTTP $HTTP_CODE - $AUTH_BODY"
  exit 1
fi

AUTH_HEADERS=(
  -H "Authorization: bearer $TOKEN"
  -H "X-AS-UserContext: $NINTEX_CONTEXT_USERNAME"
  -H "Accept: application/json"
)

# ── 2. List Templates ────────────────────────────────────────────────
echo ""
echo "── 2. List Templates ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/templates" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  COUNT=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']['templates']))" 2>/dev/null || echo "0")
  log_pass "GET /templates (HTTP $HTTP_CODE, $COUNT templates)"

  if [ -z "$TEMPLATE_ID" ] && [ "$COUNT" -gt 0 ]; then
    TEMPLATE_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['templates'][0]['templateID'])" 2>/dev/null)
    TEMPLATE_NAME=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['templates'][0]['name'])" 2>/dev/null)
    echo "  Using template: $TEMPLATE_NAME ($TEMPLATE_ID)"
  fi
else
  log_fail "GET /templates" "HTTP $HTTP_CODE - $BODY"
fi

if [ -z "$TEMPLATE_ID" ]; then
  echo ""
  echo "ERROR: No template available. Pass a template ID as argument: ./test-nintex-api.sh <template_id>"
  exit 1
fi

# ── 3. Get Template Details ──────────────────────────────────────────
echo ""
echo "── 3. Get Template Details ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/templates/$TEMPLATE_ID" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  SIGNERS=$(echo "$BODY" | python3 -c "import sys,json; s=json.load(sys.stdin)['result']['content']['signers']; print(', '.join([x['label'] for x in s]))" 2>/dev/null || echo "unknown")
  log_pass "GET /templates/{id} (HTTP $HTTP_CODE, signers: $SIGNERS)"
else
  log_fail "GET /templates/{id}" "HTTP $HTTP_CODE - $BODY"
fi

# ── 4. Submit Envelope ───────────────────────────────────────────────
echo ""
echo "── 4. Submit Envelope ──"
RESP=$(curl -s -w "\n%{http_code}" -X POST "$NINTEX_API_BASE_URL/submit" \
  "${AUTH_HEADERS[@]}" \
  -H "Content-Type: application/json" \
  -d "{\"request\":{\"templates\":[{\"templateID\":\"$TEMPLATE_ID\",\"values\":[{\"name\":\"Signer 1 Name\",\"value\":\"API Test\"},{\"name\":\"Signer 1 Email\",\"value\":\"$NINTEX_CONTEXT_USERNAME\"}]}]}}")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  ENVELOPE_ID=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['envelopeID'])" 2>/dev/null)
  AUTH_TOKEN=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['authToken'])" 2>/dev/null)
  log_pass "POST /submit (HTTP $HTTP_CODE, envelopeID: $ENVELOPE_ID)"
else
  log_fail "POST /submit" "HTTP $HTTP_CODE - $BODY"
  echo ""
  echo "Cannot continue without an envelope. Exiting."
  echo "Results: $PASS passed, $FAIL failed"
  exit 1
fi

sleep 3

# ── 5. Get Envelope Status ───────────────────────────────────────────
echo ""
echo "── 5. Get Envelope Status ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/envelopes/$ENVELOPE_ID/status" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['status'])" 2>/dev/null)
  log_pass "GET /envelopes/{id}/status (HTTP $HTTP_CODE, status: $STATUS)"
else
  log_fail "GET /envelopes/{id}/status" "HTTP $HTTP_CODE - $BODY"
fi

# ── 6. Get Signing Links ─────────────────────────────────────────────
echo ""
echo "── 6. Get Signing Links ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/envelope/$ENVELOPE_ID/signingLinks" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  LINKS=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']['signingLinks']))" 2>/dev/null || echo "0")
  log_pass "GET /envelope/{id}/signingLinks (HTTP $HTTP_CODE, $LINKS links)"
else
  log_fail "GET /envelope/{id}/signingLinks" "HTTP $HTTP_CODE - $BODY"
fi

# ── 7. Get Envelope History ──────────────────────────────────────────
echo ""
echo "── 7. Get Envelope History ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/envelopes/$ENVELOPE_ID/history" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  EVENTS=$(echo "$BODY" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['result']['envelopeHistoryEvents']))" 2>/dev/null || echo "0")
  log_pass "GET /envelopes/{id}/history (HTTP $HTTP_CODE, $EVENTS events)"
else
  log_fail "GET /envelopes/{id}/history" "HTTP $HTTP_CODE - $BODY"
fi

# ── 8. Cancel Envelope ───────────────────────────────────────────────
echo ""
echo "── 8. Cancel Envelope ──"
RESP=$(curl -s -w "\n%{http_code}" -X PUT "$NINTEX_API_BASE_URL/envelopes/$ENVELOPE_ID/cancel" \
  "${AUTH_HEADERS[@]}" \
  -H "Content-Type: application/json" \
  -d "{\"request\":{\"authToken\":\"$AUTH_TOKEN\",\"remarks\":\"API test cancellation\"}}")

HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  log_pass "PUT /envelopes/{id}/cancel (HTTP $HTTP_CODE)"
else
  log_fail "PUT /envelopes/{id}/cancel" "HTTP $HTTP_CODE - $BODY"
fi

# ── 9. Verify Cancelled ─────────────────────────────────────────────
echo ""
echo "── 9. Verify Cancelled Status ──"
RESP=$(curl -s -w "\n%{http_code}" "$NINTEX_API_BASE_URL/envelopes/$ENVELOPE_ID/status" "${AUTH_HEADERS[@]}")
HTTP_CODE=$(echo "$RESP" | tail -1)
BODY=$(echo "$RESP" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
  STATUS=$(echo "$BODY" | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['status'])" 2>/dev/null)
  if [ "$STATUS" = "cancelled" ]; then
    log_pass "Status confirmed: $STATUS"
  else
    log_fail "Expected 'cancelled'" "Got: $STATUS"
  fi
else
  log_fail "GET /envelopes/{id}/status" "HTTP $HTTP_CODE"
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "Results: $PASS passed, $FAIL failed"
echo "============================================"
echo ""
echo "API Path Reference:"
echo "  POST  /authentication/apiUser          - Auth (request wrapper)"
echo "  GET   /templates                       - List templates"
echo "  GET   /templates/{id}                  - Template details"
echo "  POST  /submit                          - Submit envelope (request.templates[])"
echo "  GET   /envelopes/{id}/status           - Envelope status (plural)"
echo "  GET   /envelope/{id}/signingLinks      - Signing links (SINGULAR)"
echo "  GET   /envelopes/{id}/history          - Envelope history (plural)"
echo "  PUT   /envelopes/{id}/cancel           - Cancel (request.authToken + request.remarks)"
echo ""
echo "NOTE: /envelope/ (singular) for signingLinks, /envelopes/ (plural) for all others"

exit $FAIL
