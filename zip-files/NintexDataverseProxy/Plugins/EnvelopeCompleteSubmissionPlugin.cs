using System;
using System.Linq;
using System.ServiceModel;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using NintexDataverseProxy.Services;
using NintexDataverseProxy.Mappers;
using Newtonsoft.Json.Linq;

namespace NintexDataverseProxy.Plugins
{
    /// <summary>
    /// Advanced envelope plugin that handles complete submission with related entities
    /// </summary>
    public class EnvelopeCompleteSubmissionPlugin : IPlugin
    {
        private readonly string _secureConfig;
        private readonly string _unsecureConfig;

        public EnvelopeCompleteSubmissionPlugin(string unsecureConfig, string secureConfig)
        {
            _unsecureConfig = unsecureConfig;
            _secureConfig = secureConfig;
        }

        public void Execute(IServiceProvider serviceProvider)
        {
            IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            IOrganizationService service = serviceFactory.CreateOrganizationService(context.UserId);
            ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            try
            {
                if (context.MessageName.ToUpper() != "CREATE")
                {
                    return;
                }

                Entity envelope = (Entity)context.InputParameters["Target"];
                tracingService.Trace($"EnvelopeCompleteSubmissionPlugin: Processing envelope {envelope.Id}");

                // Get configuration
                var config = JObject.Parse(_secureConfig);
                string nintexApiUrl = config["ApiUrl"].ToString();
                string apiUsername = config["ApiUsername"].ToString();
                string apiKey = config["ApiKey"].ToString();
                string contextUsername = config["ContextUsername"].ToString();

                // Create and authenticate client
                var nintexClient = new NintexApiClient(nintexApiUrl);
                var authTask = nintexClient.AuthenticateAsync(apiUsername, apiKey, contextUsername);
                authTask.Wait();

                if (!authTask.Result)
                {
                    throw new InvalidPluginExecutionException("Failed to authenticate with Nintex API");
                }

                // Build complete submission payload
                JObject submitPayload = BuildCompleteSubmissionPayload(envelope, service, tracingService);

                tracingService.Trace($"Complete payload: {submitPayload.ToString()}");

                // Store request
                envelope["cs_requestbody"] = submitPayload.ToString();

                // Submit to Nintex
                var submitTask = nintexClient.SubmitEnvelopeAsync(submitPayload);
                submitTask.Wait();
                var response = submitTask.Result;

                tracingService.Trace($"Nintex response: {response.ToString()}");

                // Update envelope with response
                DataverseToNintexMapper.UpdateEnvelopeFromNintexResponse(envelope, response);

                // Update related signers with their IDs and signing links
                UpdateRelatedSigners(envelope.Id, response, service, tracingService);

                // Log the API request
                LogApiRequest(envelope.Id, "POST", "/submit", submitPayload.ToString(), 
                             response.ToString(), 200, service);

                tracingService.Trace("EnvelopeCompleteSubmissionPlugin: Completed successfully");
            }
            catch (Exception ex)
            {
                tracingService.Trace($"EnvelopeCompleteSubmissionPlugin Error: {ex.ToString()}");
                throw new InvalidPluginExecutionException($"Error submitting envelope: {ex.Message}", ex);
            }
        }

        /// <summary>
        /// Build complete submission payload with signers, documents, and fields
        /// </summary>
        private JObject BuildCompleteSubmissionPayload(Entity envelope, IOrganizationService service, ITracingService trace)
        {
            var payload = DataverseToNintexMapper.MapEnvelopeToSubmitPayload(envelope);

            // Retrieve and add signers
            var signers = RetrieveRelatedSigners(envelope.Id, service, trace);
            if (signers.Any())
            {
                var signersArray = new JArray();
                foreach (var signer in signers)
                {
                    signersArray.Add(DataverseToNintexMapper.MapSignerToNintexSigner(signer));
                }
                payload["Signers"] = signersArray;
                trace.Trace($"Added {signers.Count} signers to payload");
            }

            // Retrieve and add documents
            var documents = RetrieveRelatedDocuments(envelope.Id, service, trace);
            if (documents.Any())
            {
                var documentsArray = new JArray();
                foreach (var doc in documents)
                {
                    var docObj = DataverseToNintexMapper.MapDocumentToNintexDocument(doc);
                    
                    // Add fields/JotBlocks for this document
                    var fields = RetrieveDocumentFields(doc.Id, service, trace);
                    if (fields.Any())
                    {
                        var jotBlocksArray = new JArray();
                        foreach (var field in fields)
                        {
                            jotBlocksArray.Add(DataverseToNintexMapper.MapFieldToNintexJotBlock(field));
                        }
                        docObj["JotBlocks"] = jotBlocksArray;
                    }
                    
                    documentsArray.Add(docObj);
                }
                payload["Documents"] = documentsArray;
                trace.Trace($"Added {documents.Count} documents to payload");
            }

            return payload;
        }

