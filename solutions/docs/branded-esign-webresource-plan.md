# Plan — user-invoked branded e-signature from a model-driven app (ribbon + JS web resource)

> **Status: design for review. Nothing implemented yet.** Separate from the
> [PdfImageOverlay plugin](pdf-overlay-plugin/README.md); this is a **consumer** front-end for
> backend (internal) users.

**Goal:** a backend user viewing a **registered political party** in a model-driven app clicks a
ribbon button → the system builds a branded e-signature envelope (the party's logo stamped onto a
chosen template's PDF) and sends it ad-hoc — all from the browser, no flow run needed.

**Answer to "is there a JS Web API way?": yes.** A command-bar button runs a JS web resource that
uses the Dataverse Web API. It's the interactive sibling of the flow path, and it **reuses the same
generic `ec_OverlayImageOnPdf` Custom API** for the PDF work.

---

## Where it fits

```mermaid
flowchart TD
  U["Backend user on<br/>Political Party form (MDA)"] -->|clicks "Send for e-signature"| CMD["Ribbon command"]
  CMD --> JS["JS web resource<br/>ec_esign_brandedparty.js"]
  JS -->|"GET pfa_logo/$value"| LOGO[("pfa_politicalparty.pfa_logo")]
  JS -->|"GET TemplateSourcePDF + cs_templatejson"| TPL[("cs_template")]
  JS -->|"POST ec_OverlayImageOnPdf (PDF+logo)"| API["Custom API (plugin)"]
  API -->|"branded PDF"| JS
  JS -->|"create cs_envelope + EnvelopeSourcePDF + signers, set cs_adhocsend"| ENV[("cs_envelope")]
  ENV -->|"ad-hoc flow (unchanged)"| NINTEX["Broker → Nintex"]
```

---

## Interaction flow (what the JS does)
1. **Guard / context** — read the current `pfa_politicalparty` id from `formContext`; confirm it's
   *registered* and has a logo (enable rule, below).
2. **Pick a template + recipients** — open a small dialog (a custom page or HTML web resource
   dialog, or `Xrm.Navigation.navigateTo`) to choose the `cs_template` and enter signer name(s)/
   email(s). (Templates list filtered to Global + shared-with-me, per the template model.)
3. **Fetch inputs (Web API):**
   - Logo: `GET /api/data/v9.2/pfa_politicalparties(<id>)/pfa_logo/$value?size=full` → base64.
   - Template PDF: `GET /annotations?$filter=_objectid_value eq <tplId> and subject eq 'TemplateSourcePDF'&$select=documentbody`.
   - Fields/signers: the chosen template's `cs_templatejson`.
4. **Brand the PDF** — `POST /api/data/v9.2/ec_OverlayImageOnPdf` with `{PdfContent, ImageContent, Anchor:"TopRight"}` → returns the branded `PdfContent`. *(Reuses the generic plugin — no client-side PDF library needed.)*
5. **Create the envelope (Web API):**
   - `POST /cs_envelopes` (`cs_templateid`, `cs_envelopejson` recipients, `statuscode` Draft).
   - `POST /annotations` `EnvelopeSourcePDF` = branded PDF, regarding the envelope.
   - `POST /cs_signers` one per recipient (role from `cs_templatejson.signers[]`, email/name).
   - `PATCH /cs_envelopes(<id>)` `cs_adhocsend = true`.
6. **Feedback** — `Xrm.Utility.showProgressIndicator()` during, then a success dialog with a link to
   the new envelope (or the envelope details page). The broker ad-hoc flow submits to Nintex.

---

## Ribbon command
- **Modern command** (Power Apps command designer) or **Ribbon Workbench** button on the
  `pfa_politicalparty` main form (and/or the grid).
- **Label/icon:** "Send for e-signature".
- **Action:** JS function `EC.Esign.sendBrandedParty(primaryControl)`.
- **Enable rule (visibility):** only when the record is *registered* (status flag) **and** a logo
  exists. The simplest robust enable check is a small JS `EnableRule` returning false until those
  hold (a formula/column rule can cover the status; the logo presence is checked in JS).

---

## Two overlay options (recommended first)

| Option | How | Pros | Cons |
|---|---|---|---|
| **A. Call `ec_OverlayImageOnPdf`** (recommended) | JS `POST`s the Custom API, gets branded PDF | One overlay implementation (server-side), identical to the flow path; no client PDF lib; small JS | requires the PdfImageOverlay solution installed |
| **B. Overlay client-side with pdf-lib** | JS loads pdf-lib (web resource), draws the logo in-browser | no dependency on the plugin solution | duplicate overlay logic; ships pdf-lib as a web resource; browser-only. (This is what the existing `cs_esign_branded_request.js` sample does.) |

**Recommendation: Option A** — the ribbon button and the headless flow then share the exact same
PDF engine (the plugin), so branding is pixel-identical regardless of entry point.

---

## Prerequisites
- **PdfImageOverlay** solution installed (for Option A).
- The broker `ESign - Send Ad-hoc Envelope` flow on (it already is).
- `pfa_politicalparty` Web API enabled for the fields read (if this runs on the **portal**; inside
  the **model-driven app** the user's security role governs access, not portal table permissions).
- A chosen `cs_template` with a `TemplateSourcePDF` and `cs_templatejson` fields.
- Security: the user needs create on `cs_envelope`/`cs_signer`/`annotation` and read on the party +
  template. (Model-driven app = Dataverse security roles, not portal permissions.)

---

## Model-driven app vs portal (important)
This plan is for the **model-driven (backend) app** — internal staff. It uses `Xrm.WebApi` and
Dataverse security roles. It is **not** the Power Pages portal (which has its own table permissions
and the `cs_templateshare` snapshot path). If you later want the **same button for portal users**,
that's a portal web template + the portal Web API + the share-aware read — a separate effort.

---

## Pros / cons vs the flow path
- **Ribbon/JS:** immediate, interactive, with a picker dialog and inline feedback; best for a human
  choosing template + recipients on the spot.
- **Flow:** headless/automatable (e.g. triggered by a status change or a bulk operation); no UI.
- They are complementary and **share the `ec_OverlayImageOnPdf` plugin**, so keep both.

---

## Annex — JS sketch (Option A)

```javascript
// ec_esign_brandedparty.js  (model-driven app ribbon command)
var EC = EC || {}; EC.Esign = EC.Esign || {};
EC.Esign.sendBrandedParty = async function (primaryControl) {
  var fc = primaryControl;                        // formContext
  var partyId = fc.data.entity.getId().replace(/[{}]/g, "");
  try {
    Xrm.Utility.showProgressIndicator("Preparing e-signature…");

    // 1) template + recipients — replace with your picker (custom page / dialog)
    var pick = await EC.Esign.pickTemplateAndRecipients();   // { templateId, recipients:[{name,email,role}] }

    // 2) logo (base64)
    var logoResp = await fetch("/api/data/v9.2/pfa_politicalparties(" + partyId + ")/pfa_logo/$value?size=full",
                               { headers: { Accept: "application/octet-stream" } });
    var logoB64 = EC.Esign.bufToB64(await logoResp.arrayBuffer());

    // 3) template PDF (base64) via Xrm.WebApi
    var ann = await Xrm.WebApi.retrieveMultipleRecords("annotation",
      "?$select=documentbody&$top=1&$filter=_objectid_value eq " + pick.templateId + " and subject eq 'TemplateSourcePDF'");
    var pdfB64 = ann.entities[0].documentbody;

    // 4) brand the PDF via the generic Custom API
    var overlay = await Xrm.WebApi.online.execute(EC.Esign.overlayRequest(pdfB64, logoB64));
    var branded = (await overlay.json()).PdfContent;

    // 5) create envelope + annotation + signers + adhoc
    var env = await Xrm.WebApi.createRecord("cs_envelope", {
      cs_name: pick.title, cs_subject: pick.title, cs_templateid: pick.templateId,
      cs_envelopejson: JSON.stringify({ templateId: pick.templateId, recipients: pick.recipients }),
      statuscode: 1
    });
    await Xrm.WebApi.createRecord("annotation", {
      subject: "EnvelopeSourcePDF", filename: "branded.pdf", mimetype: "application/pdf",
      documentbody: branded, "objectid_cs_envelope@odata.bind": "/cs_envelopes(" + env.id + ")"
    });
    for (var i = 0; i < pick.recipients.length; i++) {
      var r = pick.recipients[i];
      await Xrm.WebApi.createRecord("cs_signer", {
        cs_fullname: r.name, cs_email: r.email, cs_signerorder: i + 1, cs_language: "en-US",
        cs_signerstatus: "Pending", "cs_EnvelopeLookup@odata.bind": "/cs_envelopes(" + env.id + ")"
      });
    }
    await Xrm.WebApi.updateRecord("cs_envelope", env.id, { cs_adhocsend: true });

    Xrm.Utility.closeProgressIndicator();
    await Xrm.Navigation.openAlertDialog({ text: "E-signature sent. Envelope created." });
  } catch (e) {
    Xrm.Utility.closeProgressIndicator();
    await Xrm.Navigation.openErrorDialog({ message: "Send failed: " + (e.message || e) });
  }
};

// Custom API request object for Xrm.WebApi.online.execute
EC.Esign.overlayRequest = function (pdfB64, imgB64) {
  return {
    PdfContent: pdfB64, ImageContent: imgB64, Anchor: "TopRight",
    getMetadata: function () {
      return {
        boundParameter: null, operationType: 0, operationName: "ec_OverlayImageOnPdf",
        parameterTypes: {
          PdfContent:   { typeName: "Edm.String", structuralProperty: 1 },
          ImageContent: { typeName: "Edm.String", structuralProperty: 1 },
          Anchor:       { typeName: "Edm.String", structuralProperty: 1 }
        }
      };
    }
  };
};

EC.Esign.bufToB64 = function (buf) {
  var bytes = new Uint8Array(buf), bin = ""; for (var i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
};
```

*(`pickTemplateAndRecipients` is the UI piece — a custom page or HTML dialog; stubbed here.)*
```
