# Dataverse Record Deployment Tool

A bash script that copies specific records or entire tables from one Dataverse environment to another using the Web API. Useful for deploying Power Pages components (web templates, content snippets, site settings) and other Dataverse records between environments without importing full solutions.

## Prerequisites

- **bash** (macOS/Linux/WSL)
- **curl** — for HTTP requests to Dataverse Web API
- **python3** — for JSON parsing and URL encoding
- An **Entra app registration** (service principal) with Dataverse API permissions in both source and target environments

## Quick Start

```bash
# 1. Copy the example config and fill in your credentials
cp .env-deploy.example .env-deploy

# 2. Edit .env-deploy with your source/target environment details
#    (see Configuration section below)

# 3. Run the script
./deploy-records.sh --config .env-deploy
```

## Usage

```bash
./deploy-records.sh [OPTIONS]
```

| Option | Description |
|---|---|
| `--config`, `-c` `<file>` | Path to environment config file |
| `--help`, `-h` | Show help message |

If no `--config` is provided, the script prompts interactively for all credentials.

## Configuration

Create a `.env-deploy` file (see `.env-deploy.example`):

```bash
# Source Environment (read-only — records are fetched from here)
SRC_TENANT_ID="your-source-tenant-id"
SRC_CLIENT_ID="your-source-client-id"
SRC_CLIENT_SECRET="your-source-client-secret"
SRC_ENVIRONMENT_URL="https://source-org.crm3.dynamics.com"

# Target Environment (records are deployed here)
TGT_TENANT_ID="your-target-tenant-id"
TGT_CLIENT_ID="your-target-client-id"
TGT_CLIENT_SECRET="your-target-client-secret"
TGT_ENVIRONMENT_URL="https://target-org.crm3.dynamics.com"
```

> **Note:** Never commit `.env-deploy` files containing real secrets. The `.env-deploy.example` file contains placeholder values only.

## Deployment Modes

The script prompts you to choose a mode after authenticating:

### Mode 1 — Deploy Specific Records by GUID

Deploy one or more records from a single table by providing their GUIDs.

```
Choose mode:
  1) Deploy specific records by GUID(s)

Enter table name: powerpagecomponents
Enter GUID(s) (comma-separated): abc123-..., def456-...
```

### Mode 2 — Deploy All Records from Table(s)

Deploy all records from one or more tables. Optionally filter by Power Pages website ID.

```
Choose mode:
  2) Deploy all records from table(s)

Enter table name(s) (comma-separated): powerpagecomponents, annotations
Filter by website ID? (leave blank to skip):
```

## Deployment Plan & Confirmation

Before making any changes, the script displays a deployment plan showing each record with:

| Column | Description |
|---|---|
| GUID | The record's unique identifier |
| Name | Display name of the record |
| Modified | Last modified date |
| Action | **Create** (new record) or **Update** (existing record) |

You must confirm with `y` before any writes are made to the target environment.

## Supported Tables

| Table | Contents |
|---|---|
| `powerpagecomponents` | Web templates, site settings, content snippets (enhanced data model) |
| `mspp_webtemplates` | Legacy web templates (standard data model) |
| `mspp_contentsnippets` | Legacy content snippets |
| `cs_templates` | E-signature templates |
| `cs_envelopes` | E-signature envelopes |
| `annotations` | Note attachments (e.g., PDF files) |
| *(any table)* | The script auto-detects the primary key column |

## Examples

```bash
# Deploy using a config file
./deploy-records.sh --config .env-deploy

# Deploy interactively (prompts for all credentials)
./deploy-records.sh

# Show help
./deploy-records.sh --help
```

## How It Works

1. **Authenticates** to both source and target using OAuth2 client credentials
2. **Fetches records** from the source environment via Dataverse Web API
3. **Checks target** for existing records (by GUID match)
4. **Shows deployment plan** with Create/Update actions per record
5. **Executes** after user confirmation — creates new records (POST) or updates existing ones (PATCH)
6. OData metadata fields (`@odata.*`, `_*_value`, `*@*`) are automatically stripped before writing

## Safety

- The **source environment is never modified** — only GET requests are made
- The **target environment** only receives POST (create) or PATCH (update) for confirmed records
- **Site settings are not touched** unless you explicitly include them in your deployment
- All changes require **explicit confirmation** before execution
