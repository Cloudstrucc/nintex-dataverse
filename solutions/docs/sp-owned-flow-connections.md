# Running broker flows as the service principal (no personal account)

## Why

Every ESign flow was bound to the connection reference `cs_sharecommondataserviceforapps`
("Dataverse (Current Environment)"), whose **connection is owned by a real user** — in dev,
`CloudAdmin Pearson Fredrick`. Two consequences:

1. **The flows executed with that person's Dataverse privileges**, not the service principal's.
   If that account is disabled or its rights change, the broker changes behaviour.
2. **Automation could not turn a flow on.** Power Automate refuses activation unless the
   activating principal can use the flow's connection:

   ```
   ConnectionAuthorizationFailed: Connection 'cs_sharecommondataserviceforapps' cannot be used
   to activate this flow ... have the connection owner activate the flow
   ```

   This is a correct guardrail, not a quirk: enabling a flow means "start executing with these
   credentials", so letting principal A enable a flow that runs as principal B would be a
   confused-deputy escalation. The check is on the **connection**, not the flow record — which is
   exactly why changing `workflow.ownerid` does not help.

## The fix

Create a Dataverse connection that **authenticates as the service principal**, and point the
flows' connection reference at it. Then the flows run as the SP, and the SP can activate them.

This is fully automatable — no maker-portal step and no human identity involved.

```bash
# 1. Create an SP-authenticated Dataverse connection (pac is authed app-only as the same SP)
pac connection create \
  --environment https://dev-ec-esign-01.crm3.dynamics.com \
  --tenant-id "$EC_TENANT_ID" \
  --name "ESign Broker SP (Dataverse)" \
  --application-id "$EC_CLIENT_ID" \
  --client-secret "$EC_CLIENT_SECRET"
# -> connection id, e.g. pac-dv-8557a033-20ae-4cd8-9ca3-1a0b9da73b1f

pac connection list    # confirm Status = Connected
```

Then create a connection reference bound to it, inside the broker solution:

```
POST /api/data/v9.2/connectionreferences      (header: MSCRM.SolutionUniqueName: ESignatureBroker)
{
  "connectionreferencelogicalname":  "cs_spdataverse",
  "connectionreferencedisplayname":  "Dataverse — ESign Broker SP",
  "connectorid": "/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps",
  "connectionid": "<connection id from pac>"
}
```

The resulting connection reference is **owned by the application user**, not a person.

Finally, repoint a flow and activate it. In `workflow.clientdata`:

```
properties.connectionReferences["shared_commondataserviceforapps"]
  .connection.connectionReferenceLogicalName  =  "cs_spdataverse"
```

then `PATCH workflow { "statecode": 1, "statuscode": 2 }` — which now succeeds, because the SP
owns the connection.

## Pilot result (dev, 2026-10-16)

`ESign - Cancel Envelope` was the pilot. It had been stuck in **Draft** precisely because nobody
had activated it and automation could not.

| Check | Result |
|---|---|
| SP activated the flow | **yes** — previously `ConnectionAuthorizationFailed` |
| Envelope In Process → after cancel request | **statuscode 8 / Cancelled, statecode 1** |
| `cs_cancelleddate` written | yes |
| **Record modified by** | **`# Nintex - E-Sign - PEPP - Dev`** (the SP, not a person) |
| AssureSign cancel succeeded | yes — `Update_Envelope_Cancelled` only runs `runAfter HTTP_Cancel_Envelope [Succeeded]` |

Backup of the pre-change flow definition: `scratchpad flowbackup/CancelEnvelope.before-sp.json`
(the only change is the `connectionReferenceLogicalName`; revert it to
`cs_sharecommondataserviceforapps` to roll back).

## Rolling out to the remaining flows

The other 12 ESign flows still use `cs_sharecommondataserviceforapps`. For each: repoint
`connectionReferenceLogicalName` to `cs_spdataverse`, then re-activate. Do it a few at a time and
confirm each still runs, because the SP's Dataverse privileges must cover everything the flow
does — the SP is a System Administrator in the EC environments, so this is expected to be a
superset of the user's rights, but it is worth verifying per flow rather than assuming.

