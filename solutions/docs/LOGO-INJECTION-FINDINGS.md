# Dynamically injecting a per-party logo into a signed document (findings + design)

**Use case (client):** different political parties each upload their own logo while
completing an online form. When they finish, their Dataverse calls the broker to
prepare + send an e-signature envelope. Each party's signer should see **their**
party logo (top-right) on the Nintex/AssureSign version of the PDF they sign.

**Scope:** this is **one** use case for one subset of users. The normal template
feature (reference a `templateID`) is unchanged and keeps working. This adds an
**opt-in** "bring your own branded PDF" path for this scenario only.

---

## 1. Is "inject an image via a template field" supported? — No

Verified against the EC sandbox (`sb.assuresign.net`, DocumentNOW **v3.7**) and the
Nintex docs:

- AssureSign has **no image / logo / graphic field type**. The field (JotBlock)
  types are Signature, Initials, Date, Timestamp, Text, Drop-down, Multiple-choice,
  and "fixed" signature/textbox. The only sender-applied *graphic* is a drawn
  **signature** — not an arbitrary image.
- A document field's `inputType` enum (`FieldInputType`) accepts **only `signer`**.
- Templates expose **no `senderInputs`** array (passing one is silently dropped).
- The "variable" control we built is a **typed** field with `signerInputType` of
  `prefill` / `free_Text` / `timestamp` — **text/data only**. An image cannot travel
  through the submit `values[]` channel (those are `{name, value}` *string* pairs,
  matched to fields by name).

**Conclusion:** you cannot push a logo image into a referenced template via an API
field. The logo must be **in the PDF bytes**.

## 2. What *is* supported — ad-hoc (dynamic) document submit

AssureSign DocumentNOW `/submit` accepts the document **inline as base64**, with no
`templateID` — you provide the `content.documents[].file.fileToUpload.data` plus the
signing `fields`, `signers`, and `steps` in the same call. This is the same `content`
shape the broker already builds when it *creates* a template, just POSTed to
`/submit` instead of `/templates`.

```
POST {apiBaseUrl}/submit
Authorization: bearer {token}
X-AS-UserContext: {contextUsername}
```
```json
{ "request": { "content": {
  "documents": [{
    "name": "Party Agreement",
    "file": { "fileToUpload": { "data": "<BASE64 OF THE PDF WITH THE LOGO BAKED IN>",
                                "fileName": "party-agreement.pdf" }, "extension": "pdf" },
    "fields": [ { "fieldType":"signature","inputType":"signer","name":"Signature",
                  "signer":"Primary Signer","required":true,"pageIndex":0,
                  "position":{"x":0.14,"y":0.77},"size":{"width":0.33,"height":0.06},
                  "signatureType":"signature" } ]
  }],
  "signers": [ { "label":"Primary Signer","email":"[Primary Signer Email]","name":"[Primary Signer Name]" } ],
  "steps":   [ { "name":"Step 1","signers":["Primary Signer"] } ],
  "envelope":{ "name":"Party Agreement","workflowType":"sequential" }
} } }
```
Notes (all verified):
- `fileName` must have **no** `\ / : * ? " < > |` (AssureSign treats it as a path).
- `position`/`size` are **0–1 fractions**, top-left origin.
- typed fields need a non-empty `signerInputType` (variable→`prefill`,
  date→`timestamp`, else `free_Text`) — same rule as the template path.
- Prefill still works: pass `request.templates[0].values`/`content` `values[]`
  `{name,value}` matched to fields by name.

## 3. Chosen design — the **hybrid** (keep the template for layout, swap the PDF)

The client keeps **one** template design (field layout + signer roles). At send time
the broker submits **ad-hoc** using the party-branded PDF **plus the stored template's
field layout**. One template to maintain, per-party branding, and the existing
`templateID` path is untouched.

To keep the current working flows **100% unchanged** (easy revert), the ad-hoc path
is a **separate, opt-in** flow triggered by its own signal — it never competes with
the normal Prepare/Send trigger:

| Piece | What |
|---|---|
| **`cs_adhocsend`** (bit, on `cs_envelope`) | the opt-in signal. Normal envelopes never set it, so the existing Prepare flow path is unaffected. |
| **Branded PDF** | stored as an **annotation** on the envelope, subject **`EnvelopeSourcePDF`** (base64) — same pattern as the template PDF (`TemplateSourcePDF`); no size-limited memo column. |
| **`ESign - Send Ad-hoc Envelope`** (new flow) | triggers on `cs_envelope` where `cs_adhocsend = true`. Reads the envelope, its template (`cs_templatejson` → fields/signers), the `EnvelopeSourcePDF` annotation, and the recipients; builds the ad-hoc `/submit`; writes `cs_preparedenvelopeid`, `cs_responsebody`, and `statuscode → In Process`. |
| **`SAMPLE - Create Branded Envelope`** (sample flow) | generates or picks a party-branded PDF, creates a `cs_envelope` that references a layout template, attaches the `EnvelopeSourcePDF` annotation, sets recipients + `cs_adhocsend = true`. |

**Who bakes the logo in:** the client already uploads the party image and generates
their PDF, so the realistic path is "merge the logo into the PDF in the client's own
process, then hand the base64 to the broker." Power Automate has no native PDF
compositing; production options are (a) generate the PDF where the form lives, (b) a
Word/HTML template + a Convert-to-PDF action (OneDrive/SharePoint connector), or
(c) an Azure Function / PDF service. The **sample** flow below sidesteps that by
submitting a pre-branded test PDF that varies per run, which is enough to *verify the
broker ad-hoc path and that the logo shows per party*.

## 4. Revert

All additions are opt-in and isolated: delete the `ESign - Send Ad-hoc Envelope`
flow, the `SAMPLE - Create Branded Envelope` flow, and (optionally) the `cs_adhocsend`
column + any `EnvelopeSourcePDF` annotations. The normal `templateID` Prepare/Send
path is never modified. Flow + schema backups are kept under
`solutions/docs/` and the scratchpad `flow-backups/`.
