# Implementation plan — "Branded Envelope" Dataverse plugin (party logo on an existing template)

**Goal:** stay entirely within Power Platform. Take an existing `cs_template` (which already
has its Nintex field configuration + a `TemplateSourcePDF`), composite a party logo onto the
top-right of its PDF, create an ad-hoc envelope, and let the broker submit it — **no Azure,
no custom connector, no premium licence.**

This builds on the dormant reference already in the repo:
- Plugin scaffold: `solutions/ESignatureClient/sample-mda/plugin/SendBrandedEnvelopePlugin.cs`
- Client-side equivalent (for reference): `solutions/ESignatureClient/sample-mda/webresources/cs_esign_branded_request.js`
- Node proof-of-concept of the overlay math: `solutions/docs/sample-create-partylogo-envelope.mjs`

The plugin only **creates the record + overlays the PDF + sets `cs_adhocsend`**. The existing
broker flow **`ESign - Send Ad-hoc Envelope`** (unchanged) reads the template fields + the
inline `EnvelopeSourcePDF` and submits to Nintex. Nothing in the broker changes.

---

## 1. Architecture / where it runs

```
cs_signaturerequest (MDA record: Title, Template, Signee1/2, Party logo)
        │  user clicks "Send Branded Envelope"  (command-bar button)
        ▼
Custom API  cs_SendBrandedEnvelope   (bound to cs_signaturerequest)
        │  → fires the plugin (sync, Post-Operation, sandbox/isolation)
        ▼
PLUGIN (C#):
   1. read cs_template.cs_templatejson (field + signer labels)
   2. read template TemplateSourcePDF annotation  → base PDF bytes
   3. get the party logo bytes  (see §4 — decision)
   4. CompositeLogo(basePdf, logo)  → branded PDF   (PdfSharpCore)
   5. create cs_envelope (cs_templateid = template, recipients json)
   6. create EnvelopeSourcePDF annotation (branded PDF)
   7. create cs_signer rows from the lookups
   8. set cs_adhocsend = true
        ▼
BROKER flow "ESign - Send Ad-hoc Envelope" (UNCHANGED) → submits inline PDF + template fields to Nintex
```

Steps 1-8 are already written in `SendBrandedEnvelopePlugin.cs`. **Three stubs** remain:
`ParseSignerLabels`, `DownloadFileColumn`, and **`CompositeLogo`** (the real work).

---

## 2. Components to build

| # | Component | What |
|---|---|---|
| A | **Custom API** `cs_SendBrandedEnvelope` | Bound action on `cs_signaturerequest` (or unbound with a `TemplateId`/`RequestId` input). Fires the plugin. Optional input params if we don't bind to a record (see §4). |
| B | **Plugin assembly** | Fill the 3 stubs in `SendBrandedEnvelopePlugin.cs`; target **.NET Framework 4.6.2**, reference `Microsoft.CrmSdk.CoreAssemblies`. |
| C | **PDF library** | **PdfSharpCore** (pure-managed, sandbox-safe). **Not** classic PdfSharp / `System.Drawing` (GDI is blocked in the sandbox). |
| D | **ILRepack/ILMerge** | Merge PdfSharpCore (+ its deps) into the plugin DLL — the sandbox loads only your single signed assembly. |
| E | **Registration** | Register the (signed) assembly + a step on the Custom API message, **synchronous, Post-Operation, isolation = Sandbox**. |
| F | **Solution packaging** | Add the plugin assembly, SDK message processing step, and Custom API to the client solution (`ESignatureClient`) so it travels dev → test. |
| G | **Trigger** | A command-bar button on `cs_signaturerequest` that calls the Custom API — or set it on Update of a `cs_sendnow` flag so a flow can trigger it. |

---

## 3. `CompositeLogo` — the overlay (PdfSharpCore)

The one piece of real new code. Equivalent to the pdf-lib `drawImage` in the Node sample.

**Coordinate conversion (important):** pdf-lib uses a **bottom-left** origin; PdfSharpCore's
`XGraphics` uses a **top-left** origin (like GDI). The Node sample centres the logo at
`(540, 740)` on a `612 × 792` page with a `64pt` box. Converting to top-left origin:
`topY = pageHeight − 740 = 52`, so the box's top-left is `(540 − 32, 52 − 32) = (508, 20)`.

```csharp
private static byte[] CompositeLogo(byte[] pdfBytes, byte[] logoBytes)
{
    if (logoBytes == null || logoBytes.Length == 0) return pdfBytes; // no logo → unchanged
    using (var inStream  = new MemoryStream(pdfBytes))
    using (var outStream = new MemoryStream())
    {
        var doc  = PdfSharpCore.Pdf.IO.PdfReader.Open(inStream, PdfSharpCore.Pdf.IO.PdfDocumentOpenMode.Modify);
        var page = doc.Pages[0];
        using (var gfx = PdfSharpCore.Drawing.XGraphics.FromPdfPage(page))
        using (var imgStream = new MemoryStream(logoBytes))
        {
            var img = PdfSharpCore.Drawing.XImage.FromStream(() => imgStream); // JPG or PNG
            const double box = 64, cx = 540, cyTop = 792 - 740; // = 52
            double s  = Math.Min(box / img.PixelWidth, box / img.PixelHeight);
            double w  = img.PixelWidth * s, h = img.PixelHeight * s;
            gfx.DrawImage(img, cx - w / 2, cyTop - h / 2, w, h);
        }
        doc.Save(outStream, closeStream: false);
        return outStream.ToArray();
    }
}
```