Not yet done in **test**; test still runs on the user-owned connection.

## Note on the Power Platform admin APIs

Separately from the above, this service principal is **not** registered as a Power Platform
management application, so the BAP / PowerApps / Flow *admin* APIs reject it app-only:

```
BAP   /scopes/admin/environments   -> 403 "service principal ... does not have permission"
Flow  /scopes/admin/.../flows      -> 403 EnvironmentAccessDenied
```

That registration is a one-time tenant-admin step (`pac admin create-service-principal`, or
`New-PowerAppManagementApp`). It is **not required** for the connection rework above — that path
goes through Dataverse and `pac connection`, both of which work app-only today.


---

## Rollout procedure — order matters

Patching `clientdata` on a flow that is **currently activated** does not rebind it. The record
updates, the flow still reports Activated, but the runtime keeps the previous connection and the
Dataverse webhook trigger stays registered against it. Observed both failure modes in dev:

- repoint while Activated, then PATCH `statecode:1` (a no-op, since it was already 1) →
  **the trigger stopped firing entirely**; envelopes sat at Preparing with no run and no error.
- an off/on cycle after that made it fire again, but the run still executed as the **old**
  connection's owner.

The procedure that works, per flow:

1. `PATCH { statecode: 0, statuscode: 1 }`  — deactivate
2. `PATCH { clientdata }` with `connectionReferences["shared_commondataserviceforapps"]
   .connection.connectionReferenceLogicalName = "cs_spdataverse"` — rebind **while Draft**
3. `PATCH { statecode: 1, statuscode: 2 }`  — activate, registering the trigger against the new connection

Then allow ~a minute before testing: the webhook registration is not instant, and a record changed
in that window will not fire the trigger.

Verify by the executing identity, not by the flow's own status: read `modifiedon`/`modifiedby` on a
record the flow writes. It must come back as the application user.

## Dev rollout result (2026-10-16)

All **13** ESign flows now run on `cs_spdataverse` and are Activated. No flow that was previously
off was switched on, with one intended exception: `ESign - Cancel Envelope`, which had been stuck
in Draft because automation could not activate it.

End-to-end send verified after the rebind — envelope reached **In Process** with an AssureSign
envelope id, and the record came back **modified by `# Nintex - E-Sign - PEPP - Dev`**.

## Connection references left orphaned (dev) — review before purging

Nothing in the environment's 139 cloud flows references these any more:

| Connection reference | Display name | Owner |
|---|---|---|
| `cs_sharecommondataserviceforapps` | Dataverse (Current Environment) | CloudAdmin Pearson Fredrick |
| `cs_sharedcommondataserviceforapps_17ab1` | Microsoft Dataverse ESignatureBroker-17ab1 | CloudAdmin Pearson Fredrick |
| `cs_sharedcommondataserviceforapps_efa00` | Microsoft Dataverse ESignatureBroker-efa00 | CloudAdmin Pearson Fredrick |
| `cs_sharedcommondataserviceforapps_69ae5` | Microsoft Dataverse ESignatureBroker-69ae5 | CloudAdmin Pearson Fredrick |
| `cs_sharedcommondataserviceforapps_575e5` | Microsoft Dataverse ESignatureClient-575e5 | Fredrick Pearson |
| `cs_sharedcommondataserviceforapps_2bce1` | Microsoft Dataverse ESignatureClient-2bce1 | CloudAdmin Wang Don |
| `new_sharednew5f…_e820f` | Election Canada E-Sign ESign-e820f | CloudAdmin Pearson Fredrick |
| `new_sharednew5f…_3338e` | Election Canada E-Sign ESign-3338e | CloudAdmin Pearson Fredrick |

**Do not delete `cs_sharecommondataserviceforapps` on the strength of this list alone.** It ships
as part of the ESignatureBroker/ESignatureClient solutions, so removing it changes the solution's
connection-reference contract and will affect imports into **test** and **fp-01**, which still run
on it. Retire it there first, or keep it until those environments are migrated.

The `_17ab1 / _efa00 / _69ae5 / _575e5 / _2bce1` entries look like duplicates accumulated from
repeated solution imports and are the safest candidates to remove first.
