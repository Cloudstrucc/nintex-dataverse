#!/bin/bash
# ============================================================
# Generic Dataverse Record Deployment
# Copies specific records or entire tables from one Dataverse
# environment to another using the Web API.
#
# Usage:
#   ./deploy-records.sh --config .env-deploy
#   ./deploy-records.sh   (interactive — prompts for all values)
#
# Modes:
#   1) Deploy specific records by GUID(s)
#   2) Deploy all records from a table (or multiple tables)
#
# ============================================================

set -euo pipefail

# ── Colors ────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

# ── Parse --config argument ───────────────────────────────────
CONFIG_FILE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config|-c) CONFIG_FILE="$2"; shift 2 ;;
    *) echo -e "${RED}Unknown argument: $1${NC}"; exit 1 ;;
  esac
done

# ── Collect environment credentials ───────────────────────────
if [[ -n "$CONFIG_FILE" ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${RED}ERROR: Config file not found: $CONFIG_FILE${NC}"
    exit 1
  fi
  echo -e "${BLUE}Loading config from: $CONFIG_FILE${NC}"
  set -a; source "$CONFIG_FILE"; set +a

  # Strip quotes
  SRC_TENANT_ID="${SRC_TENANT_ID//\"/}"
  SRC_CLIENT_ID="${SRC_CLIENT_ID//\"/}"
  SRC_CLIENT_SECRET="${SRC_CLIENT_SECRET//\"/}"
  SRC_ENVIRONMENT_URL="${SRC_ENVIRONMENT_URL//\"/}"
  TGT_TENANT_ID="${TGT_TENANT_ID//\"/}"
  TGT_CLIENT_ID="${TGT_CLIENT_ID//\"/}"
  TGT_CLIENT_SECRET="${TGT_CLIENT_SECRET//\"/}"
  TGT_ENVIRONMENT_URL="${TGT_ENVIRONMENT_URL//\"/}"
else
  echo ""
  echo -e "${BLUE}No config file provided. Enter credentials manually.${NC}"
  echo ""
  echo -e "${YELLOW}── Source Environment ──${NC}"
  read -rp "  Tenant ID: " SRC_TENANT_ID
  read -rp "  Client ID: " SRC_CLIENT_ID
  read -rsp "  Client Secret: " SRC_CLIENT_SECRET; echo ""
  read -rp "  Environment URL: " SRC_ENVIRONMENT_URL

  echo ""
  echo -e "${YELLOW}── Target Environment ──${NC}"
  read -rp "  Tenant ID: " TGT_TENANT_ID
  read -rp "  Client ID: " TGT_CLIENT_ID
  read -rsp "  Client Secret: " TGT_CLIENT_SECRET; echo ""
  read -rp "  Environment URL: " TGT_ENVIRONMENT_URL
fi

# ── Validate required vars ────────────────────────────────────
for var in SRC_TENANT_ID SRC_CLIENT_ID SRC_CLIENT_SECRET SRC_ENVIRONMENT_URL \
           TGT_TENANT_ID TGT_CLIENT_ID TGT_CLIENT_SECRET TGT_ENVIRONMENT_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo -e "${RED}ERROR: $var is not set.${NC}"
    exit 1
  fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Source: $SRC_ENVIRONMENT_URL${NC}"
echo -e "${BLUE} Target: $TGT_ENVIRONMENT_URL${NC}"
echo -e "${BLUE}========================================${NC}"

# ── Authenticate ──────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Authenticating...${NC}"

SRC_TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$SRC_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$SRC_CLIENT_ID" \
  -d "client_secret=$SRC_CLIENT_SECRET" \
  -d "scope=$SRC_ENVIRONMENT_URL/.default" \
  -d "grant_type=client_credentials" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [[ ${#SRC_TOKEN} -lt 100 ]]; then echo -e "${RED}ERROR: Source auth failed.${NC}"; exit 1; fi
echo -e "  Source: ${GREEN}✓${NC}"

TGT_TOKEN=$(curl -s -X POST "https://login.microsoftonline.com/$TGT_TENANT_ID/oauth2/v2.0/token" \
  -d "client_id=$TGT_CLIENT_ID" \
  -d "client_secret=$TGT_CLIENT_SECRET" \
  -d "scope=$TGT_ENVIRONMENT_URL/.default" \
  -d "grant_type=client_credentials" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))" 2>/dev/null)

if [[ ${#TGT_TOKEN} -lt 100 ]]; then echo -e "${RED}ERROR: Target auth failed.${NC}"; exit 1; fi
echo -e "  Target: ${GREEN}✓${NC}"

# ── Choose deployment mode ────────────────────────────────────
echo ""
echo "Select deployment mode:"
echo "  1) Deploy specific records by GUID(s)"
echo "  2) Deploy all records from table(s)"
echo ""
read -rp "Enter 1 or 2: " MODE

if [[ "$MODE" == "1" ]]; then
  # ── Mode 1: Specific GUIDs ─────────────────────────────────
  read -rp "Table name (e.g. powerpagecomponents, mspp_webtemplates): " TABLE_NAME
  echo "Enter record GUIDs (comma-separated):"
  read -rp "  GUIDs: " GUID_INPUT
  IFS=',' read -ra GUIDS <<< "$GUID_INPUT"

  # Trim whitespace
  for i in "${!GUIDS[@]}"; do GUIDS[$i]=$(echo "${GUIDS[$i]}" | xargs); done

  SELECT_COLS="$TABLE_NAME"
  # Detect primary key and name column based on table
  case "$TABLE_NAME" in
    powerpagecomponents) PK="powerpagecomponentid"; NAME_COL="name"; EXTRA_COLS="powerpagecomponenttype" ;;
    mspp_webtemplates)   PK="mspp_webtemplateid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
    mspp_contentsnippets) PK="mspp_contentsnippetid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
    cs_templates)        PK="cs_templateid"; NAME_COL="cs_name"; EXTRA_COLS="" ;;
    cs_envelopes)        PK="cs_envelopeid"; NAME_COL="cs_name"; EXTRA_COLS="" ;;
    *) PK="${TABLE_NAME%s}id"; NAME_COL="name"; EXTRA_COLS=""
       echo -e "${YELLOW}  Warning: guessing PK=$PK, name=$NAME_COL for table $TABLE_NAME${NC}" ;;
  esac

  # Query source records and check target
  echo ""
  echo -e "${YELLOW}Querying records...${NC}"
  echo ""

  RECORDS_JSON="["
  FIRST=true
  for GUID in "${GUIDS[@]}"; do
    # Get from source
    SRC_RECORD=$(curl -s "$SRC_ENVIRONMENT_URL/api/data/v9.2/${TABLE_NAME}($GUID)?\$select=$NAME_COL,modifiedon${EXTRA_COLS:+,$EXTRA_COLS}" \
      -H "Authorization: Bearer $SRC_TOKEN" -H "Accept: application/json" 2>/dev/null)
    SRC_NAME=$(echo "$SRC_RECORD" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('$NAME_COL','?'))" 2>/dev/null)
    SRC_MOD=$(echo "$SRC_RECORD" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('modifiedon','?')[:19].replace('T',' '))" 2>/dev/null)

    # Check if exists in target
    TGT_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$TGT_ENVIRONMENT_URL/api/data/v9.2/${TABLE_NAME}($GUID)" \
      -H "Authorization: Bearer $TGT_TOKEN" -H "Accept: application/json" 2>/dev/null)
    if [[ "$TGT_CHECK" == "200" ]]; then ACTION="Update"; else ACTION="Create"; fi

    if [[ "$FIRST" == true ]]; then FIRST=false; else RECORDS_JSON+=","; fi
    RECORDS_JSON+="{\"guid\":\"$GUID\",\"name\":\"$SRC_NAME\",\"modified\":\"$SRC_MOD\",\"action\":\"$ACTION\"}"
  done
  RECORDS_JSON+="]"

