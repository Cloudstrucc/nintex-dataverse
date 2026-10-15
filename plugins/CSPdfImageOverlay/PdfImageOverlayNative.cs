// PdfImageOverlayNative.cs — version B (dependency-free). Custom API: cs_OverlayImageOnPdf.
// Stamps an image onto a PDF via an incremental update, with NO third-party libraries.
// Scope: classic cross-reference-table PDFs (not xref/object streams); inline page /Resources.
// Images: JPEG (DCTDecode) and opaque 8-bit PNG (grayscale/RGB, non-interlaced, via FlateDecode
//         with the PNG predictor). Transparency/palette/interlaced PNG -> use cs_OverlayImageOnPdfX.
using System;
using System.Globalization;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.Xrm.Sdk;

namespace CSPdfImageOverlay
{
    public class PdfImageOverlayNative : OverlayBase
    {
        protected override string ApiName { get { return "cs_OverlayImageOnPdf"; } }
        private static readonly Encoding L = Encoding.GetEncoding(28591); // ISO-8859-1 (1 byte = 1 char)
        private static readonly CultureInfo IC = CultureInfo.InvariantCulture;

        private static void Fail(string m) { throw new InvalidPluginExecutionException(m); }
        private static string Unsupported(string why)
        { return why + " is not supported by the native engine (cs_OverlayImageOnPdf); use cs_OverlayImageOnPdfX (iText)."; }

        protected override byte[] Overlay(byte[] pdf, byte[] img, OverlayOpts o)
        {
            string s = L.GetString(pdf);
            if (!s.StartsWith("%PDF")) Fail("Not a PDF.");
            if (s.Contains("/XRef")) Fail(Unsupported("Cross-reference stream PDFs"));

            int sxIdx = s.LastIndexOf("startxref", StringComparison.Ordinal);
            if (sxIdx < 0) Fail(Unsupported("PDFs without a startxref"));
            long oldStartxref = long.Parse(Regex.Match(s.Substring(sxIdx), @"startxref\s+(\d+)").Groups[1].Value, IC);

            var rootM = Regex.Match(s, @"/Root\s+(\d+\s+\d+\s+R)");
            if (!rootM.Success) Fail("No /Root in trailer.");
            string rootRef = rootM.Groups[1].Value;

            // --- locate the target /Page object (in file order; fine for single-page templates) ---
            var objRe = new Regex(@"(\d+)\s+(\d+)\s+obj\b([\s\S]*?)endobj", RegexOptions.Singleline);
            Match pageM = null; int seen = 0;
            foreach (Match m in objRe.Matches(s))
            {
                if (!Regex.IsMatch(m.Groups[3].Value, @"/Type\s*/Page(?![a-zA-Z])")) continue;
                seen++;
                if (o.Page <= 0 || seen == o.Page) { pageM = m; break; }
                if (pageM == null) pageM = m;
            }
            if (pageM == null) Fail("No /Page object found.");
            int pageObjNum = int.Parse(pageM.Groups[1].Value, IC);
            int pageGen = int.Parse(pageM.Groups[2].Value, IC);
            string pageBody = pageM.Groups[3].Value;

            double pageW = 612, pageH = 792;
            var mb = Regex.Match(pageBody, @"/MediaBox\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]");
            if (mb.Success)
            {
                pageW = double.Parse(mb.Groups[3].Value, IC) - double.Parse(mb.Groups[1].Value, IC);
                pageH = double.Parse(mb.Groups[4].Value, IC) - double.Parse(mb.Groups[2].Value, IC);
            }

            // --- decode the image into a PDF image XObject (dict fragment + stream bytes) ---
            int iw, ih; string imgDict; byte[] imgStream;
            BuildImageXObject(img, out iw, out ih, out imgDict, out imgStream);

            double dw, dh, px, pyTop;
            Fit(iw, ih, pageW, pageH, o, out dw, out dh, out px, out pyTop);
            double pyB = pageH - pyTop - dh; // PDF content stream origin is bottom-left

            // --- new object numbers ---
            int maxObj = 0;
            foreach (Match m in Regex.Matches(s, @"(\d+)\s+\d+\s+obj\b"))
                maxObj = Math.Max(maxObj, int.Parse(m.Groups[1].Value, IC));
            var szM = Regex.Match(s, @"/Size\s+(\d+)");
            if (szM.Success) maxObj = Math.Max(maxObj, int.Parse(szM.Groups[1].Value, IC) - 1);
            int imgObj = maxObj + 1, contentObj = maxObj + 2, newSize = maxObj + 3;
            string xname = "ECImg" + imgObj;

            string content = string.Format(IC, "q {0:0.###} 0 0 {1:0.###} {2:0.###} {3:0.###} cm /{4} Do Q",
                dw, dh, px, pyB, xname);
            byte[] contentBytes = L.GetBytes(content);

            string newPageBody = RewritePage(pageBody, contentObj, imgObj, xname);

            // --- assemble incremental update ---
            using (var ms = new MemoryStream())
            {
                ms.Write(pdf, 0, pdf.Length);
                if (pdf.Length == 0 || pdf[pdf.Length - 1] != (byte)'\n') W(ms, "\n");

                long offImg = ms.Position;
                W(ms, imgObj + " 0 obj\n<< /Type /XObject /Subtype /Image /Width " + iw + " /Height " + ih +
                     " " + imgDict + " /Length " + imgStream.Length + " >>\nstream\n");
                ms.Write(imgStream, 0, imgStream.Length);
                W(ms, "\nendstream\nendobj\n");

                long offContent = ms.Position;
                W(ms, contentObj + " 0 obj\n<< /Length " + contentBytes.Length + " >>\nstream\n");
                ms.Write(contentBytes, 0, contentBytes.Length);
                W(ms, "\nendstream\nendobj\n");

                long offPage = ms.Position;
                W(ms, pageObjNum + " " + pageGen + " obj\n" + newPageBody.Trim() + "\nendobj\n");

                long xrefPos = ms.Position;
                var x = new StringBuilder();
                x.Append("xref\n");
                x.Append(pageObjNum + " 1\n").Append(XrefLine(offPage, pageGen));
                x.Append(imgObj + " 2\n").Append(XrefLine(offImg, 0)).Append(XrefLine(offContent, 0));
                x.Append("trailer\n<< /Size " + newSize + " /Root " + rootRef + " /Prev " + oldStartxref + " >>\n");
                x.Append("startxref\n" + xrefPos + "\n%%EOF\n");
                W(ms, x.ToString());

                return ms.ToArray();
            }
        }

