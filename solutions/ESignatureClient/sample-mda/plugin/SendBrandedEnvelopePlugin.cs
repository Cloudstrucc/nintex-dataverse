// =============================================================================
//  SendBrandedEnvelopePlugin  —  DORMANT REFERENCE ONLY (do NOT register as-is)
// =============================================================================
//
//  This is the server-side equivalent of the sample's client-side JavaScript
//  (cs_esign_branded_request.js). It is provided so the team can see how the
//  "composite the party logo onto the template PDF and send ad-hoc" step would
//  look as a plug-in, WITHOUT having to register an assembly for the small demo.
//  The working sample uses the JavaScript web resource instead; this file is
//  intentionally left UNREGISTERED (dormant).
//
//  If you ever want to use it instead of the JS:
//    * Target .NET Framework 4.6.2, reference Microsoft.CrmSdk.CoreAssemblies.
//    * PDF compositing needs a managed PDF library (e.g. PdfSharpCore / PdfSharp).
//      Sandbox (isolation) plugins may only call managed code and a limited API
//      surface, so ILMerge the PDF library into this assembly, or run the plugin
//      in a plug-in registration "None" (full-trust) profile on a dev box.
//    * Register on a CUSTOM ACTION (recommended), e.g. cs_SendBrandedEnvelope,
//      bound to cs_signaturerequest, and call that action from a command-bar
//      button — OR register on Update of a cs_sendnow flag. Post-Operation,
//      synchronous or async.
//
//  Flow of logic (mirrors the JS):
//    1. load the cs_signaturerequest (Title, Template, Signee 1/2, Party logo),
//    2. read the template's TemplateSourcePDF annotation + cs_templatejson,
//    3. composite the logo top-right of page 1,
//    4. create cs_envelope + EnvelopeSourcePDF annotation + recipients,
//    5. set cs_adhocsend = true -> broker "ESign - Send Ad-hoc Envelope" flow.
// =============================================================================

using System;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;

namespace ESign.Client.Sample
{
    public class SendBrandedEnvelopePlugin : IPlugin
    {
        public void Execute(IServiceProvider serviceProvider)
        {
            var context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            var factory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            var service = factory.CreateOrganizationService(context.UserId);
            var trace = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            // The record the action/button was invoked against.
            var requestRef = context.PrimaryEntityId != Guid.Empty
                ? new EntityReference("cs_signaturerequest", context.PrimaryEntityId)
                : (context.InputParameters.Contains("Target") ? (EntityReference)context.InputParameters["Target"] : null);
            if (requestRef == null) throw new InvalidPluginExecutionException("No cs_signaturerequest target.");

            var req = service.Retrieve("cs_signaturerequest", requestRef.Id,
                new ColumnSet("cs_title", "cs_description", "cs_template", "cs_signee1", "cs_signee2", "cs_partylogo"));

            var templateRef = req.GetAttributeValue<EntityReference>("cs_template");
            if (templateRef == null) throw new InvalidPluginExecutionException("Pick a Template first.");

            // 1. template json (layout + signer labels)
            var tpl = service.Retrieve("cs_template", templateRef.Id, new ColumnSet("cs_name", "cs_templatejson"));
            var templateJson = tpl.GetAttributeValue<string>("cs_templatejson") ?? "{}";
            var signerLabels = ParseSignerLabels(templateJson); // ["Primary Signer", "Signer 2", ...]

            // 2. template source PDF (annotation)
            byte[] pdfBytes = GetAnnotationBody(service, "cs_template", templateRef.Id, "TemplateSourcePDF");
            if (pdfBytes == null) throw new InvalidPluginExecutionException("Template has no TemplateSourcePDF to brand.");

            // 3. party logo (File column) — download via the File column API
            byte[] logoBytes = DownloadFileColumn(service, "cs_signaturerequest", requestRef.Id, "cs_partylogo");

            // 4. composite logo top-right of page 1  (needs a managed PDF library)
            byte[] brandedPdf = CompositeLogo(pdfBytes, logoBytes); // see note below

            // 5. recipients from the two contact lookups (match signer labels by order)
            var recipients = new List<object>();
            AddRecipient(service, recipients, req.GetAttributeValue<EntityReference>("cs_signee1"),
                signerLabels.ElementAtOrDefault(0) ?? "Primary Signer");
            if (signerLabels.Count > 1)
                AddRecipient(service, recipients, req.GetAttributeValue<EntityReference>("cs_signee2"),
                    signerLabels[1]);

            var title = req.GetAttributeValue<string>("cs_title") ?? "Signature request";
            var envelopeJson = BuildEnvelopeJson(templateRef.Id, tpl.GetAttributeValue<string>("cs_name"), recipients);

            // 6. create the envelope (same-env sample; point at the broker org in production)
            var envelope = new Entity("cs_envelope")
            {
                ["cs_name"] = title,
                ["cs_subject"] = title,
                ["cs_templateid"] = templateRef.Id.ToString(),
                ["cs_envelopejson"] = envelopeJson,
                ["statuscode"] = new OptionSetValue(1)
            };
            var envelopeId = service.Create(envelope);

            // 7. attach the branded PDF
            service.Create(new Entity("annotation")
            {
                ["subject"] = "EnvelopeSourcePDF",
                ["filename"] = "branded.pdf",
                ["mimetype"] = "application/pdf",
                ["documentbody"] = Convert.ToBase64String(brandedPdf),
                ["objectid"] = new EntityReference("cs_envelope", envelopeId)
            });

            // 8. flip cs_adhocsend -> broker "ESign - Send Ad-hoc Envelope" flow submits
            service.Update(new Entity("cs_envelope") { Id = envelopeId, ["cs_adhocsend"] = true });

            trace.Trace("Branded envelope {0} created and queued for ad-hoc send.", envelopeId);
        }