elif [[ "$MODE" == "2" ]]; then
  # ── Mode 2: Entire tables ──────────────────────────────────
  echo "Enter table name(s) (comma-separated, e.g. powerpagecomponents,mspp_webtemplates):"
  read -rp "  Tables: " TABLE_INPUT
  IFS=',' read -ra TABLES <<< "$TABLE_INPUT"

  echo ""
  echo "Optional: filter by website ID? (leave blank to skip)"
  read -rp "  Website ID: " WEBSITE_FILTER

  GUIDS=()
  TABLE_NAME="${TABLES[0]}" # for PK detection

  case "$TABLE_NAME" in
    powerpagecomponents) PK="powerpagecomponentid"; NAME_COL="name"; EXTRA_COLS="powerpagecomponenttype" ;;
    mspp_webtemplates)   PK="mspp_webtemplateid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
    mspp_contentsnippets) PK="mspp_contentsnippetid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
    *) PK="${TABLE_NAME%s}id"; NAME_COL="name"; EXTRA_COLS="" ;;
  esac

  echo ""
  echo -e "${YELLOW}Querying records from ${#TABLES[@]} table(s)...${NC}"

  RECORDS_JSON="["
  FIRST=true

  for TBL in "${TABLES[@]}"; do
    TBL=$(echo "$TBL" | xargs)

    case "$TBL" in
      powerpagecomponents) PK="powerpagecomponentid"; NAME_COL="name"; EXTRA_COLS="powerpagecomponenttype" ;;
      mspp_webtemplates)   PK="mspp_webtemplateid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
      mspp_contentsnippets) PK="mspp_contentsnippetid"; NAME_COL="mspp_name"; EXTRA_COLS="" ;;
      *) PK="${TBL%s}id"; NAME_COL="name"; EXTRA_COLS="" ;;
    esac

    FILTER=""
    if [[ -n "$WEBSITE_FILTER" ]]; then
      FILTER="\$filter=_powerpagesiteid_value%20eq%20$WEBSITE_FILTER&"
    fi

    SRC_RECORDS=$(curl -s "$SRC_ENVIRONMENT_URL/api/data/v9.2/${TBL}?${FILTER}\$select=$PK,$NAME_COL,modifiedon${EXTRA_COLS:+,$EXTRA_COLS}&\$orderby=modifiedon%20desc&\$top=100" \
      -H "Authorization: Bearer $SRC_TOKEN" -H "Accept: application/json" 2>/dev/null)

    echo "$SRC_RECORDS" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
