# RESOLVED — `cs_OverlayImageOnPdfX` `Width`/`Height`

**Status: closed.** `Width`/`Height` are honoured independently of the source image's pixel
dimensions. Verified on **fp-01** (`dev-ppep-fp-01`) by measuring rendered pixels, not by reading
the source. No code change was needed for the sizing contract; what *was* missing is a way to tell
which build answered a call, which is now exposed as `EngineVersion` (see below).

## Acceptance test — PASS

512×512 px image, `{X:506, Y:18, Width:68, Height:68}` on a 612×792 pt page:

| Source image | Params | Emitted transform | Rendered ink box (pt, top-left origin) |
|---|---|---|---|
| 512×512 px | `X:506, Y:18, Width:68, Height:68` | `68 0 0 68 506 706 cm` | left **506**, top **18**, **69×69** |
| 144×144 px | same | `68 0 0 68 506 706 cm` | identical |
| 400×100 px | same | `68 0 0 68 506 706 cm` | identical |
| 512×512 px | `Width:42` only | `42 0 0 42 546 726 cm` | 42×42, aspect preserved |
| 400×100 px | `Width:68` only | `68 0 0 17 520 751 cm` | 69×18, aspect preserved |

Three different source resolutions produce an **identical** 68×68 box, so the drawn size does not
track input pixels. (69 vs 68 is one inclusive boundary pixel when rasterising at 72 dpi.) The
transform is read by inflating the appended page content stream; the ink box is measured from a
`pdftoppm` raster.

Registration was also checked on fp-01 and is clean: `Anchor` (String), `Width`, `Height`, `X`, `Y`,
`Margin` (Float), `Page` (Integer) all present and `IsOptional = true`; `PdfContent` /
`ImageContent` required; exactly one `PdfImageOverlayIText` plug-in type, no stale duplicate.

## What produced the original symptom

The reported sizes (268×126, 288×378) are non-proportional from square inputs, which no code path
in this project can produce — every path is either an exact rectangle or an aspect-preserving fit.
That points at an assembly predating the current `Fit()` logic, i.e. the **1.0.0** managed build
that was on fp-01 until 1.0.9 was imported at 02:57 on 2026-10-15.

Note that Dataverse caches the plug-in assembly **per sandbox worker** and refreshes lazily, so for
a short window after an import some calls are still answered by the previous build while others get
the new one. A test run spanning that window sees inconsistent results — which is exactly the shape
of the original report, and why the next section exists.

## New: `EngineVersion` response property (1.0.10)

Both `cs_OverlayImageOnPdfX` and `cs_OverlayImageOnPdf` now return an extra String property:

| Name | Type | Description |
|---|---|---|
| `EngineVersion` | String | Assembly version of the build that served **this** request, e.g. `1.0.10.0`. |

Assert on it before trusting any other result:

```javascript
const res  = await fetch(`${env}/api/data/v9.2/cs_OverlayImageOnPdfX`, { method:'POST', headers, body });
const { PdfContent, EngineVersion } = await res.json();
if (EngineVersion !== '1.0.10.0') throw new Error(`stale sandbox worker: ${EngineVersion}`);
```

If two consecutive calls disagree, you are hitting the per-worker cache — repeat until it settles
rather than drawing conclusions from a single call.

## Parameter convention (confirmed intended)

`GetD` treats a **non-positive** number as "not supplied". This is required, not stylistic:
Dataverse delivers optional Custom API parameters with their **type default** rather than omitting
them, so an unsent `Decimal` arrives as `0` and `InputParameters.Contains(...)` is always true.
Without this, `Width`/`Height` both counted as supplied-at-zero and the plug-in emitted a degenerate
`0 0 0 0 … cm` transform — the image embedded but drew at zero area. Pass positive numbers; to sit
flush at an edge pass e.g. `0.01`. `Page = 0` likewise means "not supplied" → page 1; use a
**negative** `Page` for all pages.

---
*Deployed to fp-01 as managed solution **1.0.3.0**, plug-in assembly **1.0.10.0**.*