        // ---- helpers (sketched; fill in with your JSON + PDF libraries) --------

        private static List<string> ParseSignerLabels(string templateJson)
        {
            // Use your JSON serializer (e.g. System.Text.Json / Newtonsoft) to read
            // templateJson.signers[].label. Returned list drives recipient order.
            return new List<string> { "Primary Signer", "Signer 2" };
        }

        private static byte[] GetAnnotationBody(IOrganizationService service, string entity, Guid id, string subject)
        {
            var q = new QueryExpression("annotation")
            {
                ColumnSet = new ColumnSet("documentbody"),
                TopCount = 1,
                Criteria = new FilterExpression
                {
                    Conditions =
                    {
                        new ConditionExpression("objectid", ConditionOperator.Equal, id),
                        new ConditionExpression("subject", ConditionOperator.Equal, subject)
                    }
                }
            };
            var note = service.RetrieveMultiple(q).Entities.FirstOrDefault();
            var body = note?.GetAttributeValue<string>("documentbody");
            return string.IsNullOrEmpty(body) ? null : Convert.FromBase64String(body);
        }

        private static byte[] DownloadFileColumn(IOrganizationService service, string entity, Guid id, string column)
        {
            // Use InitializeFileBlocksDownload + DownloadBlock messages to stream the
            // File column bytes. Returns null if no file uploaded.
            // (Omitted for brevity in this dormant reference.)
            return null;
        }

        private static byte[] CompositeLogo(byte[] pdfBytes, byte[] logoBytes)
        {
            // Draw logoBytes onto page 1, top-right, using a managed PDF library
            // (PdfSharpCore). If logoBytes is null, return pdfBytes unchanged.
            // Equivalent to the pdf-lib drawImage call in the JS sample.
            return pdfBytes;
        }

        private static void AddRecipient(IOrganizationService service, List<object> list, EntityReference contactRef, string role)
        {
            if (contactRef == null) return;
            var c = service.Retrieve("contact", contactRef.Id, new ColumnSet("fullname", "emailaddress1"));
            list.Add(new
            {
                role,
                name = c.GetAttributeValue<string>("fullname") ?? contactRef.Name ?? "Signer",
                email = c.GetAttributeValue<string>("emailaddress1") ?? ""
            });
        }

        private static string BuildEnvelopeJson(Guid templateId, string templateName, List<object> recipients)
        {
            // Serialize { templateId, templateName, recipients } with your JSON library.
            var sb = new StringBuilder();
            sb.Append("{\"templateId\":\"").Append(templateId).Append("\",");
            sb.Append("\"templateName\":").Append(JsonString(templateName)).Append(",");
            sb.Append("\"recipients\":[]}"); // replace [] with serialized recipients
            return sb.ToString();
        }

        private static string JsonString(string s) =>
            "\"" + (s ?? "").Replace("\\", "\\\\").Replace("\"", "\\\"") + "\"";
    }
}