records = d.get('value', [])
for r in records:
    guid = r.get('$PK', '')
    name = r.get('$NAME_COL', '?')
    mod = r.get('modifiedon', '?')[:19].replace('T', ' ')
    print(f'{guid}|{name}|{mod}|$TBL')
" 2>/dev/null | while IFS='|' read -r GUID NAME MOD TBL_NAME; do
      GUIDS+=("$GUID")
      TGT_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "$TGT_ENVIRONMENT_URL/api/data/v9.2/${TBL_NAME}($GUID)" \
        -H "Authorization: Bearer $TGT_TOKEN" 2>/dev/null)
      if [[ "$TGT_CHECK" == "200" ]]; then ACTION="Update"; else ACTION="Create"; fi

      if [[ "$FIRST" == true ]]; then FIRST=false; else RECORDS_JSON+=","; fi
      RECORDS_JSON+="{\"guid\":\"$GUID\",\"name\":\"$NAME\",\"modified\":\"$MOD\",\"action\":\"$ACTION\",\"table\":\"$TBL_NAME\"}"
    done
  done
  RECORDS_JSON+="]"

else
  echo -e "${RED}Invalid choice.${NC}"; exit 1
fi

# ── Display deployment plan ───────────────────────────────────
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE} Deployment Plan${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "$RECORDS_JSON" | python3 -c "
import sys, json

records = json.loads(sys.stdin.read())
if not records:
    print('  No records found.')
    sys.exit(0)

# Column widths
gw = 38
nw = max(max(len(r.get('name','')[:40]) for r in records), 4)
nw = min(nw, 40)
mw = 20
aw = 8

hdr = f\"{'GUID':<{gw}}  {'Name':<{nw}}  {'Last Modified':<{mw}}  {'Action':<{aw}}\"
sep = '─' * len(hdr)
print(f'  {hdr}')
print(f'  {sep}')

creates = 0
updates = 0
for r in records:
    guid = r.get('guid', '?')
    name = r.get('name', '?')[:nw]
    mod = r.get('modified', '?')
    action = r.get('action', '?')
    if action == 'Create': creates += 1
    else: updates += 1
    marker = '🆕' if action == 'Create' else '🔄'
    print(f'  {guid:<{gw}}  {name:<{nw}}  {mod:<{mw}}  {marker} {action}')

print(f'  {sep}')
print(f'  Total: {len(records)} records ({updates} updates, {creates} creates)')
" 2>/dev/null

# ── Confirm ───────────────────────────────────────────────────
echo ""
read -rp "Proceed with deployment? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Deployment cancelled."
  exit 0
fi

# ── Execute deployment ────────────────────────────────────────
echo ""
echo -e "${YELLOW}Deploying...${NC}"

# Re-parse records for deployment
TOTAL=$(echo "$RECORDS_JSON" | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null)
CURRENT=0
SUCCESS=0
FAILED=0

echo "$RECORDS_JSON" | python3 -c "
import sys, json
for r in json.loads(sys.stdin.read()):
    t = r.get('table', '$TABLE_NAME')
    print(f\"{r['guid']}|{r['name']}|{r['action']}|{t}\")
" 2>/dev/null | while IFS='|' read -r GUID NAME ACTION TBL; do
  ((CURRENT++)) || true

  # Fetch full record from source
  SRC_FULL=$(curl -s "$SRC_ENVIRONMENT_URL/api/data/v9.2/${TBL}($GUID)" \
    -H "Authorization: Bearer $SRC_TOKEN" -H "Accept: application/json" 2>/dev/null)

  # Remove OData metadata fields before PATCHing
  PATCH_BODY=$(echo "$SRC_FULL" | python3 -c "
import sys, json
d = json.loads(sys.stdin.read())
# Remove read-only / metadata fields
for key in list(d.keys()):
    if key.startswith('@') or key.startswith('_') or key in (
        'modifiedon','createdon','versionnumber','overwritetime',
        'componentstate','solutionid','ismanaged','importsequencenumber',
        'overriddencreatedon','timezoneruleversionnumber','utcconversiontimezonecode',
        'statecode','statuscode','componentidunique'
    ):
        del d[key]
print(json.dumps(d))
" 2>/dev/null)

  if [[ "$ACTION" == "Create" ]]; then
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
      "$TGT_ENVIRONMENT_URL/api/data/v9.2/${TBL}" \
      -H "Authorization: Bearer $TGT_TOKEN" \
      -H "Content-Type: application/json" \
      -H "OData-MaxVersion: 4.0" \
      -d "$PATCH_BODY" 2>/dev/null)
  else
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH \
      "$TGT_ENVIRONMENT_URL/api/data/v9.2/${TBL}($GUID)" \
      -H "Authorization: Bearer $TGT_TOKEN" \
      -H "Content-Type: application/json" \
      -H "If-Match: *" \
      -d "$PATCH_BODY" 2>/dev/null)
  fi

  if [[ "$HTTP" == "204" || "$HTTP" == "201" ]]; then
    echo -e "  [$CURRENT/$TOTAL] ${GREEN}✓${NC} $NAME ($ACTION)"
    ((SUCCESS++)) || true
  else
    echo -e "  [$CURRENT/$TOTAL] ${RED}✗${NC} $NAME ($ACTION) — HTTP $HTTP"
    ((FAILED++)) || true
  fi
done

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE} Deployment complete.${NC}"
echo -e "${BLUE} Source: $SRC_ENVIRONMENT_URL${NC}"
echo -e "${BLUE} Target: $TGT_ENVIRONMENT_URL${NC}"
echo -e "${BLUE}========================================${NC}"