        private static void W(Stream s, string t) { var b = L.GetBytes(t); s.Write(b, 0, b.Length); }
        private static string XrefLine(long off, int gen)
        { return off.ToString("D10", IC) + " " + gen.ToString("D5", IC) + " n\r\n"; } // exactly 20 bytes

        // ---- page dict surgery: add our content stream + image XObject ----
        private static string RewritePage(string body, int contentObj, int imgObj, string xname)
        {
            string add = contentObj + " 0 R";
            // /Contents
            if (Regex.IsMatch(body, @"/Contents\s*\["))
                body = Regex.Replace(body, @"(/Contents\s*\[)([\s\S]*?)(\])", "$1$2 " + add + " $3");
            else if (Regex.IsMatch(body, @"/Contents\s+\d+\s+\d+\s+R"))
                body = Regex.Replace(body, @"/Contents\s+(\d+\s+\d+\s+R)", "/Contents [$1 " + add + "]");
            else
                Fail("Page has no /Contents to extend.");

            // /Resources -> /XObject
            string xentry = "/" + xname + " " + imgObj + " 0 R";
            if (Regex.IsMatch(body, @"/Resources\s+\d+\s+\d+\s+R"))
                Fail(Unsupported("Pages whose /Resources is an indirect object"));
            else if (Regex.IsMatch(body, @"/Resources\s*<<"))
            {
                if (Regex.IsMatch(body, @"/XObject\s*<<"))
                    body = new Regex(@"/XObject\s*<<").Replace(body, "/XObject << " + xentry + " ", 1);
                else
                    body = new Regex(@"/Resources\s*<<").Replace(body, "/Resources << /XObject << " + xentry + " >> ", 1);
            }
            else
            {
                // no /Resources: inject before the final >> of the page dict
                int close = body.LastIndexOf(">>", StringComparison.Ordinal);
                if (close < 0) Fail("Malformed page dictionary.");
                body = body.Substring(0, close) + " /Resources << /XObject << " + xentry + " >> >> " + body.Substring(close);
            }
            return body;
        }

