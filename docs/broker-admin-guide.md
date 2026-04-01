# E-Signature Broker Service — Admin Guide

## Overview

The broker service runs in a centralized Dataverse environment and handles all communication with the Nintex AssureSign API. Client environments create records in the broker's Dataverse tables, and broker flows automatically process them.

## Installation

### Prerequisites

- Power Platform environment with Dataverse
- Nintex AssureSign account with API credentials
- PAC CLI for solution packing (optional)

### Import Solutions (in order)

1. **Nintex Schema** — creates all Dataverse tables
   ```
   solutions/releases/schema/nintex_1_0_0_2_unmanaged.zip
   ```

2. **E-Signature Config** — creates environment variables
   ```
   solutions/releases/config/ESignatureConfig_1_0_0_0_unmanaged.zip
   ```

3. **E-Signature Broker** — creates the 10 automation flows
   ```
   solutions/releases/broker/ESignatureBroker_1_0_0_47_unmanaged.zip
   ```

### Configure Environment Variables

After importing ESignatureConfig, set these values in the Power Platform admin center or via the maker portal:

| Variable | Purpose | Example |
|---|---|---|
| `cs_NintexApiUsername` | API user created in Nintex portal | `my-broker-service_apdXXXXX` |
| `cs_NintexApiKey` | API key for the above user | `abc123...` |
| `cs_NintexContextUsername` | Nintex user to impersonate | `admin@company.com` |
| `cs_NintexAuthUrl` | Authentication endpoint | `https://account.assuresign.net/api/v3.7` |
| `cs_NintexApiBaseUrl` | API base URL (region-specific) | `https://ca1.assuresign.net/api/documentnow/v3.7` |

### Configure Connection Reference

The broker flows use connection reference `cs_sharecommondataserviceforapps`. Set this to a Dataverse connection authenticated against the broker environment itself.

### Activate Flows

Activate all 10 flows in Power Automate. They will begin listening for Dataverse record changes.

### Assign Security Role

Assign the **E-Signature Broker User** security role to any service accounts or users that need CRUD access to the broker tables.

---

## Broker Flows — Detailed Reference

### ESign - Prepare Envelope

**Trigger:** Envelope `statuscode` changes to `717640001` (Preparing)

**What it does:**
1. Reads the envelope record (template ID, subject, message, etc.)
2. Authenticates with Nintex API
3. Fetches template details from Nintex to get dynamic signer placeholder names (e.g., `[Recipient Name]` vs `[Signer 1 Name]`)
4. Lists all signers linked to the envelope (ordered by `cs_signerorder`)
5. Builds the `values` array by mapping each signer's fullname/email to the template's placeholder names
6. Calls `POST /submit` with `{request: {templates: [{templateID, values}]}}`
7. Stores the returned `envelopeID` in `cs_preparedenvelopeid` and `authToken` in `cs_requestbody`
8. Sets status to In Process (`717640003`)
9. On failure: sets status to Error (`717640005`) and stores response in `cs_responsebody`

### ESign - Send Envelope

**Trigger:** Envelope `statuscode` changes to `717640002` (Ready to Send)

**Note:** With the current Prepare Envelope flow going directly to In Process, this flow is a fallback path. It handles envelopes that have a `cs_preparedenvelopeid` (from a legacy prepare step) or submits fresh.

### ESign - Get Signing Links

**Trigger:** Envelope `statuscode` changes to `717640003` (In Process)

**What it does:**
1. Calls `GET /envelope/{id}/signingLinks` (note: **singular** `/envelope/`)
2. For each signing link returned, matches to the signer record by email
3. Updates the signer's `cs_signinglink` and `cs_signerstatus`

### ESign - Cancel Envelope

**Trigger:** Envelope `cs_iscancelled` changes to `true`

**What it does:**
1. Reads the envelope record
2. Authenticates with Nintex
3. Calls `PUT /envelopes/{id}/cancel` with body `{request: {authToken, remarks}}`
4. The `authToken` is read from `cs_requestbody` (stored during submit)
5. Sets status to Cancelled (`717640006`)

