# Capturing the signer "decline reason / feedback" from Nintex eSign (AssureSign)

**Question (client):** When a signer clicks **Decline signing** and types feedback (the *"Feedback or Comments"* box), how do we pick that text up from the Nintex/AssureSign API and land it in a Dataverse/CRM table?

**Status:** research + plan only — nothing implemented yet. Verified live against the EC **sandbox** (`sb.assuresign.net`, DocumentNOW **v3.7**) using the broker's own API credentials.

---

## 1. Where the decline feedback lives in the AssureSign API

AssureSign DocumentNOW **does not** return a clean, dedicated `declineReason` field on the signatory object. The signer's decline + feedback is recorded in the **envelope audit history**, and the decline *state* shows up in the **status** call. Two endpoints matter (the broker already calls both):

### a) `GET /envelopes/{preparedEnvelopeId}/history`  ← the reason lives here
Live shape (verified):
```json
{
  "envelopeID": "4ab439d5-…",
  "envelopeHistoryEvents": [
    { "id": "…", "date": "2026-10-09T04:28:33.877",
      "details": "Envelope created by user 'ECSign Dev Service Account (svc-…@elections.ca)' at IP '4.248.98.162'" },
    { "id": "…", "date": "…", "details": "Email 'Document available to sign' sent to 'fpearson' (fpearson613@gmail.com) …" },
    { "id": "…", "date": "…", "details": "Envelope visited by 'fpearson613@gmail.com' at IP '99.219.224.115' …" }
    // …a Decline produces a further event here whose `details` carries the decline + the typed feedback
  ],
  "documentList": [ { "history": [ { "id": "…", "date": "…", "details": "…" } ] } ]
}
```
Each event is `{ id, date, details }`, where **`details`** is a human‑readable audit string. A decline adds an event (and/or a document‑level history entry) whose `details` records the decline and the signer's feedback text.

### b) `GET /envelopes/{preparedEnvelopeId}/status`  ← the decline *state*
```json
{ "result": {
    "envelopeID": "…", "status": "iN_PROGRESS",
    "documentList": [ { "status": { "statusType": "signinG_STEP_PROGRESS", "statusDetails": "Step 1" },
                        "documentID": "…", "name": "…CCCS Security Assessment….pdf" } ] } }
```
On a decline, envelope `status` becomes the declined value and the document `status.statusType`/`statusDetails` reflect it. `statusDetails` is a short string (e.g. "Step 1" today) and may carry a brief decline note, but the **full feedback text is in the history `details`, not here**.

> ⚠️ **One field still to pin down exactly:** no envelope in the sandbox is currently in a *declined* state (the CCCS envelope the client screenshotted still reads `iN_PROGRESS` — the decline form was shown but not submitted). The **exact wording/placement** of the decline event's `details` (and whether the feedback is one event or a separate "signer feedback" event) should be confirmed against **one real submitted decline**. I can grab the precise string the moment a decline is actually completed.

---

## 2. What the broker does today (and a gap to fix)

| Flow | Endpoint | Today |
|---|---|---|
| **ESign‑StatusSync** / **ESign‑CheckEnvelopeStatus** | `/envelopes/{id}/status` | Normalises envelope status → `cs_envelope.statuscode` (already maps a **`declined`** → `717640005`‑style code) and updates signer statuses. Does **not** capture any reason. |
| **ESign‑GetEnvelopeHistory** | `/envelopes/{id}/history` | Intended to write `cs_envelopehistory` rows (`cs_eventtype`, `cs_eventdate`, `cs_description`, `cs_username`). |

**Gap found:** `ESign‑GetEnvelopeHistory` parses `@body(...)?['result']` with `eventType / eventDate / description / userName`, but the live v3.7 response is `envelopeHistoryEvents[]` with **`id / date / details`** (no `result`, no `eventType`). So the flow's mapping doesn't match the API and currently captures nothing (there are **0** `cs_envelopehistory` rows in dev). This must be aligned before history — including decline feedback — can be ingested.

---

## 3. Recommended implementation (broker side)

**A. Fix `ESign‑GetEnvelopeHistory` to the real schema.** Iterate `envelopeHistoryEvents` (and `documentList[].history`), mapping `date → cs_eventdate`, `details → cs_description`, and derive `cs_eventtype` by inspecting `details` (e.g. contains "declined"/"feedback"/"visited"/"signed").

**B. Add a first‑class decline field (recommended for the client).** On `ESign‑StatusSync` / `ESign‑CheckEnvelopeStatus`, when the normalised status is **declined**, call the history endpoint, find the decline/feedback event, and store the reason on a new column:
- `cs_envelope.cs_declinereason` (memo) — the simplest thing for the client to read, and/or
- `cs_signer.cs_declinereason` (memo) + `cs_signer.cs_declineddate` if you need it per‑signer (the `details` string names the signer's email, so it can be attributed).

Keeping the full audit trail in `cs_envelopehistory` as well (from fix **A**) gives traceability; the dedicated `cs_declinereason` gives the client one obvious field to map.

**C. Confirm the parse** against one real decline, then finalise the string extraction (regex/substring of `details`).

---

## 4. What to tell the client (CRM mapping)

The client solution reads the broker's Dataverse over the cross‑environment connection. Give them **one** of these to map into their CRM table:

- **Preferred:** `cs_envelope.cs_declinereason` — a single memo field, populated by the broker when a signer declines. One‑to‑one map into their CRM "decline reason" column. (Needs broker change **B**.)
- **Alternative (no new field):** the `cs_envelopehistory` row for that envelope where `cs_eventtype` = *declined/feedback* → use `cs_description`. (Needs broker change **A** so history is captured at all.)

Either way, the client keys off `cs_envelope` (via `cs_preparedenvelopeid` / the envelope GUID they already track) and pulls the reason field when `statuscode` = **Declined**.

---

## 5. Suggested next step

Have a signer actually **submit** a decline (with feedback) on a sandbox envelope. I'll pull that envelope's `/history` and show the exact `details` string, which pins down the parse and confirms whether the feedback is in the envelope history, the document history, or `statusDetails`. Then changes **A/B** are a small, well‑scoped update to two broker flows plus one or two columns — no client‑side change beyond mapping the field.
