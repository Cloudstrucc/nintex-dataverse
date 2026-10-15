# PDF Image Overlay — Custom API usage & testing guide

> Self-contained guide for testing the **`cs_OverlayImageOnPdfX`** Custom API.
> Environment: **dev-ppep-fp-01** (`https://dev-ppep-fp-01.crm3.dynamics.com`), where the
> **`PdfImageOverlay`** managed solution is installed.

## What it does
A Dataverse **Custom API** (a server-side plug-in) that takes a **PDF** and an **image** (both as
base64) and returns a **new PDF with the image stamped onto it**. It runs entirely inside Dataverse
(plug-in sandbox) — no Azure, no external service. The engine is iText7 and it works on **any** PDF
and any **JPEG/PNG** (including transparency).

It is **schema-agnostic**: it reads/writes no tables and knows nothing about e-signatures. You hand
it bytes, it hands bytes back.

---

## The Custom API

| | |
|---|---|
| **Unique name** | `cs_OverlayImageOnPdfX` |
| **Type** | **Unbound** (global) Action — not bound to any table |
| **Call style** | `POST /api/data/v9.2/cs_OverlayImageOnPdfX` (Web API), or Power Automate "Perform an unbound action", or `Xrm.WebApi.online.execute` |
| **Side effects** | none (reads/writes no data) |

### Request parameters

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `PdfContent` | String | **Yes** | — | Base64 of the source PDF. |
| `ImageContent` | String | **Yes** | — | Base64 of the image to stamp (**PNG or JPEG**). |
| `Anchor` | String | No | `TopRight` | `TopRight`, `TopLeft`, `BottomRight`, `BottomLeft`, or `Center`. Ignored when both `X` and `Y` are supplied. |
| `X` | Decimal | No | — | Explicit **left** position in PDF **points**, **top-left origin**. Overrides `Anchor` when `X`+`Y` both given. |
| `Y` | Decimal | No | — | Explicit **top** position (points, top-left origin). |
| `Width` | Decimal | No | auto | Target width (points). If only `Width` is given, height is derived to keep aspect ratio. |
| `Height` | Decimal | No | auto | Target height (points). If only `Height` is given, width is derived to keep aspect ratio. |
| `Margin` | Decimal | No | `24` | Edge margin (points) used for anchored placement. |
| `Page` | Integer | No | `1` | 1-based page to stamp. **Negative (e.g. `-1`) = every page** (e.g. watermark). |

> **Zero means "not supplied".** Dataverse delivers optional Custom API parameters with their type
> default rather than omitting them, so an unsent `Decimal` arrives as `0`. The plug-in therefore
> treats a **non-positive** `X`/`Y`/`Width`/`Height`/`Margin` as *not supplied* and falls back to the
> default. To place something flush against an edge, pass a tiny non-zero value such as `0.01`
> rather than `0`. Likewise `Page = 0` means "not supplied" → page 1; use a **negative** `Page` for
> all pages.

### Response

| Name | Type | Description |
|---|---|---|
| `PdfContent` | String | Base64 of the resulting PDF. |
| `EngineVersion` | String | Assembly version of the build that served **this** request (e.g. `1.0.10.0`). Assert on it before trusting a result — the sandbox caches the assembly per worker, so right after a deploy some calls can still be answered by the previous build. |

### Coordinate system (important)
`X`/`Y` are **top-left origin** (0,0 = top-left of the page), in PDF **points** (72 pt = 1 inch; a
US-Letter page is 612 × 792 pt). You do **not** need to flip Y — the plug-in converts to PDF's
internal bottom-left origin for you.

### Default placement (no position/size given)
- **Position:** top-right corner, 24 pt from the top and right edges.
- **Size:** image fit inside a box of `clamp(12% of page width, 48pt, 120pt)`, aspect preserved.
  On a 612×792 page that's a ~73 pt box — a sensible logo size.
- **Page:** page 1 only.

Verified in dev on a US-Letter page, defaults only — the emitted transform is
`73.44 0 0 73.44 514.56 694.56 cm`, i.e. a 73.44 pt square 24 pt in from the top and right edges.

### Source image size (gotcha, not a plug-in issue)
A Dataverse **image column** such as `pfa_politicalparty.pfa_logo` stores a **144 × 144 square
thumbnail** unless the column has *“Can store full image”* enabled — so `/$value?size=full` can
still hand you a square-cropped logo. The overlay reproduces whatever bytes it is given; if a
wordmark comes out cropped, check the source column, not the API.

---

## How to call it

### 1. Raw Web API
```http
POST https://dev-ppep-fp-01.crm3.dynamics.com/api/data/v9.2/cs_OverlayImageOnPdfX
Authorization: Bearer <token>
Content-Type: application/json
OData-MaxVersion: 4.0
OData-Version: 4.0

{ "PdfContent": "<base64 pdf>", "ImageContent": "<base64 png-or-jpeg>", "Anchor": "TopRight" }
```
Response body:
```json
{ "PdfContent": "<base64 pdf with image stamped>" }
```

### 2. Power Automate
Add **Dataverse → "Perform an unbound action"**:
- **Action Name:** `cs_OverlayImageOnPdfX`
- **Parameters (raw):**
```json
{ "PdfContent": "@{...}", "ImageContent": "@{...}", "Anchor": "TopRight" }
```
- Read the result from `outputs('Perform_an_unbound_action')?['body/PdfContent']`.

