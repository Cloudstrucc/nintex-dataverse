# Nintex AssureSign E-Signature Broker Service

A **Power Platform** broker service that sits between client environments and the **Nintex AssureSign API**, managing all e-signature transaction state in Dataverse.

## Architecture

The broker uses a three-solution design (publisher prefix `cs`):

| Solution | Purpose | Folder |
|---|---|---|
| **Nintex Schema** (`nintex`) | 16 custom Dataverse tables, columns, relationships | `solutions/` (schema only) |
| **E-Signature Config** (`ESignatureConfig`) | 5 environment variables (API credentials, URLs) | `solutions/ESignatureConfig/` |
| **E-Signature Broker** (`ESignatureBroker`) | 10 Power Automate cloud flows | `solutions/ESignatureBroker/` |
| **E-Signature Client** (`ESignatureClient`) | Sample flows for client environments | `solutions/ESignatureClient/` |

**Import order:** Schema > Config > Broker (each depends on the previous). The Client solution is installed separately in client environments.

## Repository Structure

```
solutions/          Dataverse solution source (pac unpack format)
releases/           Solution zip files (managed + unmanaged)
  broker/           ESignatureBroker releases
  client/           ESignatureClient releases
  config/           ESignatureConfig releases
  schema/           Nintex Schema releases
installer/          .NET CLI installer (source + platform binaries)
power-pages/        Power Pages site configuration
word-addin/         Word Add-in for template authoring
scripts/            Shell scripts for deployment and diagnostics
docs/               Architecture and integration guides
connectors/         OpenAPI/Swagger connector definitions
```

## Broker Flows

| Flow | Trigger | Action |
|---|---|---|
| **Prepare Envelope** | statuscode = Preparing (717640001) | Submits to Nintex API, sets status to In Process |
| **Send Envelope** | statuscode = Ready to Send (717640002) | Submits prepared envelope to Nintex API |
| **Cancel Envelope** | cs_iscancelled = true | Cancels via Nintex API |
| **Status Sync** | Recurrence (30 min) | Polls Nintex for status updates |
| **Get Signing Links** | statuscode = In Process (717640003) | Retrieves signing URLs |
| **Get Access Links** | statuscode = Completed (717640004) | Creates access link records |
| **Get Envelope History** | cs_requesthistory = true | Fetches history from Nintex |
| **Get Document Content** | cs_requestsignedcopy = true | Downloads signed documents |
| **Send Signer Reminder** | cs_sendreminder = true | Sends reminder via Nintex API |
| **Sync Templates** | Recurrence (daily) | Syncs template list from Nintex |

## Envelope Lifecycle

```
Draft (1) --> Preparing (717640001) --> In Process (717640003) --> Completed (717640004)
                                                               \-> Cancelled (717640006)
                                                               \-> Error (717640005)
```

## Quick Start

### Prerequisites
- Power Platform environment with Dataverse
- Nintex AssureSign account with API credentials
- PAC CLI (`pac`)

### Deploy
1. Import solutions in order: Schema > Config > Broker
2. Set environment variables in ESignatureConfig (API credentials, URLs)
3. Configure connection references
4. Activate broker flows

### Test API Connectivity
```bash
# Run the API test suite (reads credentials from .env)
./scripts/test-nintex-api.sh
```

### Pack Solutions
```bash
pac solution pack --zipFile output.zip --folder solutions/ESignatureBroker --processCanvasApps false
```

## Environment Variables

| Variable | Purpose |
|---|---|
| `cs_NintexApiUsername` | Nintex API username |
| `cs_NintexApiKey` | Nintex API key |
| `cs_NintexContextUsername` | User impersonation context |
| `cs_NintexAuthUrl` | Auth endpoint (default: `https://account.assuresign.net/api/v3.7`) |
| `cs_NintexApiBaseUrl` | API base URL (default: `https://ca1.assuresign.net/api/documentnow/v3.7`) |
| `cs_BrokerServiceEnvironment` | Client solution: broker Dataverse environment URL |

## Documentation

See the `docs/` folder for detailed guides:
- [Broker Admin Guide](docs/broker-admin-guide.md)
- [Client Integration Guide](docs/client-integration-guide.md)
- [Custom Connector Guide](docs/custom-connector-guide-v2.md)
- [Solution Architecture (SADD)](docs/sadd-v2.md)

## License

See [LICENSE](LICENSE).
