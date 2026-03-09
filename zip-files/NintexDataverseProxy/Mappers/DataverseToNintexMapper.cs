using System;
using System.Linq;
using Microsoft.Xrm.Sdk;
using Newtonsoft.Json.Linq;

namespace NintexDataverseProxy.Mappers
{
    /// <summary>
    /// Maps Dataverse entities to Nintex API payloads
    /// </summary>
    public class DataverseToNintexMapper
    {
        /// <summary>
        /// Map Dataverse Envelope entity to Nintex submit payload
        /// </summary>
        public static JObject MapEnvelopeToSubmitPayload(Entity envelope)
        {
            var payload = new JObject();

            // Template ID if using template
            if (envelope.Contains("cs_templateid"))
            {
                payload["TemplateID"] = envelope.GetAttributeValue<string>("cs_templateid");
            }

            // Subject and message
            if (envelope.Contains("cs_subject"))
            {
                payload["Subject"] = envelope.GetAttributeValue<string>("cs_subject");
            }

            if (envelope.Contains("cs_message"))
            {
                payload["Message"] = envelope.GetAttributeValue<string>("cs_message");
            }

            // Expiration settings
            if (envelope.Contains("cs_daystoexpire"))
            {
                payload["DaysToExpire"] = envelope.GetAttributeValue<int>("cs_daystoexpire");
            }

            if (envelope.Contains("cs_reminderfrequency"))
            {
                payload["ReminderFrequency"] = envelope.GetAttributeValue<int>("cs_reminderfrequency");
            }

            // URLs
            if (envelope.Contains("cs_redirecturl"))
            {
                payload["RedirectURL"] = envelope.GetAttributeValue<string>("cs_redirecturl");
            }

            if (envelope.Contains("cs_callbackurl"))
            {
                payload["CallbackURL"] = envelope.GetAttributeValue<string>("cs_callbackurl");
            }

            // Processing mode
            if (envelope.Contains("cs_processingmode"))
            {
                payload["ProcessingMode"] = envelope.GetAttributeValue<string>("cs_processingmode");
            }

            return payload;
        }

        /// <summary>
        /// Map Dataverse Signer entity to Nintex signer object
        /// </summary>
        public static JObject MapSignerToNintexSigner(Entity signer)
        {
            var signerObj = new JObject();

            if (signer.Contains("cs_email"))
            {
                signerObj["Email"] = signer.GetAttributeValue<string>("cs_email");
            }

            if (signer.Contains("cs_fullname"))
            {
                signerObj["FullName"] = signer.GetAttributeValue<string>("cs_fullname");
            }

            if (signer.Contains("cs_signerorder"))
            {
                signerObj["SignerOrder"] = signer.GetAttributeValue<int>("cs_signerorder");
            }

            if (signer.Contains("cs_phonenumber"))
            {
                signerObj["PhoneNumber"] = signer.GetAttributeValue<string>("cs_phonenumber");
            }

            if (signer.Contains("cs_language"))
            {
                signerObj["Language"] = signer.GetAttributeValue<string>("cs_language");
            }

            if (signer.Contains("cs_authenticationtype"))
            {
                signerObj["AuthenticationType"] = signer.GetAttributeValue<string>("cs_authenticationtype");
            }

            if (signer.Contains("cs_password"))
            {
                signerObj["AccessCode"] = signer.GetAttributeValue<string>("cs_password");
            }

            return signerObj;
        }

        /// <summary>
        /// Map Dataverse Document entity to Nintex document object
        /// </summary>
        public static JObject MapDocumentToNintexDocument(Entity document)
        {
            var docObj = new JObject();

            if (document.Contains("cs_filename"))
            {
                docObj["FileName"] = document.GetAttributeValue<string>("cs_filename");
            }

            if (document.Contains("cs_filecontent"))
            {
                // Assume base64 encoded content
                docObj["FileContent"] = document.GetAttributeValue<string>("cs_filecontent");
            }

            if (document.Contains("cs_documentorder"))
            {
                docObj["DocumentOrder"] = document.GetAttributeValue<int>("cs_documentorder");
            }

            return docObj;
        }

        /// <summary>
        /// Map Dataverse Field entity to Nintex JotBlock
        /// </summary>
        public static JObject MapFieldToNintexJotBlock(Entity field)
        {
            var jotBlock = new JObject();

            if (field.Contains("cs_fieldtype"))
            {
                jotBlock["Type"] = field.GetAttributeValue<string>("cs_fieldtype");
            }

            if (field.Contains("cs_positionx"))
            {
                jotBlock["X"] = field.GetAttributeValue<decimal>("cs_positionx");
            }

            if (field.Contains("cs_positiony"))
            {
                jotBlock["Y"] = field.GetAttributeValue<decimal>("cs_positiony");
            }

            if (field.Contains("cs_width"))
            {
                jotBlock["Width"] = field.GetAttributeValue<decimal>("cs_width");
            }

            if (field.Contains("cs_height"))
            {
                jotBlock["Height"] = field.GetAttributeValue<decimal>("cs_height");
            }

            if (field.Contains("cs_pagenumber"))
            {
                jotBlock["PageNumber"] = field.GetAttributeValue<int>("cs_pagenumber");
            }

            if (field.Contains("cs_isrequired"))
            {
                jotBlock["IsRequired"] = field.GetAttributeValue<bool>("cs_isrequired");
            }

            if (field.Contains("cs_defaultvalue"))
            {
                jotBlock["DefaultValue"] = field.GetAttributeValue<string>("cs_defaultvalue");
            }

            return jotBlock;
        }

        /// <summary>
        /// Update Dataverse Envelope from Nintex response
        /// </summary>
        public static void UpdateEnvelopeFromNintexResponse(Entity envelope, JObject nintexResponse)
        {
            if (nintexResponse["EnvelopeID"] != null)
            {
                envelope["cs_envelopeid"] = nintexResponse["EnvelopeID"].ToString();
            }

            if (nintexResponse["Status"] != null)
            {
                envelope["cs_status"] = nintexResponse["Status"].ToString();
            }

            if (nintexResponse["SentDate"] != null)
            {
                envelope["cs_sentdate"] = nintexResponse["SentDate"].ToObject<DateTime>();
            }

            if (nintexResponse["CompletedDate"] != null)
            {
                envelope["cs_completeddate"] = nintexResponse["CompletedDate"].ToObject<DateTime>();
            }

            // Store full response
            envelope["cs_responsebody"] = nintexResponse.ToString();
        }

        /// <summary>
        /// Update Dataverse Signer from Nintex response
        /// </summary>
        public static void UpdateSignerFromNintexResponse(Entity signer, JObject nintexSigner)
        {
            if (nintexSigner["SignerID"] != null)
            {
                signer["cs_signerid"] = nintexSigner["SignerID"].ToString();
            }

            if (nintexSigner["Status"] != null)
            {
                signer["cs_signerstatus"] = nintexSigner["Status"].ToString();
            }

            if (nintexSigner["SignedDate"] != null)
            {
                signer["cs_signeddate"] = nintexSigner["SignedDate"].ToObject<DateTime>();
            }

            if (nintexSigner["ViewedDate"] != null)
            {
                signer["cs_vieweddate"] = nintexSigner["ViewedDate"].ToObject<DateTime>();
            }

            if (nintexSigner["SigningLink"] != null)
            {
                signer["cs_signinglink"] = nintexSigner["SigningLink"].ToString();
            }
        }
    }
}
