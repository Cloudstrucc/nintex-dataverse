#!/bin/bash
# ============================================================
# Elections Canada – ESIGN Portal Deployment Script
# Lives at: root/solutions/releases/ec-deploy-esign.sh
# .env file: root/.env  (two levels up)
# Usage: ./ec-deploy-esign.sh
# ============================================================

set -euo pipefail

# ── Resolve paths (script is 2 levels below root) ─────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../.."
ENV_FILE="$ROOT_DIR/.env"
SITE_DIR="$ROOT_DIR/power-pages/site/e-sign-dev---e-sign-dev"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

# Load .env
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── Required variables ────────────────────────────────────────────────────
: "${EC_ENVIRONMENT_URL:?EC_ENVIRONMENT_URL is not set in .env}"
: "${EC_TENANT_ID:?EC_TENANT_ID is not set in .env}"
: "${EC_CLIENT_ID:?EC_CLIENT_ID is not set in .env}"
: "${EC_CLIENT_SECRET:?EC_CLIENT_SECRET is not set in .env}"

TENANT_ID="$EC_TENANT_ID"
CLIENT_ID="$EC_CLIENT_ID"
CLIENT_SECRET="$EC_CLIENT_SECRET"
ENVIRONMENT="$EC_ENVIRONMENT_URL"
TARGET_WEBSITE_ID="${EC_WEBSITE_ID:-}"

# ── Solution definitions (folder/filename_version) ────────────────────────
# Order matters: Schema → Config → Broker → Client
SOL_NAMES=("Schema"              "Config"                   "Broker"                       "Client")
SOL_PATHS=("schema/nintex_1_0_0_2" "config/ESignatureConfig_1_0_0_0" "broker/ESignatureBroker_1_0_0_51" "client/ESignatureClient_1_0_0_15")
SOL_DESCS=("Tables & columns"   "Environment variables"    "Cloud flows (broker)"         "Cloud flows (client)")

# ── Helper: yes/no prompt (returns 0=yes, 1=no) ──────────────────────────
ask_yn() {
  local prompt="$1"
  local choice
  read -rp "$prompt (y/n): " choice
  case "$choice" in
    [yY]|[yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

# ══════════════════════════════════════════════════════════════════════════
#  STEP 1: What do you want to deploy?
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "=========================================="
echo " ESIGN Deployment — What to deploy"
echo " Target: $ENVIRONMENT"
echo "=========================================="
echo ""
echo "What would you like to deploy?"
echo "  1) All solutions + portal"
echo "  2) All solutions only (no portal)"
echo "  3) Select specific solutions"
echo "  4) Portal only (no solutions)"
echo ""
read -rp "Enter 1, 2, 3, or 4: " DEPLOY_MODE

DEPLOY_SCHEMA=false
DEPLOY_CONFIG=false
DEPLOY_BROKER=false
DEPLOY_CLIENT=false
DEPLOY_PORTAL=false
SOLUTION_TYPE="managed"
ZIP_SUFFIX="_managed"

case "$DEPLOY_MODE" in
  1)
    DEPLOY_SCHEMA=true; DEPLOY_CONFIG=true; DEPLOY_BROKER=true; DEPLOY_CLIENT=true; DEPLOY_PORTAL=true
    ;;
  2)
    DEPLOY_SCHEMA=true; DEPLOY_CONFIG=true; DEPLOY_BROKER=true; DEPLOY_CLIENT=true
    ;;
  3)
    echo ""
    echo "Select which solutions to deploy:"
    ask_yn "  Schema (tables & columns)?"         && DEPLOY_SCHEMA=true
    ask_yn "  Config (environment variables)?"     && DEPLOY_CONFIG=true
    ask_yn "  Broker (cloud flows)?"               && DEPLOY_BROKER=true
    ask_yn "  Client (cloud flows)?"               && DEPLOY_CLIENT=true
    echo ""
    ask_yn "  Also deploy the Power Pages portal?" && DEPLOY_PORTAL=true
    ;;
  4)
    DEPLOY_PORTAL=true
    ;;
  *)
    echo "ERROR: Invalid choice '$DEPLOY_MODE'."
    exit 1
    ;;