### ESign - Status Sync

**Trigger:** Recurrence (every 30 minutes)

**What it does:**
1. Lists all envelopes with status In Process
2. For each, calls `GET /envelopes/{id}/status`
3. Updates envelope status if changed (completed, cancelled)
4. Calls `GET /envelopes/{id}/signers` to update individual signer statuses

### ESign - Get Access Links

**Trigger:** Envelope `statuscode` changes to `717640004` (Completed)

Creates access link records (`cs_accesslink`) for completed envelopes.

### ESign - Get Envelope History

**Trigger:** Envelope `cs_requesthistory` changes to `true`

Fetches event history from Nintex and creates `cs_envelopehistory` records.

### ESign - Get Document Content

**Trigger:** Document `cs_requestsignedcopy` changes to `true`

Downloads the signed document content and stores it in `cs_signedcontent`.

### ESign - Send Signer Reminder

**Trigger:** Signer `cs_sendreminder` changes to `true`

Sends a reminder notification to the signer via Nintex API.

### ESign - Sync Templates

**Trigger:** Recurrence (daily)

Syncs the template list from Nintex API into the `cs_templates` table. Creates new records or updates existing ones by matching on `cs_templateid`.

---

## Client Onboarding

For each client environment:

1. **Import ESignatureClient solution** into the client environment
2. **Set `cs_BrokerServiceEnvironment`** to the broker's Dataverse URL
3. **Configure `cs_esignbrokerconnection`** — the client needs a Dataverse connection that can reach the broker environment
4. **Assign the E-Signature Broker User role** to the client's service account in the broker environment
5. **Test** — run the "Sample - List Templates" flow to verify connectivity

---

## Testing

### API Test Script

```bash
# From repo root — tests all 9 Nintex API endpoints
./scripts/test-nintex-api.sh
```

### End-to-End Test

1. In the client environment, run **Sample - Create and Send Envelope**
2. In the broker environment, verify the **Prepare Envelope** flow ran successfully
3. Check that the envelope status is now In Process
4. Verify the signer received a signing email

### Flow Run History

Check flow run history in Power Automate for each broker flow to diagnose issues. The `cs_responsebody` field on the envelope record stores the Nintex API response for debugging.

---

## Monitoring

### Key Fields to Monitor

| Field | Table | Meaning |
|---|---|---|
| `statuscode` | cs_envelope | Current lifecycle state |
| `cs_responsebody` | cs_envelope | Last Nintex API response (for debugging) |
| `cs_preparedenvelopeid` | cs_envelope | Nintex envelope ID |
| `cs_requestbody` | cs_envelope | Nintex authToken (needed for cancel) |
| `cs_signerstatus` | cs_signer | Per-signer signing status |
| `cs_signinglink` | cs_signer | URL the signer uses to sign |

### Common Issues

| Symptom | Cause | Fix |
|---|---|---|
| Prepare flow not triggering | Client didn't set statuscode to 717640001 | Verify client flow sets `item/statuscode: 717640001` (flat form) |
| Nintex API 401 | Expired or wrong credentials | Update environment variables in ESignatureConfig |
| Nintex API 500 on submit | Wrong request body format | Ensure body uses `{request: {templates: [{templateID, values}]}}` |
| Signing links 404 | Wrong URL path | Must use singular `/envelope/` not `/envelopes/` |
| Cancel fails | Missing authToken | Ensure `cs_requestbody` has the authToken from submit |
| Empty template list | Sync Templates hasn't run | Run the Sync Templates flow manually, or wait for daily recurrence |

---

## Security

- **Connection references** control which Dataverse environment the flows target
- **E-Signature Broker User** security role restricts access to broker tables only
- **Environment variables** store API credentials — never hardcode in flows
- **Row-level security** can be configured so clients only see their own envelope records
- Rotate Nintex API keys periodically and update the environment variables
