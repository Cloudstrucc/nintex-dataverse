# Nintex AssureSign E-Signature Broker Service

A **Power Platform** broker service that sits between client Dataverse environments and the **Nintex AssureSign API**, managing all e-signature transaction state in a centralized broker environment.

## Architecture

```
Client Environment                    Broker Environment                  Nintex AssureSign
┌──────────────────┐                 ┌──────────────────────┐            ┌────────────────┐
│ Client Flows     │  Dataverse      │ Broker Tables        │            │                │
│ (ESignatureClient│  Cross-Env      │ (cs_envelope,        │  REST API  │  /submit       │
│  solution)       │──Connection────>│  cs_signer, etc.)    │──────────> │  /templates    │
│                  │                 │                      │            │  /signingLinks │
│ Create envelope  │                 │ Broker Flows         │  <──────── │  /cancel       │
│ Add signers      │                 │ (ESignatureBroker    │            │  /status       │
│ Set status       │                 │  solution)           │            │                │
└──────────────────┘                 └──────────────────────┘            └────────────────┘
```

### Solutions (publisher prefix `cs`)

| Solution | Unique Name | Purpose |
|---|---|---|
| **Nintex Schema** | `nintex` | 16 custom Dataverse tables, columns, relationships, status values |
| **E-Signature Config** | `ESignatureConfig` | 5 environment variables for Nintex API credentials and URLs |
| **E-Signature Broker** | `ESignatureBroker` | 10 Power Automate cloud flows for Nintex API integration |
| **E-Signature Client** | `ESignatureClient` | 6 sample flows + environment variable for client environments |

**Import order (broker environment):** Schema > Config > Broker

**Client environment:** Install ESignatureClient only — it connects cross-environment to the broker's Dataverse.

## Repository Structure

```
solutions/                              Dataverse solution source (pac unpack format)
├── ESignatureBroker/                   Broker flows source
├── ESignatureClient/                   Client sample flows source
├── ESignatureConfig/                   API environment variables source
└── releases/                           Solution zip files (managed + unmanaged)
    ├── broker/                         ESignatureBroker releases
    ├── client/                         ESignatureClient releases
    ├── config/                         ESignatureConfig releases
    └── schema/                         Nintex Schema releases
installer/                              .NET CLI installer (source + platform binaries)
power-pages/                            Power Pages site configuration
word-addin/                             Word Add-in for template authoring
scripts/                                Shell scripts for deployment and diagnostics
docs/                                   Architecture and integration guides
connectors/                             OpenAPI/Swagger connector definitions
```

## Broker Flows

All broker flows are triggered automatically by Dataverse record changes — no manual intervention required.

| Flow | Trigger | What It Does |
|---|---|---|
| **ESign - Prepare Envelope** | Envelope statuscode = Preparing (717640001) | Fetches template signer names dynamically from Nintex, builds values array, calls `POST /submit`, stores envelopeID + authToken, sets status to In Process |
| **ESign - Send Envelope** | Envelope statuscode = Ready to Send (717640002) | Submits prepared envelope or new envelope to Nintex API (fallback path) |
| **ESign - Get Signing Links** | Envelope statuscode = In Process (717640003) | Calls `GET /envelope/{id}/signingLinks`, updates signer records with signing URLs |
| **ESign - Cancel Envelope** | Envelope cs_iscancelled = true | Calls `PUT /envelopes/{id}/cancel` with authToken + remarks, sets status to Cancelled |
| **ESign - Status Sync** | Recurrence (every 30 min) | Polls Nintex for all In Process envelopes, updates statuscode + signer statuses |
| **ESign - Get Access Links** | Envelope statuscode = Completed (717640004) | Retrieves access link records for completed envelopes |
| **ESign - Get Envelope History** | Envelope cs_requesthistory = true | Fetches event history from Nintex, creates history records in Dataverse |
| **ESign - Get Document Content** | Document cs_requestsignedcopy = true | Downloads signed document content from Nintex |
| **ESign - Send Signer Reminder** | Signer cs_sendreminder = true | Sends reminder notification via Nintex API |
| **ESign - Sync Templates** | Recurrence (daily) | Syncs template list from Nintex API into cs_templates table |

## Client Sample Flows

These flows run in the client environment and create/read records in the broker environment via cross-environment Dataverse connection.

| Flow | Trigger | What It Does |
|---|---|---|
| **Sample - Create and Send Envelope** | Button (Subject, Signer Name, Email, Template ID, Message) | Creates envelope + signer in broker, sets status to Preparing — triggers the full broker submit chain |
| **Sample - Create Draft Envelope** | Button (Subject, Template ID, Message, Days to Expire) | Creates envelope in Draft status — add signers/docs before triggering |
| **Sample - Add Signer to Envelope** | Button (Envelope ID, Signer Name, Email, Order) | Adds a signer record linked to an existing envelope |
| **Sample - Check Envelope Status** | Button (Envelope ID) | Reads envelope record + lists signers and documents |
| **Sample - Cancel Envelope** | Button (Envelope ID) | Checks if In Process, sets cs_iscancelled = true — triggers broker cancel flow |
| **Sample - List Templates** | Button (no inputs) | Queries broker for all available e-signature templates |