esac

# ── Check if any solutions are being deployed ─────────────────────────────
DEPLOY_ANY_SOL=false
if [[ "$DEPLOY_SCHEMA" == true || "$DEPLOY_CONFIG" == true || "$DEPLOY_BROKER" == true || "$DEPLOY_CLIENT" == true ]]; then
  DEPLOY_ANY_SOL=true
fi

# ══════════════════════════════════════════════════════════════════════════
#  STEP 2: Managed or unmanaged? (only if deploying solutions)
# ══════════════════════════════════════════════════════════════════════════
if [[ "$DEPLOY_ANY_SOL" == true ]]; then
  echo ""
  echo "Select solution type:"
  echo "  1) managed"
  echo "  2) unmanaged"
  echo ""
  read -rp "Enter 1 or 2: " TYPE_CHOICE

  case "$TYPE_CHOICE" in
    1) SOLUTION_TYPE="managed" ;;
    2) SOLUTION_TYPE="unmanaged" ;;
    *)
      echo "ERROR: Invalid choice '$TYPE_CHOICE'."
      exit 1
      ;;
  esac
  ZIP_SUFFIX="_${SOLUTION_TYPE}"
fi

# ══════════════════════════════════════════════════════════════════════════
#  STEP 3: Portal validation (if deploying portal)
# ══════════════════════════════════════════════════════════════════════════
if [[ "$DEPLOY_PORTAL" == true ]]; then
  if [[ -z "$TARGET_WEBSITE_ID" ]]; then
    echo ""
    read -rp "Enter the target Power Pages Website ID (GUID): " TARGET_WEBSITE_ID
    if [[ -z "$TARGET_WEBSITE_ID" ]]; then
      echo "ERROR: Website ID is required to deploy the portal."
      exit 1
    fi
  fi
  if [[ ! -d "$SITE_DIR" ]]; then
    echo "ERROR: Power Pages site folder not found at $SITE_DIR"
    exit 1
  fi
fi

# ── Calculate step count ──────────────────────────────────────────────────
STEP_COUNT=1  # auth is always step 1
[[ "$DEPLOY_SCHEMA" == true ]] && ((STEP_COUNT++))
[[ "$DEPLOY_CONFIG" == true ]] && ((STEP_COUNT++))
[[ "$DEPLOY_BROKER" == true ]] && ((STEP_COUNT++))
[[ "$DEPLOY_CLIENT" == true ]] && ((STEP_COUNT++))
[[ "$DEPLOY_PORTAL" == true ]] && ((STEP_COUNT++))
((STEP_COUNT++))  # verify step
TOTAL_STEPS=$STEP_COUNT

# ══════════════════════════════════════════════════════════════════════════
#  Summary
# ══════════════════════════════════════════════════════════════════════════
echo ""
echo "========================================"
echo " ESIGN Deployment Summary"
echo " Target:        $ENVIRONMENT"
if [[ "$DEPLOY_ANY_SOL" == true ]]; then
echo " Solution type: $SOLUTION_TYPE"
echo " Solutions:"
[[ "$DEPLOY_SCHEMA" == true ]] && echo "   ✓ Schema (tables & columns)"
[[ "$DEPLOY_CONFIG" == true ]] && echo "   ✓ Config (environment variables)"
[[ "$DEPLOY_BROKER" == true ]] && echo "   ✓ Broker (cloud flows)"
[[ "$DEPLOY_CLIENT" == true ]] && echo "   ✓ Client (cloud flows)"
else
echo " Solutions:     None"
fi
if [[ "$DEPLOY_PORTAL" == true ]]; then
echo " Portal:        Yes"
else
echo " Portal:        No"
fi
echo "========================================"
echo ""
if ! ask_yn "Proceed with deployment?"; then
  echo "Deployment cancelled."
  exit 0
