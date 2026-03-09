using System;
using System.ServiceModel;
using Microsoft.Xrm.Sdk;
using NintexDataverseProxy.Services;
using NintexDataverseProxy.Mappers;
using Newtonsoft.Json.Linq;

namespace NintexDataverseProxy.Plugins
{
    /// <summary>
    /// Plugin for cs_envelope entity
    /// Proxies operations to Nintex AssureSign API
    /// </summary>
    public class EnvelopePlugin : IPlugin
    {
        private readonly string _secureConfig;
        private readonly string _unsecureConfig;

        public EnvelopePlugin(string unsecureConfig, string secureConfig)
        {
            _unsecureConfig = unsecureConfig;
            _secureConfig = secureConfig;
        }

        public void Execute(IServiceProvider serviceProvider)
        {
            // Obtain the execution context
            IPluginExecutionContext context = (IPluginExecutionContext)serviceProvider.GetService(typeof(IPluginExecutionContext));
            IOrganizationServiceFactory serviceFactory = (IOrganizationServiceFactory)serviceProvider.GetService(typeof(IOrganizationServiceFactory));
            IOrganizationService service = serviceFactory.CreateOrganizationService(context.UserId);
            ITracingService tracingService = (ITracingService)serviceProvider.GetService(typeof(ITracingService));

            try
            {
                // Get the target entity
                Entity targetEntity = null;
                
                if (context.InputParameters.Contains("Target") && context.InputParameters["Target"] is Entity)
                {
                    targetEntity = (Entity)context.InputParameters["Target"];
                }
                else
                {
                    return;
                }

                tracingService.Trace($"EnvelopePlugin: {context.MessageName} on {targetEntity.LogicalName}");

                // Get configuration from secure config (should contain Nintex API credentials)
                var config = ParseSecureConfig(_secureConfig);
                string nintexApiUrl = config["ApiUrl"];
                string apiUsername = config["ApiUsername"];
                string apiKey = config["ApiKey"];
                string contextUsername = config["ContextUsername"];

                // Create Nintex API client
                var nintexClient = new NintexApiClient(nintexApiUrl);
                
                // Authenticate
                var authTask = nintexClient.AuthenticateAsync(apiUsername, apiKey, contextUsername);
                authTask.Wait();
                
                if (!authTask.Result)
                {
                    throw new InvalidPluginExecutionException("Failed to authenticate with Nintex API");
                }

                // Handle different messages
                switch (context.MessageName.ToUpper())
                {
                    case "CREATE":
                        HandleCreate(targetEntity, nintexClient, service, tracingService);
                        break;
                        
                    case "UPDATE":
                        HandleUpdate(targetEntity, context, nintexClient, service, tracingService);
                        break;
                        
                    case "DELETE":
                        HandleDelete(context, nintexClient, service, tracingService);
                        break;
                }
            }
            catch (FaultException<OrganizationServiceFault> ex)
            {
                tracingService.Trace($"EnvelopePlugin Error: {ex.ToString()}");
                throw new InvalidPluginExecutionException($"An error occurred in EnvelopePlugin: {ex.Message}", ex);
            }
            catch (Exception ex)
            {
                tracingService.Trace($"EnvelopePlugin Error: {ex.ToString()}");
                throw new InvalidPluginExecutionException($"An error occurred in EnvelopePlugin: {ex.Message}", ex);
            }
        }

        private void HandleCreate(Entity envelope, NintexApiClient client, IOrganizationService service, ITracingService trace)
        {
            trace.Trace("HandleCreate: Starting envelope submission to Nintex");

            // Map Dataverse entity to Nintex payload
            var submitPayload = DataverseToNintexMapper.MapEnvelopeToSubmitPayload(envelope);
            
            // TODO: Retrieve related signers, documents, fields and add to payload
            // This would require additional queries to get related records
            
            // Store request body
            envelope["cs_requestbody"] = submitPayload.ToString();

            // Submit to Nintex
            var submitTask = client.SubmitEnvelopeAsync(submitPayload);
            submitTask.Wait();
            var response = submitTask.Result;

            trace.Trace($"Nintex response: {response.ToString()}");

            // Update envelope with Nintex response
            DataverseToNintexMapper.UpdateEnvelopeFromNintexResponse(envelope, response);
            
            trace.Trace("HandleCreate: Envelope submitted successfully");
        }

        private void HandleUpdate(Entity envelope, IPluginExecutionContext context, NintexApiClient client, IOrganizationService service, ITracingService trace)
        {
            trace.Trace("HandleUpdate: Processing envelope update");

            // Get the full envelope entity (post-image or retrieve)
            Entity fullEnvelope = envelope;
            
            if (context.PostEntityImages.Contains("PostImage"))
            {
                fullEnvelope = context.PostEntityImages["PostImage"];
            }

            // Check if this is a cancellation
            if (envelope.Contains("cs_iscancelled") && envelope.GetAttributeValue<bool>("cs_iscancelled"))
            {
                string envelopeId = fullEnvelope.GetAttributeValue<string>("cs_envelopeid");
                
                if (!string.IsNullOrEmpty(envelopeId))
                {
                    trace.Trace($"Cancelling envelope: {envelopeId}");
                    var cancelTask = client.CancelEnvelopeAsync(envelopeId);
                    cancelTask.Wait();
                    
                    if (cancelTask.Result)
                    {
                        envelope["cs_cancelleddate"] = DateTime.UtcNow;
                        trace.Trace("Envelope cancelled successfully");
                    }
                }
            }
        }

        private void HandleDelete(IPluginExecutionContext context, NintexApiClient client, IOrganizationService service, ITracingService trace)
        {
            trace.Trace("HandleDelete: Processing envelope deletion");

            // Get pre-image to access envelope ID
            if (context.PreEntityImages.Contains("PreImage"))
            {
                Entity preImage = context.PreEntityImages["PreImage"];
                string envelopeId = preImage.GetAttributeValue<string>("cs_envelopeid");

                if (!string.IsNullOrEmpty(envelopeId))
                {
                    trace.Trace($"Cancelling envelope before delete: {envelopeId}");
                    var cancelTask = client.CancelEnvelopeAsync(envelopeId);
                    cancelTask.Wait();
                    
                    trace.Trace("Envelope cancelled before deletion");
                }
            }
        }

        private JObject ParseSecureConfig(string secureConfig)
        {
            // Parse JSON config or use default format
            // Example secure config format:
            // {"ApiUrl":"https://api.assuresign.net/v3.7","ApiUsername":"user","ApiKey":"key","ContextUsername":"context@email.com"}
            
            if (string.IsNullOrEmpty(secureConfig))
            {
                throw new InvalidPluginExecutionException("Secure configuration is required for Nintex API credentials");
            }

            return JObject.Parse(secureConfig);
        }
    }
}
