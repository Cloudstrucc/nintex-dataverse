# E-Signature Client — Integration Guide

## Overview

The **E-Signature Client** solution provides sample Power Automate flows that connect your Dataverse environment to the centralized E-Signature Broker Service. The broker handles all Nintex AssureSign API communication — your flows simply create records in the broker's Dataverse, and the broker flows process them automatically.

### How It Works

```
Your Environment                          Broker Environment
────────────────                          ──────────────────
1. Create envelope record ──────────────> cs_envelope created (Draft)
2. Create signer record(s) ─────────────> cs_signer created
3. Set status to Preparing ─────────────> statuscode = 717640001
                                          ↓
                                          Broker flow triggers automatically
                                          ↓
                                          Nintex API: submit envelope
                                          ↓
                                          Status updated to In Process
                                          Signing links generated
                                          Signer receives email
```

You never call the Nintex API directly. The broker does all the work.

---

## Installation

### Step 1: Import the Client Solution

Import into your Dataverse environment:
```
solutions/releases/client/ESignatureClient_1_0_0_14_unmanaged.zip
```

Or use the managed version for production:
```
solutions/releases/client/ESignatureClient_1_0_0_14_managed.zip
```

### Step 2: Set the Environment Variable

During import (or after), set **Broker Service Environment** (`cs_BrokerServiceEnvironment`) to the broker's Dataverse URL:
```
https://goc-wetv14.crm3.dynamics.com
```
(Replace with your actual broker environment URL.)

### Step 3: Configure the Connection Reference

The solution includes connection reference `cs_esignbrokerconnection`. Configure it with a **Microsoft Dataverse** connection that targets the broker environment.

**Important:** The user or service account running the flows must have the **E-Signature Broker User** security role assigned in the broker environment.

### Step 4: Activate the Flows

Turn on the sample flows you want to use. All flows are shipped in an off state.

---

## Sample Flows

### Sample - List Templates

**Trigger:** Button (no inputs)

**What it does:** Queries the broker's `cs_templates` table and returns all available e-signature templates with their name, description, and template ID.

**Use this to:** Discover which template IDs are available before creating envelopes.

**Test:** Run the flow and check the output of the `List_Templates` action — you should see an array of template records.

---

### Sample - Create and Send Envelope

**Trigger:** Button with inputs:
- Envelope Subject (required)
- Signer Full Name (required)
- Signer Email (required)
- Template ID (required)
- Message (optional)

**What it does:**
1. Creates an envelope record in the broker environment (Draft status)
2. Creates a signer record linked to the envelope
3. Sets the envelope status to Preparing (`717640001`)

**What happens next (automatically in the broker):**
- The broker's **Prepare Envelope** flow triggers
- It fetches the template from Nintex to get the signer placeholder names
- It submits the envelope to Nintex API
- Status becomes In Process, signing links are generated
- The signer receives an email with their signing link

**Test:**
1. Run **Sample - List Templates** first to get a valid template ID
2. Run this flow with a real email address
3. Run **Sample - Check Envelope Status** to verify status = In Process
4. Check the signer's email inbox for the signing link

---

### Sample - Create Draft Envelope

**Trigger:** Button with inputs:
- Envelope Subject (required)
- Template ID (required)
- Message (optional)
- Days to Expire (optional, defaults to 30)

**What it does:** Creates an envelope in Draft status only. Use this when you need to add multiple signers or documents before triggering submission.

**Next steps after running:** Use **Sample - Add Signer to Envelope** to add signers, then manually update the envelope's statuscode to `717640001` (Preparing) to trigger submission.

---

### Sample - Add Signer to Envelope

**Trigger:** Button with inputs:
- Envelope ID (required) — the `cs_envelopeid` GUID
- Signer Full Name (required)
- Signer Email (required)
- Signer Order (required) — 1, 2, 3...

**What it does:** Creates a signer record linked to the specified envelope via OData bind.

**Note:** The signer order must match the template's signer positions. Signer 1 maps to the first signer defined in the Nintex template, Signer 2 to the second, etc.

---

### Sample - Check Envelope Status

**Trigger:** Button with input:
- Envelope ID (required)

**What it does:**
1. Retrieves the envelope record from the broker
2. Lists all signers for this envelope (ordered by signer order)
3. Lists all documents for this envelope

**Use this to:** Check the current status, see signing links, and verify signer/document records.

**Status values:**
| statuscode | Label |
|---|---|
| 1 | Draft |
| 717640001 | Preparing |
| 717640002 | Ready to Send |
| 717640003 | In Process |
| 717640004 | Completed |
| 717640005 | Error |
| 717640006 | Cancelled |

---

### Sample - Cancel Envelope

**Trigger:** Button with input:
- Envelope ID (required)

**What it does:**
1. Reads the envelope to check if status is In Process (717640003)
2. If cancellable, sets `cs_iscancelled` to `true`
3. The broker's **Cancel Envelope** flow triggers automatically and cancels via the Nintex API

