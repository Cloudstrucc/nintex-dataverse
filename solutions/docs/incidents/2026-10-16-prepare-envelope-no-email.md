# 2026-10-16 — Envelopes stuck at "Preparing", no signer email

## Symptom
Two envelopes created in dev (`Fred` 23:56, `Chzkc` 00:00) never produced a signer email and sat
at **Preparing** indefinitely, with `cs_preparedenvelopeid` null and `cs_responsebody` empty.

## Cause
`ESign - Prepare Envelope` **failed** on both runs, so the envelope was never submitted to
AssureSign. AssureSign is what sends the signer email, so nothing was ever sent.

It failed *silently* because `Update_Envelope_Error` was wired as
`runAfter: HTTP_Submit_Envelope [Failed, TimedOut]` — it only caught a failure of the **submit**
step. A failure anywhere earlier (auth, template fetch, signer list, values array) left the record
at Preparing with nothing written. The empty `cs_responsebody` is itself the evidence that the
failure happened *before* the submit step.

Ruled out by replaying the flow's own calls against the live dev environment-variable values:
Nintex auth `POST /authentication/apiUser` → **200**; `GET /templates/{id}` → **200**.

## Fixes applied (dev)

1. **Scoped error handler on `ESign - Prepare Envelope`.** All work actions now sit in a
   `Try_Scope`; `Update_Envelope_Error` runs after `Try_Scope [Failed, TimedOut]`, so **any**
   failing step now marks the envelope **Error (717640005)** and writes the full scope result into
   `cs_responsebody` via `result('Try_Scope')` (truncated to 8000 chars).
   - `runAfter` with several predecessors is **AND**, not OR, so a scope is the only way to catch
     "any step failed".
   - `InitializeVariable` **cannot be nested in a scope**, so the three initializers stay at top
     level. `Initialize_ValuesArray` seeded from `Get_Envelope_Record`, which is now inside the
     scope, so it initializes to `json('[]')` and the seeding moved into the scope as
     `Set_ValuesArray_Seed` (SetVariable) in the same position. Dependency order is unchanged.

2. **Deactivated `ESign - Get Signing Links`.** It was failing **100%** (2,473 runs/24h).
   Root cause: it iterates the signing links returned by Nintex (which returns **200** fine) and
   updates a matching `cs_signer` row — but ad-hoc envelopes have **no signer rows**, so the update
   gets a null record id and the flow dies. Left **Draft** deliberately so it cannot mass-fire
   across the 181 In Process envelopes when it is fixed; re-enable only after a controlled test.
   Note it sends **no email** — it is a read-only `GET …/signingLinks` plus a signer-row update.

3. **Cleared the stale `cs_statuscheckrequestedon` backlog** — 335 envelopes, some stamped as far
   back as 2026-07-29. Only that one field was written; `statuscode` was deliberately left
   untouched so nothing could be re-submitted. Prior values backed up before clearing.

Result: flow runs went from ~20 per 5 min (11 failing) to ~4 per 5 min, all succeeding.

## Still open
- **Who bulk-stamps `cs_statuscheckrequestedon`**: ~20 envelopes get stamped on the exact
  half-hour (`07:00:00`, `07:30:00`). No activated flow in dev or fp-01 does this. The two flows
  that write the field (`Sample - Check Envelope Status`, `SAMPLE - Verify & Update Envelope
  Status`) are **manual/Request** triggers using the cross-environment
  `UpdateRecordWithOrganization`, so the caller is in another environment or an external scheduler.
  With the backlog cleared and Get Signing Links off this is now benign polling, but worth tracing.
- **`ESign - Get Signing Links` needs its null-signer guard** before being reactivated.
- **`ESign - Cancel Envelope` is in Draft** in dev — unclear whether intentional.
- The two stuck envelopes were **left as-is**. Retrying them means setting `statuscode` back to
  Preparing, which would really submit and really email, so that is a deliberate decision.

## Useful queries
Flow run history is in the Dataverse **`flowrun`** table (run-level only; action-level detail needs
the maker portal — the Power Automate API rejects app-only auth with `ClientScopeAuthorizationFailed`):

```
flowruns?$select=starttime,status,errorcode,errormessage,workflowid&$orderby=starttime desc
```