### 3. Client script (model-driven app)
```javascript
const req = {
  PdfContent: pdfB64, ImageContent: imgB64, Anchor: "TopRight",
  getMetadata: () => ({
    boundParameter: null, operationType: 0, operationName: "cs_OverlayImageOnPdfX",
    parameterTypes: {
      PdfContent:   { typeName: "Edm.String", structuralProperty: 1 },
      ImageContent: { typeName: "Edm.String", structuralProperty: 1 },
      Anchor:       { typeName: "Edm.String", structuralProperty: 1 }
    }
  })
};
const res = await Xrm.WebApi.online.execute(req);
const { PdfContent } = await res.json();   // base64 of the branded PDF
```

---

## End-to-end test (Node, service principal) — matches how it was validated in dev

Reads a political party's logo (`pfa_politicalparty.pfa_logo`) + any PDF, calls the API, and
confirms the result is a valid PDF.

```javascript
// needs: a token for dev-ppep-fp-01; a base64 PDF in `pdfB64`
const FP = "https://dev-ppep-fp-01.crm3.dynamics.com";
const h = { Authorization: `Bearer ${token}`, Accept: "application/json", "Content-Type": "application/json" };

// party logo as base64 (full size)
const logoResp = await fetch(`${FP}/api/data/v9.2/pfa_politicalparties(<partyId>)/pfa_logo/$value?size=full`,
                             { headers: { Authorization: `Bearer ${token}` } });
const logoB64 = Buffer.from(await logoResp.arrayBuffer()).toString("base64");

// call the API
const r = await fetch(`${FP}/api/data/v9.2/cs_OverlayImageOnPdfX`, {
  method: "POST", headers: h,
  body: JSON.stringify({ PdfContent: pdfB64, ImageContent: logoB64, Anchor: "TopRight" })
});
const out = Buffer.from((await r.json()).PdfContent, "base64");
console.log("bytes:", out.length, "| magic:", out.slice(0,5).toString()); // expect "%PDF-"
require("fs").writeFileSync("branded.pdf", out); // open it to see the logo top-right
```

**Example party ids in fp-01** (have logos): Bloc Québécois `0764a1dd-f1ef-f011-8406-7ced8d0510ea`,
Conservative `c9d5760d-f2ef-f011-8406-7ced8d0510ea`.

### What success looks like
- HTTP 200/204 with a `PdfContent` string in the body.
- Decoded output starts with `%PDF-`, is **larger** than the input, opens in any viewer, and shows
  the image at the requested anchor/position.

---

## Image formats & sizing
- **JPEG and PNG**, including **transparency** (alpha), palette, and interlaced PNG.
- To control size: pass `Width` and/or `Height` (points). Pass just one to keep aspect ratio.
- To control position precisely: pass `X` and `Y` (top-left origin, points) — these override `Anchor`.

## Troubleshooting

**“The output PDF is bigger but I see no image.”** Fixed in **1.0.9**. In 1.0.0–1.0.8 the unsent
optional parameters arrived as `0`, so `Width`/`Height` counted as *supplied at zero* and the
plug-in emitted a degenerate transform — `0 0 0 0 0 792 cm` — which embeds the image and then draws
it at zero size. The image was present and correctly referenced from the page resources; it just had
no area. Passing an explicit `Width` **and** `Height` was the workaround on the old build. If you
see this again, decompress the appended page content stream and read the `cm` operator: the first
and fourth numbers are the drawn width and height, and they must be non-zero.

**“My change didn’t take effect on the first call.”** Dataverse caches the plug-in assembly per
sandbox worker and refreshes lazily, so for a short window after an import some calls are answered
by the new build and others by the previous one. Read **`EngineVersion`** off every response and
assert on it; if two consecutive calls disagree, you are in that window — repeat until it settles
rather than drawing conclusions from a single call.

**“`Width`/`Height` seem to be ignored / the size tracks my input image.”** Confirmed working as of
**1.0.10** — a 512×512, a 144×144 and a 400×100 source all render an identical 68×68 pt box when
sent `Width:68, Height:68`. If you see otherwise, check `EngineVersion` first: the pre-1.0.9 build
sized differently. See `plugins/CSPdfImageOverlay/WIDTH-HEIGHT-ISSUE.md` for the measured results.

## Error handling
Errors come back as a normal Dataverse `400` with a message, e.g.:
- `cs_OverlayImageOnPdfX failed: PdfContent is not valid base64.`
- `Missing required parameter: ImageContent`
- `Page out of range.`

## Notes / limits
- **Base64 everything.** Both inputs and the output are base64 strings.
- **Large PDFs:** the bytes travel in the action payload and the plug-in sandbox has a ~2-minute
  cap; keep documents reasonable (invoke from an **async** flow step if needed).
- **Stateless:** the API only transforms bytes — attaching/saving the result PDF is the caller's job.

---

## Typical consumer pattern (e-signature branding)
1. Read the party logo: `GET …/pfa_politicalparties(<id>)/pfa_logo/$value?size=full` → base64.
2. Read the template's source PDF (base64).
3. Call `cs_OverlayImageOnPdfX` (PdfContent = template PDF, ImageContent = logo) → branded PDF.
4. Do whatever you need with the returned PDF (attach to a record, send, etc.).