**Note:** Only envelopes with status In Process can be cancelled.

---

## Building Your Own Flows

The sample flows demonstrate the patterns — use them as templates for your own integrations.

### Key Patterns

**Creating records in the broker environment:** All Dataverse actions use `CreateRecordWithOrganization` or similar `WithOrganization` operations, with the `organization` parameter set to the `cs_BrokerServiceEnvironment` environment variable.

**Triggering the broker:** Set the envelope's `statuscode` to `717640001` (Preparing). The broker's Prepare Envelope flow will handle everything from there.

**Setting lookups:** Use OData bind syntax to link signers to envelopes:
```json
"cs_EnvelopeLookup@odata.bind": "/cs_envelopes(<envelope-id>)"
```

**Reading results:** Use `GetItemWithOrganization` or `ListRecordsWithOrganization` to read records from the broker environment.

### Example: Multi-Signer Envelope

```
1. Create envelope (Draft)
2. Add Signer 1 (order: 1)
3. Add Signer 2 (order: 2)
4. Add Signer 3 (order: 3)
5. Update envelope statuscode to 717640001 (Preparing)
   → Broker submits to Nintex with all 3 signers
```

### Example: Monitor Envelope Completion

```
1. Create a scheduled flow (every 30 min)
2. List envelopes where statuscode = 717640003 (In Process)
3. For each, check if statuscode has changed to 717640004 (Completed)
4. If completed, trigger your business logic (update CRM, notify user, etc.)
```

---

## Troubleshooting

### Flow fails with "The specified environment was not found"

The `cs_BrokerServiceEnvironment` environment variable has the wrong URL. Verify it matches the broker's Dataverse environment URL exactly (include `https://`).

### 404 "File or directory not found" or "The response is not in a JSON format"

This means the Dataverse API gateway is routing the request to the **client** environment instead of the broker. The `organization` parameter in the flow only works if the underlying **connection** has access to the broker environment.

**Fix:**
1. Go to **Solutions** > **E-Signature Client** > **Connection References**
2. Click `cs_esignbrokerconnection`
3. Set it to a Dataverse connection authenticated with a user who has access to the **broker** environment
4. **Turn off** the affected flow, then **turn it back on** — this re-binds all actions to the connection reference

**Important:** Never manually create new connections per-action inside the flow editor. This overrides the solution's connection reference and causes actions to target the wrong environment. Always set the connection at the **connection reference** level.

### Environment variable value not being used

If the `cs_BrokerServiceEnvironment` environment variable has a **Default Value** but no **Current Value**, the flow may not resolve it at runtime.

**Fix:**
1. Go to **Solutions** > **Default Solution** > **Environment Variables**
2. Find **Broker Service Environment** (`cs_BrokerServiceEnvironment`)
3. Click it > under **Current Value**, click **+ New value**
4. Enter the broker URL (e.g., `https://goc-wetv14.crm3.dynamics.com`)
5. Save

### "Entity 'cs_envelope' With Id = ... Does Not Exist"

You are passing the wrong ID. The client flows use two different IDs:

| Field | What It Is | When to Use |
|---|---|---|
| `cs_envelopeid` | Dataverse row ID (primary key) | Use this in all client flows (Check Status, Cancel, Add Signer) |
| `cs_preparedenvelopeid` | Nintex envelope ID (returned by API) | Do NOT use this in client flows — it's for broker-to-Nintex communication only |

To get the correct `cs_envelopeid`: open the **Create and Send Envelope** flow run history, expand the **Create_Envelope** action output, and copy the `cs_envelopeid` value.

### Flow runs but no broker flow triggers

Verify that:
1. The envelope's `statuscode` was actually set to `717640001`
2. The broker's **Prepare Envelope** flow is turned on
3. The `statuscode` field is being updated using flat parameter form (`item/statuscode`) not nested object form

### "Sample - List Templates" returns empty

The broker's **Sync Templates** flow runs daily. If no templates appear, run Sync Templates manually in the broker environment, or verify the Nintex API credentials are set correctly.

### Signer not receiving signing email

1. Run **Check Envelope Status** to verify status is In Process
2. Check the signer record's `cs_signinglink` field — if empty, the **Get Signing Links** broker flow may have failed
3. Check the signer's spam/junk folder
4. Verify the email address is correct

### Signer email has generic subject/body instead of custom subject

Import broker solution **v1.0.0.48 or later** and reactivate the **Prepare Envelope** flow. Earlier versions did not pass the envelope subject to the Nintex API, so Nintex used its default email template.

---

## Security

- The client solution contains **no tables** — it only creates records in the broker's environment via cross-environment connection
- The connection reference `cs_esignbrokerconnection` must target the broker environment
- The service account needs the **E-Signature Broker User** role in the broker environment
- API credentials are stored in the broker's environment variables — clients never see them
