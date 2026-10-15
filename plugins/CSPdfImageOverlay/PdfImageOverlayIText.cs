// PdfImageOverlayIText.cs — version A (iText7). Custom API: cs_OverlayImageOnPdfX.
// Robust, handles any PDF + JPEG/PNG (incl. transparency). iText7 is AGPL.
using System.IO;
using iText.IO.Image;
using iText.Kernel.Geom;
using iText.Kernel.Pdf;
using iText.Kernel.Pdf.Canvas;

namespace CSPdfImageOverlay
{
    public class PdfImageOverlayIText : OverlayBase
    {
        protected override string ApiName { get { return "cs_OverlayImageOnPdfX"; } }

        protected override byte[] Overlay(byte[] pdf, byte[] img, OverlayOpts o)
        {
            using (var outMs = new MemoryStream())
            {
                // Append mode: iText writes an incremental update and keeps existing page content
                // modifiable. Without it the page objects can be flushed before we append, silently
                // dropping our drawing operators (the image ends up embedded but never referenced).
                var doc = new PdfDocument(new PdfReader(new MemoryStream(pdf)), new PdfWriter(outMs),
                                          new StampingProperties().UseAppendMode());
                int first = o.Page <= 0 ? 1 : o.Page;
                int last = o.Page <= 0 ? doc.GetNumberOfPages() : o.Page;
                if (first < 1 || last > doc.GetNumberOfPages())
                    throw new Microsoft.Xrm.Sdk.InvalidPluginExecutionException("Page out of range.");

                ImageData imgData = ImageDataFactory.Create(img);
                for (int p = first; p <= last; p++)
                {
                    PdfPage page = doc.GetPage(p);
                    Rectangle ps = page.GetPageSize();
                    double pw = ps.GetWidth(), ph = ps.GetHeight();
                    double dw, dh, px, pyTop;
                    Fit(imgData.GetWidth(), imgData.GetHeight(), pw, ph, o, out dw, out dh, out px, out pyTop);
                    // iText origin is bottom-left; Fit() returns top-left Y. Honour a non-zero MediaBox origin.
                    double pyBottom = ph - pyTop - dh + ps.GetBottom();
                    double pxAbs = px + ps.GetLeft();

                    // Complex "designer" PDFs often leave unbalanced save (q) operators / an active
                    // clip or CTM. Appended content inherits that and the stamp gets clipped away.
                    // Count the leftover saves and emit matching raw Q's first, returning the graphics
                    // state to the clean page baseline before we stamp.
                    int extraSaves = LeftoverSaves(page);

                    var canvas = new PdfCanvas(page);
                    for (int k = 0; k < extraSaves; k++) canvas.WriteLiteral(" Q");
                    canvas.SaveState();
                    canvas.AddImageFittedIntoRectangle(imgData,
                        new Rectangle((float)pxAbs, (float)pyBottom, (float)dw, (float)dh), false);
                    canvas.RestoreState();
                }
                doc.Close();
                return outMs.ToArray();
            }
        }

        // Net count of unmatched 'q' (save) operators across the page's content streams.
        private static int LeftoverSaves(PdfPage page)
        {
            int depth = 0, max = 0;
            int n = page.GetContentStreamCount();
            for (int i = 0; i < n; i++)
            {
                PdfStream cs = page.GetContentStream(i);
                byte[] b = cs == null ? null : cs.GetBytes();
                if (b == null) continue;
                for (int j = 0; j < b.Length; j++)
                {
                    byte c = b[j];
                    if (c != (byte)'q' && c != (byte)'Q') continue;
                    bool pre = j == 0 || IsDelim(b[j - 1]);
                    bool post = j == b.Length - 1 || IsDelim(b[j + 1]);
                    if (!pre || !post) continue;
                    if (c == (byte)'q') { depth++; if (depth > max) max = depth; }
                    else if (depth > 0) depth--;
                }
            }
            return depth > 0 ? depth : 0;
        }

        private static bool IsDelim(byte c)
        {
            return c == 32 || c == 10 || c == 13 || c == 9 || c == 12 || c == 0
                || c == (byte)'/' || c == (byte)'[' || c == (byte)']'
                || c == (byte)'<' || c == (byte)'>' || c == (byte)'(' || c == (byte)')';
        }
    }
}
