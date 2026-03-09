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
3. Download and import both solutions in the correct order
4. Verify the installation

## Package Contents

| File | Description | Version |
|------|-------------|---------|
| `nintex_1_0_0_1_managed.zip` | Schema solution — 16 custom tables, columns, and entity relationships | 1.0.0.1 |
| `ESignatureBroker_1_0_0_33_managed.zip` | Workflow solution — 10 Power Automate cloud flows | 1.0.0.33 |
| `ImportConfig.xml` | Package configuration — ensures correct import order | — |
| `configuration.html` | Setup guide and configuration reference | — |

## Solutions Overview

### 1. Nintex Schema (`nintex`)
Defines the Dataverse data model:

- **16 tables**: `cs_envelope`, `cs_document`, `cs_signer`, `cs_accesslink`, `cs_envelopehistory`, `cs_emailnotification`, `cs_field`, `cs_senderinput`, `cs_webhook`, `cs_template`, `cs_authtoken`, `cs_assuresign`, `cs_apirequest`, `cs_digitalsignature`, `cs_item`, `cs_useraccount`
- **Lookup relationships**: `cs_envelopelookup` columns on 8 child tables linking to `cs_envelope`
- **Boolean flag columns**: `cs_isactive`, `cs_iscancelled`, `cs_requesthistory`, `cs_requestsignedcopy`, `cs_sendreminder`
- **String columns**: `cs_envelopesignerid` on `cs_document`

### 2. E-Signature Broker (`ESignatureBroker`)
10 Power Automate cloud flows that orchestrate envelope lifecycle:

| Flow | Trigger | Purpose |
|------|---------|---------|
| ESign - Prepare Envelope | `cs_envelope` created | Initialize envelope in Nintex |
| ESign - Send Envelope | `cs_envelope.cs_issent` → Yes | Submit envelope for signing |
| ESign - Status Sync | `cs_envelope.cs_requeststatus` → Yes | Poll Nintex for status updates |
| ESign - Get Signing Links | `cs_signer.cs_requestlink` → Yes | Retrieve signing URLs |
| ESign - Get Access Links | `cs_accesslink` created | Fetch access link URLs |
| ESign - Get Document Content | `cs_document.cs_requestsignedcopy` → Yes | Download signed PDFs |
| ESign - Get Envelope History | `cs_envelope.cs_requesthistory` → Yes | Sync audit history |
| ESign - Cancel Envelope | `cs_envelope.cs_iscancelled` → Yes | Cancel an in-progress envelope |
| ESign - Send Signer Reminder | `cs_signer.cs_sendreminder` → Yes | Send reminder to a signer |
| ESign - Sync Templates | `cs_assuresign.cs_synctemplates` → Yes | Import templates from Nintex |

## Prerequisites

- Microsoft Dataverse environment (Production or Sandbox)
- Power Platform admin or System Customizer role
- **PAC CLI** v1.41+ installed (`dotnet tool install --global Microsoft.PowerApps.CLI.Tool`)
- Authenticated to target environment (`pac auth create`)

## Deployment Steps

### Option A: PAC CLI (Recommended)

```bash
# 1. Authenticate to target environment
pac auth create --environment "https://your-org.crm3.dynamics.com"

# 2. Import schema solution first (must be imported before workflows)
pac solution import \
  --path Deployment/nintex_1_0_0_1_managed.zip \
  --publish-changes \
  --activate-plugins

# 3. Import workflow solution (depends on schema)
pac solution import \
  --path Deployment/ESignatureBroker_1_0_0_33_managed.zip \
  --publish-changes \
  --activate-plugins

# 4. Verify both solutions imported
pac solution list
```

### Option B: Power Platform Admin Center

1. Go to **make.powerapps.com** → select your environment
2. Navigate to **Solutions** → **Import solution**
3. Upload `nintex_1_0_0_1_managed.zip` → **Next** → **Import**
4. Wait for completion, then repeat with `ESignatureBroker_1_0_0_33_managed.zip`

### Option C: Package Deployer (Automated)

If you have a Package Deployer project configured:

```bash
# Initialize package project (one-time setup)
pac package init --outputDirectory NintexESignPackage

# Add solutions in dependency order
cd NintexESignPackage
pac package add-solution --solutionZipPath ../Deployment/nintex_1_0_0_1_managed.zip
pac package add-solution --solutionZipPath ../Deployment/ESignatureBroker_1_0_0_33_managed.zip

# Build the package
dotnet build

# Deploy
pac package deploy --package bin/Debug/NintexESignPackage.1.0.0.dll
```

## Post-Deployment Configuration

### 1. Configure Connection Reference

After importing, the `cs_sharecommondataserviceforapps` connection reference must be mapped:

1. Go to **Solutions** → **E-Signature Broker** → **Connection References**
2. Select **Dataverse (Current Environment)**
3. Click **Edit** → select or create a Dataverse connection for the service account
4. Save

### 2. Activate Cloud Flows

All 10 flows import in a draft state. To activate:

1. Go to **Solutions** → **E-Signature Broker** → **Cloud flows**
2. Select each flow → **Turn on**
3. Or use PAC CLI:
   ```bash
   pac solution publish
   ```

### 3. Configure Nintex/AssureSign Credentials

Create a record in the `cs_assuresign` (Configuration) table:

| Column | Value |
|--------|-------|
| `cs_apiurl` | Your Nintex eSign API URL |
| `cs_apikey` | Your API key |
| `cs_accountid` | Your account ID |

### 4. Test the Integration

1. Create a new `cs_envelope` record
2. Verify the **ESign - Prepare Envelope** flow triggers
3. Set `cs_issent` to **Yes** to trigger the send flow
4. Check flow run history for success

## PAC Commands Reference

Commands used during solution development:

```bash
# Unpack a solution for source control
pac solution unpack --zipfile solution.zip --folder ./unpacked --packagetype Both

# Pack solution as managed for deployment
pac solution pack --folder ./unpacked --zipfile solution_managed.zip --packagetype Managed

# Pack as unmanaged for development
pac solution pack --folder ./unpacked --zipfile solution_unmanaged.zip --packagetype Unmanaged

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
| `NullReferenceException (0x80040216)` | Workflow XML format incorrect | Ensure `customizations.xml` uses child elements (not attributes) for workflow properties |
| `WorkflowOperationParametersExtraParameter` | Missing columns in schema | Import `nintex_1_0_0_1_managed.zip` first |
| `Attribute is a String, but Lookup specified` | Column type mismatch | Cannot change existing column types — use new column name (e.g., `cs_envelopelookup`) |
| Connection reference error | Unmapped connection | Configure the Dataverse connection reference post-import |

## Solution Publisher

- **Publisher**: CloudStrucc (`cs`)
- **Prefix**: `cs_`
- **Option Value Prefix**: 71764

## Version History

| Version | Date | Changes |
|---------|------|---------|
| Schema 1.0.0.0 | Initial | 16 custom tables |
| Schema 1.0.0.1 | 2026-03 | Added boolean flags, lookup columns, entity relationships |
| Broker 1.0.0.33 | 2026-03 | 10 cloud flows with correct Dataverse format, lookup references |

---

*Built by [CloudStrucc Inc.](https://www.cloudstrucc.com) — Microsoft Partner for Power Platform & Dynamics 365*