## Envelope Lifecycle

```
Draft (1) ──> Preparing (717640001) ──> In Process (717640003) ──> Completed (717640004)
                                                                \─> Cancelled (717640006)
                                                                \─> Error (717640005)
```

The client sets status to **Preparing** — from there, the broker handles everything automatically via the flow trigger chain.

## Installation

### Broker Environment Setup

1. **Import solutions** (in order):
   ```
   solutions/releases/schema/nintex_1_0_0_2_unmanaged.zip     (or managed)
   solutions/releases/config/ESignatureConfig_1_0_0_0_unmanaged.zip
   solutions/releases/broker/ESignatureBroker_1_0_0_47_unmanaged.zip
   ```

2. **Set environment variables** (in ESignatureConfig):
   | Variable | Value |
   |---|---|
   | `cs_NintexApiUsername` | Your Nintex API username |
   | `cs_NintexApiKey` | Your Nintex API key |
   | `cs_NintexContextUsername` | Nintex context user email |
   | `cs_NintexAuthUrl` | `https://account.assuresign.net/api/v3.7` |
   | `cs_NintexApiBaseUrl` | `https://ca1.assuresign.net/api/documentnow/v3.7` |

3. **Configure connection reference** `cs_sharecommondataserviceforapps` to point to the broker environment's Dataverse.

4. **Activate all 10 broker flows** in Power Automate.

5. **Assign the E-Signature Broker User** security role to service accounts.

### Client Environment Setup

1. **Import the client solution:**
   ```
   solutions/releases/client/ESignatureClient_1_0_0_14_unmanaged.zip
   ```

2. **Set the environment variable** `cs_BrokerServiceEnvironment` to your broker's Dataverse URL (e.g., `https://goc-wetv14.crm3.dynamics.com`).

3. **Configure connection reference** `cs_esignbrokerconnection` — create a Dataverse connection that targets the broker environment.

4. **Activate the sample flows** and test.

### Using the CLI Installer (Alternative)

Platform binaries are in `installer/`:
```bash
# macOS
./installer/esign-installer-macos-arm64.pkg

# Linux
./installer/esign-installer-linux-x64

# Windows
installer\esign-installer-win-x64.exe
```

The installer prompts for credentials and imports all solutions in order.

## Testing

### Test Nintex API Connectivity

```bash
# Requires .env file at repo root with Nintex credentials
./scripts/test-nintex-api.sh

# Or specify a template ID
./scripts/test-nintex-api.sh f47f3880-88e5-4314-8a34-b4030142217c
```

Tests 9 endpoints: auth, list templates, template details, submit, status, signing links, history, cancel, verify cancelled.

### Test Client Flows

1. Run **Sample - List Templates** to verify broker connectivity and see available templates.
2. Run **Sample - Create and Send Envelope** with a valid template ID — this triggers the full chain: client creates records > broker Prepare Envelope fires > Nintex API submit > signing links generated.
3. Run **Sample - Check Envelope Status** with the envelope ID to verify status = In Process.
4. Check the signer's email for the signing link.

### Pack Solutions from Source

```bash
pac solution pack --zipFile output.zip --folder solutions/ESignatureBroker --processCanvasApps false
pac solution pack --zipFile output.zip --folder solutions/ESignatureClient --processCanvasApps false
```

## Nintex API Reference

| Method | Endpoint | Notes |
|---|---|---|
| `POST` | `/authentication/apiUser` | Auth — body wrapped in `{request: {...}}` |
| `GET` | `/templates` | List all templates |
| `GET` | `/templates/{id}` | Template details (signer placeholder names) |
| `POST` | `/submit` | Submit envelope — `{request: {templates: [{templateID, values}]}}` |
| `GET` | `/envelopes/{id}/status` | Envelope status (plural path) |
| `GET` | `/envelope/{id}/signingLinks` | Signing links (**singular** path) |
| `GET` | `/envelopes/{id}/history` | Envelope history (plural path) |
| `PUT` | `/envelopes/{id}/cancel` | Cancel — `{request: {authToken, remarks}}` |

Note: signing links uses **singular** `/envelope/`, all other endpoints use **plural** `/envelopes/`.

## Documentation

| Guide | Description |
|---|---|
| [Broker Admin Guide](docs/broker-admin-guide.md) | Broker environment setup, monitoring, security |
| [Client Integration Guide](docs/client-integration-guide.md) | Client environment setup, sample flows, testing |
| [Solution Architecture (SADD)](docs/sadd-v2.md) | Full architecture and design document |
| [Custom Connector Guide](docs/custom-connector-guide-v2.md) | Legacy custom connector documentation |

## License

See [LICENSE](LICENSE).
