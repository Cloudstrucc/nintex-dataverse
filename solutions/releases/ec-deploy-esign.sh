#!/bin/bash
# ============================================================
# Elections Canada – ESIGN Portal Deployment Script
# Lives at: root/solutions/releases/ec-deploy-esign.sh
# .env file: root/.env  (two levels up)
# Usage: ./ec-deploy-esign.sh
# ============================================================

set -euo pipefail
# -e  : exit immediately if any command fails
# -u  : treat unset variables as errors
# -o pipefail : catch failures inside pipes

# ── Resolve paths (script is 2 levels below root) ─────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/../.."
ENV_FILE="$ROOT_DIR/.env"
SITE_DIR="$ROOT_DIR/power-pages/site/e-sign-dev---e-sign-dev"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: .env file not found at $ENV_FILE"
  exit 1
fi

# Load .env — strips comments and blank lines, exports all KEY=VALUE pairs
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

# ── Required variables (must be present in .env) ───────────────────────────
: "${EC_TENANT_ID:?EC_TENANT_ID is not set in .env}"
: "${EC_CLIENT_ID:?EC_CLIENT_ID is not set in .env}"
: "${EC_CLIENT_SECRET:?EC_CLIENT_SECRET is not set in .env}"

TENANT_ID="$EC_TENANT_ID"
CLIENT_ID="$EC_CLIENT_ID"
CLIENT_SECRET="$EC_CLIENT_SECRET"

ENVIRONMENT="https://dev-ec-esign-01.crm3.dynamics.com"

# Optional: TARGET_WEBSITE_ID for Power Pages upload (can be set in .env)
TARGET_WEBSITE_ID="${EC_WEBSITE_ID:-}"

# ── Prompt: managed or unmanaged ──────────────────────────────────────────
echo ""
echo "Select solution type to import:"
echo "  1) managed"
echo "  2) unmanaged"
echo ""
read -rp "Enter 1 or 2: " TYPE_CHOICE

case "$TYPE_CHOICE" in
  1) SOLUTION_TYPE="managed" ;;
  2) SOLUTION_TYPE="unmanaged" ;;
  *)
    echo "ERROR: Invalid choice '$TYPE_CHOICE'. Enter 1 or 2."
    exit 1
    ;;
esac

# Postfix appended to each zip filename: _managed or _unmanaged
ZIP_SUFFIX="_${SOLUTION_TYPE}"

# ── Prompt: deploy Power Pages site? ──────────────────────────────────────
echo ""
echo "Deploy Power Pages site after solution import?"
echo "  1) Yes — upload site from power-pages/site/"
echo "  2) No  — solutions only"
echo ""
read -rp "Enter 1 or 2: " PORTAL_CHOICE

DEPLOY_PORTAL=false
case "$PORTAL_CHOICE" in
  1) DEPLOY_PORTAL=true ;;
  2) DEPLOY_PORTAL=false ;;
  *)
    echo "ERROR: Invalid choice '$PORTAL_CHOICE'. Enter 1 or 2."
    exit 1
    ;;
esac

# If deploying portal, ensure we have a website ID
if [[ "$DEPLOY_PORTAL" == true ]]; then
  if [[ -z "$TARGET_WEBSITE_ID" ]]; then
    echo ""
    read -rp "Enter the target Power Pages Website ID (GUID): " TARGET_WEBSITE_ID
    if [[ -z "$TARGET_WEBSITE_ID" ]]; then
      echo "ERROR: Website ID is required to deploy the portal."
      exit 1
    fi
  fi

  # Verify the site source folder exists
  if [[ ! -d "$SITE_DIR" ]]; then
    echo "ERROR: Power Pages site folder not found at $SITE_DIR"
    exit 1
  fi
fi

# ── Calculate step count ──────────────────────────────────────────────────
if [[ "$DEPLOY_PORTAL" == true ]]; then
  TOTAL_STEPS=6
else
  TOTAL_STEPS=5
fi

echo ""
echo "========================================"
echo " ESIGN Deployment"
echo " Target:        $ENVIRONMENT"
echo " Solution type: $SOLUTION_TYPE"
if [[ "$DEPLOY_PORTAL" == true ]]; then
echo " Portal:        Yes (Website ID: $TARGET_WEBSITE_ID)"
else
echo " Portal:        No"
fi
echo "========================================"

# ── 1. Authenticate ────────────────────────────────────────────────────────
echo ""
echo "[1/$TOTAL_STEPS] Authenticating as service principal..."
pac auth create \
  --environment   "$ENVIRONMENT" \
  --tenant        "$TENANT_ID" \
  --applicationId "$CLIENT_ID" \
  --clientSecret  "$CLIENT_SECRET" \
  --kind DATAVERSE

# ── 2. Schema solution (tables & columns) ─────────────────────────────────
# echo ""
# echo "[2/$TOTAL_STEPS] Importing schema solution (tables & columns)..."
# pac solution import \
#   --path "schema/nintex_1_0_0_2${ZIP_SUFFIX}.zip" \
#   --publish-changes \
#   --activate-plugins

# ── 3. Config solution (environment variables) ────────────────────────────
echo ""
echo "[3/$TOTAL_STEPS] Importing config solution (environment variables)..."
pac solution import \
  --path "config/ESignatureConfig_1_0_0_0${ZIP_SUFFIX}.zip" \
  --publish-changes \
  --activate-plugins

# ── 4. Workflow solution (cloud flows) ────────────────────────────────────
echo ""
echo "[4/$TOTAL_STEPS] Importing workflow solution (cloud flows)..."
pac solution import \
  --path "broker/ESignatureBroker_1_0_0_51${ZIP_SUFFIX}.zip" \
  --publish-changes \
  --activate-plugins

# ── 5. Deploy Power Pages site (if selected) ─────────────────────────────
if [[ "$DEPLOY_PORTAL" == true ]]; then
  echo ""
  echo "[5/$TOTAL_STEPS] Uploading Power Pages site (enhanced data model)..."
  pac powerpages upload \
    --path "$SITE_DIR" \
    --environment "$ENVIRONMENT" \
    --modelVersion 2 \
    --forceUploadAll
fi

# ── Final. Verify ─────────────────────────────────────────────────────────
VERIFY_STEP=$TOTAL_STEPS
echo ""
echo "[$VERIFY_STEP/$TOTAL_STEPS] Verifying imported solutions..."
pac solution list

echo ""
echo "========================================"
echo " Deployment complete ($SOLUTION_TYPE)."
if [[ "$DEPLOY_PORTAL" == true ]]; then
echo " Power Pages site uploaded successfully."
fi
echo "========================================"
