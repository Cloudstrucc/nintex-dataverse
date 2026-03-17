# CLAUDE.md — Project Instructions for Nintex AssureSign Broker Service

## Overview

This project implements a **Nintex AssureSign e-signature broker service** built on the **Power Platform** (Power Automate, Power Pages, Dataverse). The broker sits between client environments and the Nintex AssureSign API, managing all e-signature transaction state in Dataverse.

---

## Solution Architecture

### Three-Solution Design

The broker is split into three Dataverse solutions, all using publisher prefix **`cs`** (CustomizationOptionValuePrefix: `71764`):

| Solution | Unique Name | Purpose | Contents |
|---|---|---|---|
| **Nintex Schema** | `nintex` | Entity definitions | 16 custom tables, columns, relationships, statuscode values |
| **E-Signature Config** | `ESignatureConfig` | Environment variables | 5 env vars (API credentials, URLs) |
| **E-Signature Broker** | `ESignatureBroker` | Automation | 10 Power Automate cloud flows |

**Import order matters:** Schema → Config → Broker (each depends on the previous).

### Client Solution (Distributed Separately)

| Solution | Unique Name | Purpose |
|---|---|---|
| **E-Signature Client** | `ESignatureClient` | Sample flows for clients to CRUD broker records from their own environment |

The client solution contains no tables — only reference flows that connect to the broker environment's Dataverse tables via a cross-environment connection reference.

### Security Role

| Role | Purpose |
|---|---|
| **E-Signature Broker User** | Grants CRUD on broker tables only — assigned to app users or Entra users in the broker environment |

---

## Dataverse Tables

### Core Broker Tables

#### cs_envelope (Envelopes) — Hub Entity
The central entity for signature requests. All other entities relate back to this.

**Key columns:** cs_envelopeid (PK), cs_name, cs_subject, cs_message, cs_templateid, cs_preparedenvelopeid, cs_processingmode, cs_daystoexpire, cs_reminderfrequency, cs_responsebody, cs_requestbody, cs_requesthistory (bit), cs_iscancelled (bit), cs_sentdate, cs_completeddate, cs_cancelleddate, cs_expirationdate, cs_callbackurl, cs_redirecturl

**Envelope statuscode values (statecode=0 Active):**
| Value | Label (EN) | Label (FR) |
|---|---|---|
| 1 | Draft | Brouillon |
| 717640001 | Preparing | En préparation |
| 717640002 | Ready to Send | Prêt à envoyer |
| 717640003 | In Process | En cours |
| 717640004 | Completed | Terminé |
| 717640005 | Error | Erreur |
| 717640006 | Cancelled | Annulé |
| 717640007 | Cancel Error | Erreur d'annulation |
| 2 | Inactive (statecode=1) | Inactif |

**Envelope lifecycle:** Draft → Preparing → Ready to Send → In Process → Completed/Cancelled/Error

#### cs_signer (Signers)
**Key columns:** cs_signerid (PK), cs_fullname, cs_email, cs_signerorder (int), cs_authenticationtype, cs_language, cs_signerstatus, cs_signeddate, cs_signinglink, cs_sendreminder (bit), cs_envelopelookup (lookup→Envelope)

**Signer statuscode values:**
| Value | Label |
|---|---|
| 1 | Pending |
| 717640001 | Signed |
| 717640002 | Declined |
| 717640003 | Delegated |
| 2 | Inactive |

#### cs_document (Documents)
**Key columns:** cs_documentid (PK), cs_filename, cs_filecontent (base64), cs_signedcontent (base64), cs_documentorder (int), cs_requestsignedcopy (bit), cs_envelopelookup (lookup→Envelope)

#### cs_template (Templates)
**Key columns:** cs_templateid (PK), cs_name, cs_description, cs_isactive (bit), cs_templatejson, cs_category

#### cs_accesslink (Access Links)
**Key columns:** cs_accesslinkid (PK), cs_linkurl, cs_linktype, cs_signerid, cs_expiresat, cs_envelopelookup (lookup→Envelope)

#### cs_envelopehistory (Envelope Histories)
**Key columns:** cs_envelopehistoryid (PK), cs_eventtype, cs_eventdate, cs_description, cs_username, cs_ipaddress, cs_envelopelookup (lookup→Envelope)

### Supporting Tables

| Table | Purpose |
|---|---|
| cs_authtoken | Cached Nintex API auth tokens |
| cs_webhook | Inbound webhook event payloads |
| cs_apirequest | API call audit log |
| cs_useraccount | Nintex user account references |
| cs_field | Signature/form field definitions |
| cs_senderinput | Template sender input parameters |
| cs_emailnotification | Email notification configuration |
| cs_digitalsignature | Standalone digital signature requests |
| cs_assuresign | Legacy AssureSign integration entity |
| cs_item | Utility/test entity |

---

## Broker Flows

All 10 flows use the **Microsoft Dataverse** connector (`shared_commondataserviceforapps`) with connection reference `cs_sharecommondataserviceforapps`.

