// OverlayBase.cs — shared Custom API plumbing + size/position math for both overlay engines.
using System;
using Microsoft.Xrm.Sdk;

namespace CSPdfImageOverlay
{
    /// <summary>Parsed overlay options (same contract for both engines).</summary>
    public struct OverlayOpts
    {
        public string Anchor;
        public double? X, Y, Width, Height;
        public double Margin;
        public int Page; // 1-based; 0 = all pages
    }

    public abstract class OverlayBase : IPlugin
    {
        protected abstract string ApiName { get; }
        protected abstract byte[] Overlay(byte[] pdf, byte[] img, OverlayOpts o);

        public void Execute(IServiceProvider sp)
        {
            var ctx = (IPluginExecutionContext)sp.GetService(typeof(IPluginExecutionContext));
            var trace = (ITracingService)sp.GetService(typeof(ITracingService));
            try
            {
                byte[] pdf = FromB64(GetString(ctx, "PdfContent", true), "PdfContent");
                byte[] img = FromB64(GetString(ctx, "ImageContent", true), "ImageContent");
                var o = new OverlayOpts
                {
                    Anchor = GetString(ctx, "Anchor") ?? "TopRight",
                    X = GetD(ctx, "X"), Y = GetD(ctx, "Y"),
                    Width = GetD(ctx, "Width"), Height = GetD(ctx, "Height"),
                    Margin = GetD(ctx, "Margin") ?? 24.0,
                    Page = GetI(ctx, "Page") ?? 1
                };
                ctx.OutputParameters["PdfContent"] = Convert.ToBase64String(Overlay(pdf, img, o));
            }
            catch (InvalidPluginExecutionException) { throw; }
            catch (Exception ex)
            {
                if (trace != null) trace.Trace(ApiName + " error: {0}", ex);
                throw new InvalidPluginExecutionException(ApiName + " failed: " + ex.Message);
            }
        }

        /// <summary>Compute draw size (dw,dh) and TOP-LEFT origin position (px,pyTop).</summary>
        protected static void Fit(double imgW, double imgH, double pageW, double pageH, OverlayOpts o,
            out double dw, out double dh, out double px, out double pyTop)
        {
            if (o.Width.HasValue && o.Height.HasValue) { dw = o.Width.Value; dh = o.Height.Value; }
            else if (o.Width.HasValue) { dw = o.Width.Value; dh = imgH * (o.Width.Value / imgW); }
            else if (o.Height.HasValue) { dh = o.Height.Value; dw = imgW * (o.Height.Value / imgH); }
            else
            {
                double box = Math.Max(48.0, Math.Min(120.0, pageW * 0.12));
                double s = Math.Min(box / imgW, box / imgH);
                dw = imgW * s; dh = imgH * s;
            }
            if (o.X.HasValue && o.Y.HasValue) { px = o.X.Value; pyTop = o.Y.Value; return; }
            switch ((o.Anchor ?? "TopRight").Trim().ToLowerInvariant())
            {
                case "topleft": px = o.Margin; pyTop = o.Margin; break;
                case "bottomleft": px = o.Margin; pyTop = pageH - dh - o.Margin; break;
                case "bottomright": px = pageW - dw - o.Margin; pyTop = pageH - dh - o.Margin; break;
                case "center": px = (pageW - dw) / 2.0; pyTop = (pageH - dh) / 2.0; break;
                default: px = pageW - dw - o.Margin; pyTop = o.Margin; break; // TopRight
            }
        }

        protected static string GetString(IPluginExecutionContext c, string n, bool required = false)
        {
            if (c.InputParameters.Contains(n) && c.InputParameters[n] is string s && !string.IsNullOrEmpty(s)) return s;
            if (required) throw new InvalidPluginExecutionException("Missing required parameter: " + n);
            return null;
        }
        // Dataverse delivers *optional* Custom API parameters with their type default rather than
        // omitting them, so Contains() is always true and an unsupplied Decimal arrives as 0. Taking
        // that at face value made Width/Height both "supplied" as 0 (a degenerate "0 0 0 0 .. cm"
        // transform: the image embeds but draws at zero size) and made X/Y=0 override the anchor.
        // Treat a non-positive number as "not supplied"; to sit flush at an edge pass e.g. 0.01.
        protected static double? GetD(IPluginExecutionContext c, string n)
        {
            if (!c.InputParameters.Contains(n) || c.InputParameters[n] == null) return null;
            double v = Convert.ToDouble(c.InputParameters[n]);
            return v > 0.0 ? v : (double?)null;
        }
        // Same story for Integer: 0 means "not supplied" (-> page 1). A negative value means all pages.
        protected static int? GetI(IPluginExecutionContext c, string n)
        {
            if (!c.InputParameters.Contains(n) || c.InputParameters[n] == null) return null;
            int v = Convert.ToInt32(c.InputParameters[n]);
            return v != 0 ? v : (int?)null;
        }
        protected static byte[] FromB64(string s, string name)
        {
            try { return Convert.FromBase64String(s); }
            catch { throw new InvalidPluginExecutionException(name + " is not valid base64."); }
        }
    }
}