fi

# ══════════════════════════════════════════════════════════════════════════
#  Execute deployment
# ══════════════════════════════════════════════════════════════════════════
CURRENT_STEP=0

# ── Authenticate ──────────────────────────────────────────────────────────
((CURRENT_STEP++))
echo ""
echo "[$CURRENT_STEP/$TOTAL_STEPS] Authenticating as service principal..."
pac auth create \
  --environment   "$ENVIRONMENT" \
  --tenant        "$TENANT_ID" \
  --applicationId "$CLIENT_ID" \
  --clientSecret  "$CLIENT_SECRET" \
  --kind DATAVERSE

# ── Schema ────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_SCHEMA" == true ]]; then
  ((CURRENT_STEP++))
  echo ""
  echo "[$CURRENT_STEP/$TOTAL_STEPS] Importing Schema solution (tables & columns)..."
  pac solution import \
    --path "schema/nintex_1_0_0_2${ZIP_SUFFIX}.zip" \
    --activate-plugins \
    ${SOLUTION_TYPE:+$([ "$SOLUTION_TYPE" = "unmanaged" ] && echo "--publish-changes")}
fi

# ── Config ────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_CONFIG" == true ]]; then
  ((CURRENT_STEP++))
  echo ""
  echo "[$CURRENT_STEP/$TOTAL_STEPS] Importing Config solution (environment variables)..."
  pac solution import \
    --path "config/ESignatureConfig_1_0_0_0${ZIP_SUFFIX}.zip" \
    --activate-plugins \
    ${SOLUTION_TYPE:+$([ "$SOLUTION_TYPE" = "unmanaged" ] && echo "--publish-changes")}
fi

# ── Broker ────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_BROKER" == true ]]; then
  ((CURRENT_STEP++))
  echo ""
  echo "[$CURRENT_STEP/$TOTAL_STEPS] Importing Broker solution (cloud flows)..."
  pac solution import \
    --path "broker/ESignatureBroker_1_0_0_51${ZIP_SUFFIX}.zip" \
    --activate-plugins \
    ${SOLUTION_TYPE:+$([ "$SOLUTION_TYPE" = "unmanaged" ] && echo "--publish-changes")}
fi

# ── Client ────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_CLIENT" == true ]]; then
  ((CURRENT_STEP++))
  echo ""
  echo "[$CURRENT_STEP/$TOTAL_STEPS] Importing Client solution (cloud flows)..."
  pac solution import \
    --path "client/ESignatureClient_1_0_0_15${ZIP_SUFFIX}.zip" \
    --activate-plugins \
    ${SOLUTION_TYPE:+$([ "$SOLUTION_TYPE" = "unmanaged" ] && echo "--publish-changes")}
fi

# ── Portal ────────────────────────────────────────────────────────────────
if [[ "$DEPLOY_PORTAL" == true ]]; then
  ((CURRENT_STEP++))
  echo ""
  echo "[$CURRENT_STEP/$TOTAL_STEPS] Uploading Power Pages site (enhanced data model)..."
  pac powerpages upload \
    --path "$SITE_DIR" \
    --environment "$ENVIRONMENT" \
    --modelVersion 2 \
    --forceUploadAll
fi

# ── Verify ────────────────────────────────────────────────────────────────
((CURRENT_STEP++))
echo ""
echo "[$CURRENT_STEP/$TOTAL_STEPS] Verifying imported solutions..."
pac solution list

# ── Done ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo " Deployment complete."
[[ "$DEPLOY_ANY_SOL" == true ]] && echo " Solutions: $SOLUTION_TYPE"
[[ "$DEPLOY_PORTAL" == true ]] && echo " Power Pages site uploaded."
echo "========================================"