| Flow | Trigger | Action |
|---|---|---|
| **Prepare Envelope** | Envelope statuscode → 717640001 (Preparing) | Calls Nintex API to prepare, sets statuscode → 717640002 (Ready to Send) |
| **Send Envelope** | Envelope statuscode → 717640002 (Ready to Send) | Submits to Nintex API, sets statuscode → 717640003 (In Process) |
| **Cancel Envelope** | cs_iscancelled = true | Cancels via Nintex API, sets statuscode → 717640006 (Cancelled) |
| **Status Sync** | Recurrence (30 min) | Polls Nintex for In Process envelopes, updates statuscode + signer statuses |
| **Get Signing Links** | Envelope statuscode → 717640003 (In Process) | Retrieves signing URLs, updates signer records |
| **Get Access Links** | Envelope statuscode → 717640004 (Completed) | Creates access link records for completed envelopes |
| **Get Envelope History** | cs_requesthistory = true | Fetches history from Nintex, creates history records |
| **Get Document Content** | Document cs_requestsignedcopy = true | Downloads signed document content |
| **Send Signer Reminder** | Signer cs_sendreminder = true | Sends reminder via Nintex API |
| **Sync Templates** | Recurrence (daily) | Syncs template list from Nintex API |

### Flow Technical Notes

- **Entity names in triggers** use singular logical name: `cs_envelope`, `cs_signer`, `cs_document`
- **Entity names in actions** use plural entity set name: `cs_envelopes`, `cs_signers`, `cs_documents`, `cs_templates`, `cs_accesslinks`, `cs_envelopehistories`
- **`subscriptionRequest/filteringattributes`** must be set to prevent infinite trigger loops (e.g., `"statuscode"` for status-triggered flows)
- **Environment variables** are read via `ListRecords` on `environmentvariabledefinitions` with `$expand` to get current values
- **Statuscode values** are integers (not strings) — use `717640001` not `"Preparing"`

---

## Environment Variables (ESignatureConfig solution)

| Schema Name | Purpose |
|---|---|
| cs_NintexApiUsername | Nintex API username |
| cs_NintexApiKey | Nintex API key |
| cs_NintexContextUsername | Nintex context username (user impersonation) |
| cs_NintexAuthUrl | Auth endpoint (default: `https://account.assuresign.net/api/v3.7`) |
| cs_NintexApiBaseUrl | API base URL (default: `https://ca1.assuresign.net/api/documentnow/v3.7`) |

---

## Authoritative Documentation Sources

### Power Platform
* Overview: https://learn.microsoft.com/en-us/power-platform/
* Admin & governance: https://learn.microsoft.com/en-us/power-platform/admin/

### Power Automate
* Cloud flows: https://learn.microsoft.com/en-us/power-automate/
* HTTP connector / custom connectors: https://learn.microsoft.com/en-us/connectors/custom-connectors/
* Flow expressions (fx): https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference

### Dataverse
* Web API reference: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/overview
* Table/column schema: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/entity-metadata
* SDK for .NET: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/overview
* Security roles: https://learn.microsoft.com/en-us/power-platform/admin/security-roles-privileges
* Cross-environment connections: https://learn.microsoft.com/en-us/power-automate/connection-references

### Power Pages
* Developer docs: https://learn.microsoft.com/en-us/power-pages/

### Solution Management & ALM
* Solution concepts: https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm
* Managed vs unmanaged: https://learn.microsoft.com/en-us/power-platform/alm/managed-unmanaged-solutions
* Solution patches & clones: https://learn.microsoft.com/en-us/power-platform/alm/update-solutions-alm

### PAC CLI
* Full CLI reference: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/
* `pac solution` commands: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution
* `pac auth` commands: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth

---

## PAC CLI — Standard Workflow

### Authentication
```bash
pac auth create --environment <env-url> --applicationId <app-id> --clientSecret <secret> --tenant <tenant-id>
pac auth create --environment <env-url>   # interactive
pac auth list
pac auth select --index <n>
```

### Solution Management
```bash
pac solution pack --zipFile <output.zip> --folder <source-folder> --processCanvasApps false
pac solution unpack --zipFile <input.zip> --folder <output-folder>
pac solution import --path <solution.zip> --publish-changes --activate-plugins
pac solution export --name <solution-name> --path <output-path> --managed
pac solution check --path <solution.zip> --outputDirectory <results-dir>
```

---

## Development Standards

### Flow JSON Conventions
- Always use **logical names** for entities — never display names
- Triggers: singular logical name (`cs_envelope`)
- Actions: plural entity set name (`cs_envelopes`)
- Statuscode values are **integers** — use the `71764xxxx` prefix values
- Include `subscriptionRequest/filteringattributes` on all webhook triggers that update the same entity
- Environment variable values read via `$expand=environmentvariabledefinition_environmentvariablevalue`

### Solution Versioning
- Source folder stays at the original name (e.g., `ESignatureBroker_1_0_0_38/`)
- Version is bumped in `Other/Solution.xml` before each repack
- Zip filename includes the version number (e.g., `ESignatureBroker_1_0_0_43_unmanaged.zip`)
- Installer `Program.cs` version references must be updated to match

### What NOT to Do
- Do not use display names for entities in flow JSON (e.g., "Envelopes" — use `cs_envelopes`)
- Do not use `_local` suffixed column names — they don't exist in Dataverse API responses
- Do not hardcode credentials — use Environment Variables
- Do not deploy unmanaged solutions to non-dev environments
- Do not install the client solution in the broker environment
- Do not use deprecated `Common Data Service` connector — use **Microsoft Dataverse** connector
- Do not use string values for statuscode — always use integer values
