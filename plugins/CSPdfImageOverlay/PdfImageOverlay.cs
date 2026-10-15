// CSPdfImageOverlay / PdfImageOverlay.cs
// Custom API plug-in: cs_OverlayImageOnPdf
// Stamps a base64 image onto a base64 PDF and returns the base64 result.
// Schema-agnostic: no Dataverse reads/writes. Sandbox-safe (PdfSharpCore, no GDI).
using System;
using System.IO;
using Microsoft.Xrm.Sdk;
using PdfSharpCore.Drawing;
using PdfSharpCore.Pdf;
using PdfSharpCore.Pdf.IO;

namespace CSPdfImageOverlay
{
    public class PdfImageOverlay : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var ctx = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var trace = (ITracingService)serviceProvider.GetService(typeof(ITracingService));
            try
            {
                string pdfB64 = GetString(ctx, "PdfContent", required: true);
                string imgB64 = GetString(ctx, "ImageContent", required: true);
                string anchor = GetString(ctx, "Anchor") ?? "TopRight";
                double? x = GetDouble(ctx, "X");
                double? y = GetDouble(ctx, "Y");
                double? w = GetDouble(ctx, "Width");
                double? h = GetDouble(ctx, "Height");
                double margin = GetDouble(ctx, "Margin") ?? 24.0;
                int page = GetInt(ctx, "Page") ?? 1;

                byte[] pdf = FromB64(pdfB64, "PdfContent");
                byte[] img = FromB64(imgB64, "ImageContent");

                byte[] result = Overlay(pdf, img, anchor, x, y, w, h, margin, page);
                ctx.OutputParameters["PdfContent"] = Convert.ToBase64String(result);
            }
            catch (InvalidPluginExecutionException) { throw; }
            catch (Exception ex)
            {
                if (trace != null) trace.Trace("cs_OverlayImageOnPdf error: {0}", ex);
                throw new InvalidPluginExecutionException("cs_OverlayImageOnPdf failed: " + ex.Message);
            }
        }

        internal static byte[] Overlay(byte[] pdfBytes, byte[] imgBytes, string anchor,
            double? x, double? y, double? w, double? h, double margin, int page)
        {
            using (var inMs = new MemoryStream(pdfBytes))
            using (var outMs = new MemoryStream())
            {
                var doc = PdfReader.Open(inMs, PdfDocumentOpenMode.Modify);
                // XImage reads via a stream factory; PdfSharpCore decodes PNG/JPEG itself (no GDI).
                var xi = XImage.FromStream(() => new MemoryStream(imgBytes));

                int from, to;
                if (page <= 0) { from = 0; to = doc.PageCount - 1; }
                else
                {
                    if (page > doc.PageCount)
                        throw new InvalidPluginExecutionException("Page " + page + " is out of range (PDF has " + doc.PageCount + ").");
                    from = to = page - 1;
                }

                for (int p = from; p <= to; p++)
                {
                    var pg = doc.Pages[p];
                    double pw = pg.Width.Point, ph = pg.Height.Point;

                    // --- size ---
                    double dw, dh;
                    if (w.HasValue && h.HasValue) { dw = w.Value; dh = h.Value; }
                    else if (w.HasValue) { dw = w.Value; dh = xi.PixelHeight * (w.Value / xi.PixelWidth); }
                    else if (h.HasValue) { dh = h.Value; dw = xi.PixelWidth * (h.Value / xi.PixelHeight); }
                    else
                    {
                        double box = Math.Max(48.0, Math.Min(120.0, pw * 0.12)); // sensible default
                        double s = Math.Min(box / xi.PixelWidth, box / xi.PixelHeight);
                        dw = xi.PixelWidth * s; dh = xi.PixelHeight * s;
                    }

                    // --- position (top-left origin; PdfSharpCore XGraphics is top-left, Y down) ---
                    double px, py;
                    if (x.HasValue && y.HasValue) { px = x.Value; py = y.Value; }
                    else
                    {
                        switch ((anchor ?? "TopRight").Trim().ToLowerInvariant())
                        {
                            case "topleft": px = margin; py = margin; break;
                            case "bottomleft": px = margin; py = ph - dh - margin; break;
                            case "bottomright": px = pw - dw - margin; py = ph - dh - margin; break;
                            case "center": px = (pw - dw) / 2.0; py = (ph - dh) / 2.0; break;
                            default: /*topright*/ px = pw - dw - margin; py = margin; break;
                        }
                    }

                    using (var gfx = XGraphics.FromPdfPage(pg))
                        gfx.DrawImage(xi, px, py, dw, dh);
                }

                doc.Save(outMs, false);
                return outMs.ToArray();
            }
        }

        private static string GetString(IPluginExecutionContext c, string n, bool required = false)
        {
            if (c.InputParameters.Contains(n) && c.InputParameters[n] is string s && !string.IsNullOrEmpty(s)) return s;
            if (required) throw new InvalidPluginExecutionException("Missing required parameter: " + n);
            return null;
        }
        private static double? GetDouble(IPluginExecutionContext c, string n)
        {
            return (c.InputParameters.Contains(n) && c.InputParameters[n] != null)
                ? Convert.ToDouble(c.InputParameters[n]) : (double?)null;
        }
        private static int? GetInt(IPluginExecutionContext c, string n)
        {
            return (c.InputParameters.Contains(n) && c.InputParameters[n] != null)
                ? Convert.ToInt32(c.InputParameters[n]) : (int?)null;
        }
        private static byte[] FromB64(string s, string name)
        {
            try { return Convert.FromBase64String(s); }
            catch { throw new InvalidPluginExecutionException(name + " is not valid base64."); }
        }
    }
}
