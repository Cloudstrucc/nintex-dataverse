using System;
using System.ServiceModel;
using Microsoft.Xrm.Sdk;
using Microsoft.Xrm.Sdk.Query;
using NintexDataverseProxy.Services;
using NintexDataverseProxy.Mappers;
using Newtonsoft.Json.Linq;

namespace NintexDataverseProxy.Plugins
{
    /// <summary>
    /// Plugin to retrieve and update envelope status from Nintex
    /// Triggers on Retrieve or can be called via custom action
    /// </summary>
    public class EnvelopeStatusUpdatePlugin : IPlugin
    {
        private readonly string _secureConfig;

        public EnvelopeStatusUpdatePlugin(string unsecureConfig, string secureConfig)
        {
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
                // This plugin updates envelope status from Nintex
                // Register on Post-Operation of Retrieve or Create a custom action
                
                Entity targetEntity = null;
                
                if (context.MessageName.ToUpper() == "RETRIEVE" && context.OutputParameters.Contains("BusinessEntity"))
                {
                    targetEntity = (Entity)context.OutputParameters["BusinessEntity"];
                }
                else if (context.InputParameters.Contains("Target") && context.InputParameters["Target"] is EntityReference)
                {
                    // Custom action - retrieve the entity
                    EntityReference targetRef = (EntityReference)context.InputParameters["Target"];
                    targetEntity = service.Retrieve(targetRef.LogicalName, targetRef.Id, new ColumnSet(true));
                }
                else
                {
                    return;
                }

                if (targetEntity.LogicalName != "cs_envelope")
                {
                    return;
                }

                tracingService.Trace("EnvelopeStatusUpdatePlugin: Updating status from Nintex");

                string envelopeId = targetEntity.GetAttributeValue<string>("cs_envelopeid");
                
                if (string.IsNullOrEmpty(envelopeId))
                {
                    tracingService.Trace("No Nintex envelope ID found, skipping");
                    return;
                }

                // Get config
                var config = JObject.Parse(_secureConfig);
                string nintexApiUrl = config["ApiUrl"].ToString();
                string apiUsername = config["ApiUsername"].ToString();
                string apiKey = config["ApiKey"].ToString();
                string contextUsername = config["ContextUsername"].ToString();

                // Create client and authenticate
                var nintexClient = new NintexApiClient(nintexApiUrl);
                var authTask = nintexClient.AuthenticateAsync(apiUsername, apiKey, contextUsername);
                authTask.Wait();

                if (!authTask.Result)
                {
                    tracingService.Trace("Authentication failed");
                    return;
                }

                // Get status from Nintex
                var statusTask = nintexClient.GetEnvelopeStatusAsync(envelopeId);
                statusTask.Wait();
                var statusResponse = statusTask.Result;

                tracingService.Trace($"Nintex status: {statusResponse.ToString()}");

                // Update the entity in Dataverse
                Entity updateEntity = new Entity("cs_envelope", targetEntity.Id);
                
                if (statusResponse["Status"] != null)
                {
                    updateEntity["cs_status"] = statusResponse["Status"].ToString();
                }

                if (statusResponse["CompletedDate"] != null)
                {
                    updateEntity["cs_completeddate"] = statusResponse["CompletedDate"].ToObject<DateTime>();
                }

                service.Update(updateEntity);
                
                tracingService.Trace("Status updated successfully");
            }
            catch (Exception ex)
            {
                tracingService.Trace($"EnvelopeStatusUpdatePlugin Error: {ex.ToString()}");
                throw new InvalidPluginExecutionException($"Error updating envelope status: {ex.Message}", ex);
            }
        }
    }
}
