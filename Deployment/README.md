# E-Signature Broker — Dataverse Deployment Package

Managed deployment package for the **E-Signature Broker** integration with Nintex/AssureSign, built for Microsoft Dataverse environments.

## Quick Install

Download the installer for your platform and run it — it handles authentication, solution download, and import automatically.

| Platform | Download | Size |
|----------|----------|------|
| Windows (x64) | [esign-installer-win-x64.exe](https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment/downloads/esign-installer-win-x64.exe) | ~11 MB |
| macOS (Apple Silicon) | [esign-installer-macos-arm64.pkg](https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment/downloads/esign-installer-macos-arm64.pkg) | ~6 MB |
| macOS (Intel) | [esign-installer-macos-x64.pkg](https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment/downloads/esign-installer-macos-x64.pkg) | ~6 MB |
| Linux (x64) | [esign-installer-linux-x64](https://github.com/Cloudstrucc/nintex-dataverse/raw/main/Deployment/downloads/esign-installer-linux-x64) | ~13 MB |

**Windows:** Double-click the `.exe` or run from terminal.
**macOS:** Double-click the `.pkg` to install, then run `esign-installer` from Terminal.
**Linux:** After downloading, run `chmod +x esign-installer-linux-x64 && ./esign-installer-linux-x64`

The installer will:
1. Check for (and install if needed) the PAC CLI
2. Authenticate to your Dataverse environment via browser
3. Download and import all 3 solutions in the correct order
4. Verify the installation

## Package Contents

| File | Description | Version |
|------|-------------|---------|
| `nintex_1_0_0_1_managed.zip` | Schema solution — 16 custom tables, columns, and entity relationships | 1.0.0.1 |
| `ESignatureConfig_1_0_0_0_managed.zip` | Configuration solution — 5 environment variables for Nintex API auth | 1.0.0.0 |
| `ESignatureBroker_1_0_0_34_managed.zip` | Workflow solution — 10 Power Automate cloud flows | 1.0.0.34 |
| `ImportConfig.xml` | Package configuration — ensures correct import order | — |
| `configuration.html` | Setup guide and configuration reference | — |

## Solutions Overview

### 1. Nintex Schema (`nintex`)
Defines the Dataverse data model:

- **16 tables**: `cs_envelope`, `cs_document`, `cs_signer`, `cs_accesslink`, `cs_envelopehistory`, `cs_emailnotification`, `cs_field`, `cs_senderinput`, `cs_webhook`, `cs_template`, `cs_authtoken`, `cs_assuresign`, `cs_apirequest`, `cs_digitalsignature`, `cs_item`, `cs_useraccount`
- **Lookup relationships**: `cs_envelopelookup` columns on 8 child tables linking to `cs_envelope`
- **Boolean flag columns**: `cs_isactive`, `cs_iscancelled`, `cs_requesthistory`, `cs_requestsignedcopy`, `cs_sendreminder`
- **String columns**: `cs_envelopesignerid` on `cs_document`

### 2. E-Signature Configuration (`ESignatureConfig`)
5 Dataverse environment variables for Nintex API authentication:

| Environment Variable | Description | Default |
|---------------------|-------------|---------|
| `cs_NintexApiUsername` | API username for authentication | *(required — set at import)* |
| `cs_NintexApiKey` | API key for authentication | *(required — set at import)* |
| `cs_NintexContextUsername` | User context sent in API headers | *(required — set at import)* |
| `cs_NintexAuthUrl` | Authentication endpoint base URL | `https://account.assuresign.net/api/v3.7` |
| `cs_NintexApiBaseUrl` | DocumentNow API base URL | `https://ca1.assuresign.net/api/documentnow/v3.7` |

Flows read these values at runtime from the `environmentvariabledefinitions` table — no credentials stored in custom tables.

### 3. E-Signature Broker (`ESignatureBroker`)
10 Power Automate cloud flows that orchestrate envelope lifecycle:

| Flow | Trigger | Purpose |
|------|---------|---------|
| ESign - Prepare Envelope | `cs_envelope` created | Initialize envelope in Nintex |
| ESign - Send Envelope | `cs_envelope.cs_issent` -> Yes | Submit envelope for signing |
| ESign - Status Sync | `cs_envelope.cs_requeststatus` -> Yes | Poll Nintex for status updates |
| ESign - Get Signing Links | `cs_signer.cs_requestlink` -> Yes | Retrieve signing URLs |
| ESign - Get Access Links | `cs_accesslink` created | Fetch access link URLs |
| ESign - Get Document Content | `cs_document.cs_requestsignedcopy` -> Yes | Download signed PDFs |
| ESign - Get Envelope History | `cs_envelope.cs_requesthistory` -> Yes | Sync audit history |
| ESign - Cancel Envelope | `cs_envelope.cs_iscancelled` -> Yes | Cancel an in-progress envelope |
| ESign - Send Signer Reminder | `cs_signer.cs_sendreminder` -> Yes | Send reminder to a signer |
| ESign - Sync Templates | `cs_assuresign.cs_synctemplates` -> Yes | Import templates from Nintex |

## Prerequisites

- Microsoft Dataverse environment (Production or Sandbox)
- Power Platform admin or System Customizer role
- Nintex eSign API credentials (username, key, context username)
- **PAC CLI** v1.41+ installed (`dotnet tool install --global Microsoft.PowerApps.CLI.Tool`)

## Deployment Steps

### Option A: PAC CLI (Recommended)

```bash
# 1. Authenticate to target environment
pac auth create --environment "https://your-org.crm3.dynamics.com"

# 2. Import schema solution (tables & columns)
pac solution import \
  --path Deployment/nintex_1_0_0_1_managed.zip \
  --publish-changes \
  --activate-plugins

# 3. Import config solution (environment variables)
pac solution import \
  --path Deployment/ESignatureConfig_1_0_0_0_managed.zip \
  --publish-changes \
  --activate-plugins

# 4. Import workflow solution (cloud flows)
pac solution import \
  --path Deployment/ESignatureBroker_1_0_0_34_managed.zip \
  --publish-changes \
  --activate-plugins

# 5. Verify all solutions imported
pac solution list
```

### Option B: Power Platform Admin Center

1. Go to **make.powerapps.com** -> select your environment
2. Navigate to **Solutions** -> **Import solution**
3. Upload `nintex_1_0_0_1_managed.zip` -> **Next** -> **Import**
4. Upload `ESignatureConfig_1_0_0_0_managed.zip` -> **Next** -> **Import**
5. Upload `ESignatureBroker_1_0_0_34_managed.zip` -> **Next** -> **Import**

### Option C: Package Deployer (Automated)

```bash
pac package init --outputDirectory NintexESignPackage
cd NintexESignPackage
pac package add-solution --solutionZipPath ../Deployment/nintex_1_0_0_1_managed.zip
pac package add-solution --solutionZipPath ../Deployment/ESignatureConfig_1_0_0_0_managed.zip
pac package add-solution --solutionZipPath ../Deployment/ESignatureBroker_1_0_0_34_managed.zip
dotnet build
pac package deploy --package bin/Debug/NintexESignPackage.1.0.0.dll
```

## Post-Deployment Configuration

### 1. Set Environment Variable Values

Navigate to **Solutions** -> **E-Signature Configuration** -> **Environment Variables** and set:

| Variable | Value |
|----------|-------|
| **Nintex API Username** | Your Nintex API username |
| **Nintex API Key** | Your Nintex API key |
| **Nintex Context Username** | Your Nintex context username |
| **Nintex Auth URL** | *(defaults to `https://account.assuresign.net/api/v3.7` — change only if needed)* |
| **Nintex API Base URL** | *(defaults to `https://ca1.assuresign.net/api/documentnow/v3.7` — change only if needed)* |

### 2. Configure Connection Reference

1. Go to **Solutions** -> **E-Signature Broker** -> **Connection References**
2. Select **Dataverse (Current Environment)**
3. Click **Edit** -> select or create a Dataverse connection for the service account
4. Save

### 3. Activate Cloud Flows

All 10 flows import in a draft state. To activate:

1. Go to **Solutions** -> **E-Signature Broker** -> **Cloud flows**
2. Select each flow -> **Turn on**

### 4. Test the Integration

1. Create a new `cs_envelope` record
2. Verify the **ESign - Prepare Envelope** flow triggers
3. Set `cs_issent` to **Yes** to trigger the send flow
4. Check flow run history for success

## Authentication Architecture

The flows use Dataverse environment variables (not custom tables) for Nintex API credentials:

```
Flow Start
  |
  +-- Query environmentvariabledefinitions (5 parallel queries)
  |     |-- cs_NintexApiUsername
  |     |-- cs_NintexApiKey
  |     |-- cs_NintexContextUsername
  |     |-- cs_NintexAuthUrl
  |     +-- cs_NintexApiBaseUrl
  |
  +-- HTTP POST {AuthUrl}/authentication/apiUser
  |     Body: { apiUsername, apiKey, contextUsername }
  |     Response: { result: { token: "..." } }
  |
  +-- Set BearerToken = "bearer " + token
  +-- Set UserContext = contextUsername
  |
  +-- (Business logic actions using BearerToken + UserContext headers)
```

Each flow authenticates fresh on every run. No token caching — simpler and more reliable.

## PAC Commands Reference

```bash
# Unpack a solution for source control
pac solution unpack --zipfile solution.zip --folder ./unpacked --packagetype Both

# Pack solution as managed for deployment
pac solution pack --folder ./unpacked --zipfile solution_managed.zip --packagetype Managed

# List solutions in environment
pac solution list

# Import with overwrite
pac solution import --path solution.zip --force-overwrite --publish-changes

# Export from environment
pac solution export --name SolutionName --path ./exports --managed
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `NullReferenceException (0x80040216)` | Workflow XML format incorrect | Use the provided managed solution zips |
| `WorkflowOperationParametersExtraParameter` | Missing columns in schema | Import `nintex_1_0_0_1_managed.zip` first |
| Environment variable not found | Config solution not imported | Import `ESignatureConfig_1_0_0_0_managed.zip` before broker |
| Connection reference error | Unmapped connection | Configure the Dataverse connection reference post-import |
| HTTP 401 on Nintex API | Wrong credentials | Check environment variable values in E-Signature Configuration |

## Solution Publisher

- **Publisher**: CloudStrucc (`cs`)
- **Prefix**: `cs_`
- **Option Value Prefix**: 71764

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Schema 1.0.0.0 | Initial | 16 custom tables |
| Schema 1.0.0.1 | 2026-03 | Added boolean flags, lookup columns, entity relationships |
| Config 1.0.0.0 | 2026-03 | 5 environment variables for Nintex API auth |
| Broker 1.0.0.34 | 2026-03 | 10 cloud flows using environment variables (no table-based auth) |

---

*Built by [CloudStrucc Inc.](https://www.cloudstrucc.com) -- Microsoft Partner for Power Platform & Dynamics 365*