        // ---- image decoding (JPEG + opaque 8-bit PNG) ----
        private static void BuildImageXObject(byte[] img, out int w, out int h, out string dict, out byte[] stream)
        {
            if (img.Length > 2 && img[0] == 0xFF && img[1] == 0xD8) { Jpeg(img, out w, out h, out dict, out stream); return; }
            if (img.Length > 8 && img[0] == 0x89 && img[1] == 0x50 && img[2] == 0x4E && img[3] == 0x47) { Png(img, out w, out h, out dict, out stream); return; }
            Fail("Unsupported image format (expected JPEG or PNG)."); w = h = 0; dict = null; stream = null;
        }

        private static void Jpeg(byte[] b, out int w, out int h, out string dict, out byte[] stream)
        {
            w = h = 0; int comps = 3; int i = 2;
            while (i + 1 < b.Length)
            {
                if (b[i] != 0xFF) { i++; continue; }
                int marker = b[i + 1]; i += 2;
                if (marker == 0xD8 || marker == 0xD9 || (marker >= 0xD0 && marker <= 0xD7)) continue;
                if (i + 1 >= b.Length) break;
                int len = (b[i] << 8) | b[i + 1];
                // SOF markers (C0..CF) except DHT(C4), JPG(C8), DAC(CC)
                if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC)
                {
                    h = (b[i + 3] << 8) | b[i + 4];
                    w = (b[i + 5] << 8) | b[i + 6];
                    comps = b[i + 7];
                    break;
                }
                i += len;
            }
            if (w == 0 || h == 0) Fail("Could not read JPEG dimensions.");
            string cs = comps == 1 ? "/DeviceGray" : comps == 4 ? "/DeviceCMYK" : "/DeviceRGB";
            dict = "/ColorSpace " + cs + " /BitsPerComponent 8 /Filter /DCTDecode";
            if (comps == 4) dict += " /Decode [1 0 1 0 1 0 1 0]"; // common Adobe-inverted CMYK
            stream = b;
        }

        private static void Png(byte[] b, out int w, out int h, out string dict, out byte[] stream)
        {
            w = h = 0; int bitDepth = 0, colorType = 0, interlace = 0;
            var idat = new MemoryStream();
            int p = 8;
            while (p + 8 <= b.Length)
            {
                int len = (b[p] << 24) | (b[p + 1] << 16) | (b[p + 2] << 8) | b[p + 3];
                string type = Encoding.ASCII.GetString(b, p + 4, 4);
                int data = p + 8;
                if (type == "IHDR")
                {
                    w = (b[data] << 24) | (b[data + 1] << 16) | (b[data + 2] << 8) | b[data + 3];
                    h = (b[data + 4] << 24) | (b[data + 5] << 16) | (b[data + 6] << 8) | b[data + 7];
                    bitDepth = b[data + 8]; colorType = b[data + 9]; interlace = b[data + 12];
                }
                else if (type == "IDAT") idat.Write(b, data, len);
                else if (type == "IEND") break;
                p = data + len + 4; // skip data + CRC
            }
            if (w == 0 || h == 0) Fail("Could not read PNG dimensions.");
            if (interlace != 0) Fail(Unsupported("Interlaced PNG"));
            if (bitDepth != 8) Fail(Unsupported("PNG bit depth " + bitDepth));
            int colors;
            string cs;
            if (colorType == 0) { colors = 1; cs = "/DeviceGray"; }
            else if (colorType == 2) { colors = 3; cs = "/DeviceRGB"; }
            else Fail(Unsupported("PNG color type " + colorType + " (transparency/palette)")); // 3,4,6
            colors = colorType == 0 ? 1 : 3; cs = colorType == 0 ? "/DeviceGray" : "/DeviceRGB";
            dict = "/ColorSpace " + cs + " /BitsPerComponent 8 /Filter /FlateDecode" +
                   " /DecodeParms << /Predictor 15 /Colors " + colors + " /Columns " + w + " /BitsPerComponent 8 >>";
            stream = idat.ToArray(); // IDAT is already a zlib stream; PDF FlateDecode reads it directly
        }
    }
}
