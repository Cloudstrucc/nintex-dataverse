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
                var doc = new PdfDocument(new PdfReader(new MemoryStream(pdf)), new PdfWriter(outMs));
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
                    double pyBottom = ph - pyTop - dh; // iText origin is bottom-left
                    var canvas = new PdfCanvas(page);
                    // CTM form: width, 0, 0, height, x, y
                    canvas.AddImage(imgData, (float)dw, 0, 0, (float)dh, (float)px, (float)pyBottom, false);
                }
                doc.Close();
                return outMs.ToArray();
            }
        }
    }
}
