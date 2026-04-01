# E-Signature Client — Quick Test Guide

## Prerequisites

- Client solution (v1.0.0.14+) imported and flows activated
- Broker solution (v1.0.0.48+) imported and flows activated
- `cs_BrokerServiceEnvironment` set to broker URL
- `cs_esignbrokerconnection` pointing to broker environment
- At least one template synced (run **ESign - Sync Templates** in broker if needed)

## Test Steps

### 1. List Templates

Run **Sample - List Templates** (no inputs).

**Expected:** Array with at least one template. Copy the `cs_templateid` value for the next step.

### 2. Create and Send Envelope

Run **Sample - Create and Send Envelope** with:

| Input | Example Value |
|---|---|
| Envelope Subject | `Test Envelope` |
| Signer Full Name | `Your Name` |
| Signer Email | `your@email.com` |
| Template ID | _(from step 1)_ |
| Message | `Please sign this test document` |

**Expected:** Flow succeeds. Copy the `cs_envelopeid` from the **Create_Envelope** action output (expand it in run history). This is the **Dataverse row ID** — not the Nintex ID.

**Important:** `cs_envelopeid` (Dataverse row ID) ≠ `cs_preparedenvelopeid` (Nintex ID). Always use `cs_envelopeid` when referencing envelopes in client flows.

### 3. Check Envelope Status

Run **Sample - Check Envelope Status** with:

| Input | Value |
|---|---|
| Envelope ID | _(cs_envelopeid from step 2)_ |

**Expected:** Envelope with `statuscode = 717640003` (In Process). Signers list shows your signer with a `cs_signinglink` URL.

### 4. Verify Signer Email

Check the signer's inbox for an email with subject containing your envelope subject.

### 5. Cancel Envelope

Run **Sample - Cancel Envelope** with the same envelope ID.

**Expected:** Flow succeeds. Re-run Check Envelope Status — `statuscode` should be `717640006` (Cancelled).

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| List Templates returns empty | Sync Templates hasn't run | Run **ESign - Sync Templates** manually in broker |
| Create Envelope fails | Wrong connection reference | Verify `cs_esignbrokerconnection` targets broker env |
| Check Status says "Does Not Exist" | Using wrong ID | Use `cs_envelopeid` (Dataverse row ID), not `cs_preparedenvelopeid` (Nintex ID) |
| Broker flow doesn't trigger | statuscode not set properly | Check Create and Send flow's `Set_Envelope_To_Preparing` action succeeded |
| Signer email has generic subject | Old broker version | Import broker v1.0.0.48+ and reactivate Prepare Envelope flow |