Notes:
- `XImage.FromStream` reads JPG and PNG (matches the `pfa_logo` formats we saw: JPG/PNG).
- Page size is read from the PDF; if a template isn't 612×792 we scale `cx`/`cyTop` by the
  page's actual `Width`/`Height` (the sample templates are all 612×792, so this is a guard).
- Must enable `PdfSharpCore` image decoding (it ships its own PNG/JPEG decoders — no GDI).

---

## 4. Logo source — **decision needed**

The scaffold reads a **File column** `cs_partylogo` on `cs_signaturerequest` via
`InitializeFileBlocksDownload` + `DownloadBlock`. Options:

- **(a) File column on the request record** *(simplest, fully same-env)* — the user uploads /
  a prior step copies the party logo into `cs_signaturerequest.cs_partylogo`. `DownloadFileColumn`
  streams it. No cross-environment calls. **Recommended for the plugin.**
- **(b) Custom API input parameter** — pass the logo as base64 (or a party id) into
  `cs_SendBrandedEnvelope`. Keeps the plugin stateless; the caller supplies the logo.
- **(c) Pull `pfa_politicalparty.pfa_logo` from dev-ppep-fp-01** — matches the Node sample, but
  it's a **cross-environment** read from inside the sandbox (an authenticated HTTP call to fp-01).
  Doable but adds auth/secret handling in the plugin; heavier. Only if the logo must come live
  from PERS.

**Recommendation:** (a) for the in-platform plugin — copy the party logo onto the request's
File column as part of the request intake, then the plugin is 100% same-env and sandbox-safe.
(We can add (c) later if live PERS pull is required.)

---

## 5. Fill the other two stubs

- **`ParseSignerLabels(templateJson)`** → deserialize `cs_templatejson` and return
  `signers[].label` in order. Use **Newtonsoft.Json** (ILRepacked) or hand-roll with
  `System.Runtime.Serialization.Json` to avoid another dependency.
- **`DownloadFileColumn(...)`** → implement the `InitializeFileBlocksDownload` /
  `DownloadBlock` loop (standard Dataverse File-column download), returning `null` when empty.

---

## 6. Build & deploy (dev)

1. **Project:** new C# **Class Library (.NET Framework 4.6.2)**, e.g.
   `plugins/CS.ESign.Plugins/CS.ESign.Plugins.csproj`. Reference `Microsoft.CrmSdk.CoreAssemblies`
   (NuGet) and `PdfSharpCore` (NuGet). Move `SendBrandedEnvelopePlugin.cs` into it.
2. **Strong-name** the assembly (`.snk`) — required for registration.
3. **ILRepack** PdfSharpCore (+ Newtonsoft if used) into the output DLL so the sandbox sees one
   assembly. (MSBuild `ILRepack.Lib.MSBuild.Task`, internalize dependencies.)
4. **Register** with the **Plugin Registration Tool** (or `pac plugin push`):
   - Register the assembly (Isolation = **Sandbox**, Storage = Database).
   - Create the **Custom API** `cs_SendBrandedEnvelope` (bound to `cs_signaturerequest`, or
     unbound with inputs per §4), and register the plugin **step** on it: **synchronous,
     Post-Operation**.
5. **Add to the `ESignatureClient` solution**: the plugin assembly, the SDK message processing
   step, the Custom API, and the command-bar button — so it promotes dev → test like the flows.
6. **Command-bar button** (or flow): calls `cs_SendBrandedEnvelope` against the selected request.

---

## 7. Testing

- Unit-test `CompositeLogo` offline (feed a template PDF + a JPG/PNG, open the result, confirm the
  logo lands top-right) — the Node sample's output is the visual reference.
- In dev: create a `cs_signaturerequest` (Template = the Party Agreement template, a logo on the
  File column, two signees), click the button → confirm a `cs_envelope` + `EnvelopeSourcePDF` is
  created, `cs_adhocsend = true`, and the broker ad-hoc flow submits (envelope → In Process).
- Confirm the envelope details page renders the branded PDF (the `EnvelopeSourcePDF`-first logic
  we already deployed).

---

## 8. Risks / constraints

- **Sandbox isolation:** no filesystem, no `System.Drawing`/GDI, approved managed APIs only,
  ~2-minute execution limit. PdfSharpCore + ILRepacked deps fit inside this. (Do **not** use
  classic PdfSharp or iTextSharp-with-GDI.)
- **Assembly size / single DLL:** everything must be in one signed, ILRepacked assembly.
- **Logo format:** support JPG + PNG (both appear in `pfa_logo`); `XImage` handles both.
- **Page geometry:** scale the position if a template's page isn't 612×792 (guarded in §3).
- **Sync vs async:** synchronous gives immediate feedback to the button; if large PDFs risk the
  2-min cap, switch the step to **async**.
- **Cross-env (if we pick §4c):** needs an authenticated call to fp-01 from the sandbox — extra
  secret handling; avoid unless required.

---

## 9. Decisions to confirm before I implement

1. **Logo source** — (a) File column on the request *(recommended)*, (b) Custom API input, or
   (c) live `pfa_politicalparty` pull from fp-01.
2. **Trigger** — command-bar button on `cs_signaturerequest` *(recommended)*, or Update-of-a-flag
   so a flow invokes it.
3. **Solution home** — confirm it lives in **`ESignatureClient`** (promotes dev → test with the
   rest of the client sample).
4. **Sync or async** plugin step (default: sync).
```