        /// <summary>
        /// Retrieve signers related to the envelope
        /// </summary>
        private EntityCollection RetrieveRelatedSigners(Guid envelopeId, IOrganizationService service, ITracingService trace)
        {
            var query = new QueryExpression("cs_signer")
            {
                ColumnSet = new ColumnSet(true),
                Criteria = new FilterExpression
                {
                    Conditions =
                    {
                        new ConditionExpression("cs_envelopeid", ConditionOperator.Equal, envelopeId)
                    }
                },
                Orders =
                {
                    new OrderExpression("cs_signerorder", OrderType.Ascending)
                }
            };

            return service.RetrieveMultiple(query);
        }

        /// <summary>
        /// Retrieve documents related to the envelope
        /// </summary>
        private EntityCollection RetrieveRelatedDocuments(Guid envelopeId, IOrganizationService service, ITracingService trace)
        {
            var query = new QueryExpression("cs_document")
            {
                ColumnSet = new ColumnSet(true),
                Criteria = new FilterExpression
                {
                    Conditions =
                    {
                        new ConditionExpression("cs_envelopeid", ConditionOperator.Equal, envelopeId)
                    }
                },
                Orders =
                {
                    new OrderExpression("cs_documentorder", OrderType.Ascending)
                }
            };

            return service.RetrieveMultiple(query);
        }

        /// <summary>
        /// Retrieve fields/JotBlocks for a document
        /// </summary>
        private EntityCollection RetrieveDocumentFields(Guid documentId, IOrganizationService service, ITracingService trace)
        {
            var query = new QueryExpression("cs_field")
            {
                ColumnSet = new ColumnSet(true),
                Criteria = new FilterExpression
                {
                    Conditions =
                    {
                        new ConditionExpression("cs_documentid", ConditionOperator.Equal, documentId)
                    }
                }
            };

            return service.RetrieveMultiple(query);
        }

        /// <summary>
        /// Update related signers with Nintex response data
        /// </summary>
        private void UpdateRelatedSigners(Guid envelopeId, JObject response, IOrganizationService service, ITracingService trace)
        {
            try
            {
                // Get signers from response
                var nintexSigners = response["Signers"] as JArray;
                if (nintexSigners == null || !nintexSigners.Any())
                {
                    trace.Trace("No signers in response");
                    return;
                }

                // Get Dataverse signers
                var dataverseSigners = RetrieveRelatedSigners(envelopeId, service, trace);

                // Match and update by order
                for (int i = 0; i < Math.Min(nintexSigners.Count, dataverseSigners.Entities.Count); i++)
                {
                    var nintexSigner = nintexSigners[i] as JObject;
                    var dataverseSigner = dataverseSigners.Entities
                        .OrderBy(s => s.GetAttributeValue<int>("cs_signerorder"))
                        .ElementAt(i);

                    Entity updateSigner = new Entity("cs_signer", dataverseSigner.Id);
                    DataverseToNintexMapper.UpdateSignerFromNintexResponse(updateSigner, nintexSigner);
                    
                    service.Update(updateSigner);
                    trace.Trace($"Updated signer {i + 1}");
                }
            }
            catch (Exception ex)
            {
                trace.Trace($"Error updating signers: {ex.Message}");
                // Don't fail the whole operation if signer update fails
            }
        }

        /// <summary>
        /// Log API request to cs_apirequest table
        /// </summary>
        private void LogApiRequest(Guid envelopeId, string method, string endpoint, 
                                   string requestBody, string responseBody, int statusCode, 
                                   IOrganizationService service)
        {
            try
            {
                Entity apiRequest = new Entity("cs_apirequest");
                apiRequest["cs_name"] = $"{method} {endpoint} - {DateTime.UtcNow:yyyy-MM-dd HH:mm}";
                apiRequest["cs_envelopeid"] = envelopeId.ToString();
                apiRequest["cs_method"] = method;
                apiRequest["cs_endpoint"] = endpoint;
                apiRequest["cs_requestbody"] = requestBody;
                apiRequest["cs_responsebody"] = responseBody;
                apiRequest["cs_statuscode"] = statusCode;
                apiRequest["cs_requestdate"] = DateTime.UtcNow;
                apiRequest["cs_success"] = statusCode >= 200 && statusCode < 300;

                service.Create(apiRequest);
            }
            catch (Exception)
            {
                // Don't fail the operation if logging fails
            }
        }
    }
}
