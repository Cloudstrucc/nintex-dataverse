# Sample MDA — Branded (ad-hoc) e-signature request

A small, end-to-end **model-driven-app** sample showing how a client would use the
broker's ad-hoc / logo path from inside Dataverse: a user fills a form (title,
two signees, a party logo, a template), clicks a command-bar button, and an
envelope is sent for signature with the party logo baked onto the PDF.

It deliberately uses **client-side JavaScript (pdf-lib in the browser)** to
composite the logo — **no plug-in assembly to register**. A server-side plug-in
equivalent is included as a **dormant reference** (`plugin/SendBrandedEnvelopePlugin.cs`),
left unregistered.

> Everything here was built into the **`ESignatureClient`** (unmanaged) solution
> in **dev** (`dev-ec-esign-01`). The normal broker/template path is untouched.

---

## How it works

```
cs_signaturerequest (form)                     broker (already built)
┌──────────────────────────────┐
│ Title                        │   click      ┌───────────────────────────────┐
│ Description                  │  button      │ cs_envelope + EnvelopeSourcePDF│
│ Signee 1 (contact)           │ ───────────▶ │ annotation + recipients        │
│ Signee 2 (contact)           │   JS does:   │ cs_adhocsend = true            │
│ Template (cs_template)       │  composite   └──────────────┬────────────────┘
│ Party logo (file: jpg/png)   │  + create                   │ fires
└──────────────────────────────┘                             ▼
                                              ESign - Send Ad-hoc Envelope flow
                                                 → AssureSign /submit (ad-hoc)
                                                 → signing email w/ the logo
```

The JavaScript (`cs_esign_branded_request.js` → `ESign.sendBrandedEnvelope`):
1. reads the form fields,
2. loads the template's `TemplateSourcePDF` annotation + `cs_templatejson` layout,
3. downloads the uploaded **Party logo** file,
4. **composites the logo top-right of page 1 with pdf-lib (in the browser)**,
5. creates a `cs_envelope` (referencing the template) + an `EnvelopeSourcePDF`
   annotation + `recipients` built from the two contacts,
6. sets `cs_adhocsend = true`, which fires **ESign - Send Ad-hoc Envelope**.

---

## What was created (components)

| Component | Name | Notes |
|---|---|---|
| Table | `cs_signaturerequest` ("E-Sign Branded Request") | user-owned |
| Column (primary) | `cs_title` ("Title") | |
| Column | `cs_description` ("Description") | memo |
| Column | `cs_partylogo` ("Party logo") | **File** column (jpg/png) |
| Lookup → contact | `cs_signee1` ("Signee 1") | N:1 contact |
| Lookup → contact | `cs_signee2` ("Signee 2") | N:1 contact |
| Lookup → cs_template | `cs_template` ("Template") | N:1 cs_template |
| Main form | Information | fields added |
| Web resource | `cs_/lib/pdf-lib.min.js` | pdf-lib UMD |
| Web resource | `cs_/scripts/cs_esign_branded_request.js` | the command script |

All added to the **`ESignatureClient`** solution.

---

## Dependencies / prerequisites

1. **Broker flow ON** — **ESign - Send Ad-hoc Envelope** must be turned on (it was
   created as a draft; see `solutions/docs/LOGO-INJECTION-FINDINGS.md`). Without it
   the envelope is created but nothing is submitted.
2. **A template with a real layout** — the chosen `cs_template` must have:
   - a `TemplateSourcePDF` annotation (the base PDF), and
   - a `cs_templatejson` with `signers` + `fields` (i.e. it has been synced to
     Nintex at least once). "Test 2 personal" works for a single signer.
3. **Contacts with email** — Signee 1 (and Signee 2 if the template has two
   signers) should be contacts that have `emailaddress1`, or they won't receive
   the signing email.
4. **pdf-lib web resource** — `cs_/lib/pdf-lib.min.js` must load before the script
   (the command references both, in that order — see below).

---

## One manual step — add the command-bar button

Command-bar (ribbon) buttons can't be created cleanly over the Web API, so add it
once in the maker portal:

1. make.powerapps.com → **Solutions → E-Signature Client → Tables → E-Sign
   Branded Request → Commands** (or open the table and **Edit command bar → Main
   form**).
2. **+ New command**:
   - **Label:** `Send branded envelope`
   - **Action:** Run JavaScript
   - **Add library:** `cs_/lib/pdf-lib.min.js`, then `cs_/scripts/cs_esign_branded_request.js`
     *(order matters — pdf-lib first)*
   - **Function name:** `ESign.sendBrandedEnvelope`
   - **Parameter:** add **PrimaryControl**
   - (optional) **Visibility → Run JavaScript**: library
     `cs_/scripts/cs_esign_branded_request.js`, function `ESign.canSend`,
     parameter PrimaryControl — hides the button until a template + Signee 1 are set.
3. **Save and publish**.

Then add the table to an app (or create one): **+ New → App → Model-driven**, add
the **E-Sign Branded Request** table, Save & Publish.

---

## Test

1. Open the app → **E-Sign Branded Requests → + New**.
2. Fill **Title**, pick **Template** (e.g. *Test 2 personal*), **Signee 1** (a
   contact with your email), optionally **Signee 2**, and **upload a Party logo**
   (png/jpg). **Save**.
3. Click **Send branded envelope**.
4. You'll get a form notification with the new envelope id. Track it in the
   **Envelopes** area / portal `/envelopes/details/?id=…`, and the signer(s)
   receive the signing email with the **logo top-right**.

---

## Cross-environment note

In this dev sample the app, `cs_template` and `cs_envelope` are all in the **same**
environment, so the JS calls `Xrm.WebApi` directly. In a real deployment the
`cs_envelope`/`cs_template` tables live in the **broker** environment. Point the
`createRecord`/`updateRecord`/annotation calls (and the template/annotation reads)
at the **broker Web API** (its org URL) with an appropriate token — or keep a thin
cross-environment flow/connection reference as the other client samples do. The
compositing (pdf-lib) stays client-side either way.

---

## Dormant plug-in (reference only)

`plugin/SendBrandedEnvelopePlugin.cs` is the **server-side** equivalent, left
**unregistered**. Use it only if you later prefer a plug-in to the JS: it needs a
managed PDF library for compositing (PdfSharpCore) and is best registered on a
**custom action** called from the button. See the header comment in the file.

---

## Revert

- Delete the two web resources (`cs_/lib/pdf-lib.min.js`,
  `cs_/scripts/cs_esign_branded_request.js`) and the command.
- Delete the `cs_signaturerequest` table (removes its columns, lookups, form).
- Nothing in the broker or the normal template path is affected.
