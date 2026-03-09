using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace NintexDataverseProxy.Services
{
    /// <summary>
    /// Client for Nintex AssureSign API v3.7
    /// </summary>
    public class NintexApiClient
    {
        private readonly HttpClient _httpClient;
        private readonly string _baseUrl;
        private string _authToken;
        private DateTime _tokenExpiry;

        public NintexApiClient(string baseUrl)
        {
            _httpClient = new HttpClient();
            _baseUrl = baseUrl.TrimEnd('/');
            _httpClient.BaseAddress = new Uri(_baseUrl);
        }

        /// <summary>
        /// Authenticate with Nintex API using API credentials
        /// </summary>
        public async Task<bool> AuthenticateAsync(string apiUsername, string apiKey, string contextUsername)
        {
            try
            {
                var authPayload = new
                {
                    APIUsername = apiUsername,
                    Key = apiKey,
                    ContextUsername = contextUsername
                };

                var content = new StringContent(
                    JsonConvert.SerializeObject(authPayload),
                    Encoding.UTF8,
                    "application/json"
                );

                var response = await _httpClient.PostAsync("/authentication/apiUser", content);
                
                if (response.IsSuccessStatusCode)
                {
                    var result = await response.Content.ReadAsStringAsync();
                    var tokenData = JObject.Parse(result);
                    
                    _authToken = tokenData["token"]?.ToString();
                    
                    // Token typically expires in 60 minutes
                    _tokenExpiry = DateTime.UtcNow.AddMinutes(55);
                    
                    // Set default auth header
                    _httpClient.DefaultRequestHeaders.Authorization = 
                        new AuthenticationHeaderValue("Bearer", _authToken);
                    
                    return true;
                }
                
                return false;
            }
            catch (Exception)
            {
                return false;
            }
        }

        /// <summary>
        /// Check if token needs refresh
        /// </summary>
        private bool TokenNeedsRefresh()
        {
            return string.IsNullOrEmpty(_authToken) || DateTime.UtcNow >= _tokenExpiry;
        }

        #region Envelope Operations

        /// <summary>
        /// Submit a new envelope to Nintex
        /// POST /submit
        /// </summary>
        public async Task<JObject> SubmitEnvelopeAsync(JObject envelopeData)
        {
            var content = new StringContent(
                envelopeData.ToString(),
                Encoding.UTF8,
                "application/json"
            );

            var response = await _httpClient.PostAsync("/submit", content);
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Get envelope by ID
        /// GET /envelopes/{envelopeID}
        /// </summary>
        public async Task<JObject> GetEnvelopeAsync(string envelopeId)
        {
            var response = await _httpClient.GetAsync($"/envelopes/{envelopeId}");
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Get envelope status
        /// GET /envelopes/{envelopeID}/status
        /// </summary>
        public async Task<JObject> GetEnvelopeStatusAsync(string envelopeId)
        {
            var response = await _httpClient.GetAsync($"/envelopes/{envelopeId}/status");
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Cancel an envelope
        /// PUT /envelopes/{envelopeID}/cancel
        /// </summary>
        public async Task<bool> CancelEnvelopeAsync(string envelopeId)
        {
            var response = await _httpClient.PutAsync($"/envelopes/{envelopeId}/cancel", null);
            return response.IsSuccessStatusCode;
        }

        /// <summary>
        /// Download completed envelope
        /// POST /envelopes/{envelopeID}/download
        /// </summary>
        public async Task<byte[]> DownloadEnvelopeAsync(string envelopeId, string documentType = "Combined")
        {
            var payload = new { DocumentType = documentType };
            var content = new StringContent(
                JsonConvert.SerializeObject(payload),
                Encoding.UTF8,
                "application/json"
            );

            var response = await _httpClient.PostAsync($"/envelopes/{envelopeId}/download", content);
            return await response.Content.ReadAsByteArrayAsync();
        }

        /// <summary>
        /// Get envelope history
        /// GET /envelopes/{envelopeID}/history
        /// </summary>
        public async Task<JArray> GetEnvelopeHistoryAsync(string envelopeId)
        {
            var response = await _httpClient.GetAsync($"/envelopes/{envelopeId}/history");
            var result = await response.Content.ReadAsStringAsync();
            
            return JArray.Parse(result);
        }

        /// <summary>
        /// Get signing links for envelope
        /// GET /envelope/{envelopeID}/signingLinks
        /// </summary>
        public async Task<JArray> GetSigningLinksAsync(string envelopeId)
        {
            var response = await _httpClient.GetAsync($"/envelope/{envelopeId}/signingLinks");
            var result = await response.Content.ReadAsStringAsync();
            
            return JArray.Parse(result);
        }

        #endregion

        #region Template Operations

        /// <summary>
        /// Get all templates
        /// GET /templates
        /// </summary>
        public async Task<JArray> GetTemplatesAsync()
        {
            var response = await _httpClient.GetAsync("/templates");
            var result = await response.Content.ReadAsStringAsync();
            
            return JArray.Parse(result);
        }

        /// <summary>
        /// Get template by ID
        /// GET /templates/{templateID}
        /// </summary>
        public async Task<JObject> GetTemplateAsync(string templateId)
        {
            var response = await _httpClient.GetAsync($"/templates/{templateId}");
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Create template
        /// POST /templates
        /// </summary>
        public async Task<JObject> CreateTemplateAsync(JObject templateData)
        {
            var content = new StringContent(
                templateData.ToString(),
                Encoding.UTF8,
                "application/json"
            );

            var response = await _httpClient.PostAsync("/templates", content);
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Update template
        /// PUT /templates/{templateID}
        /// </summary>
        public async Task<JObject> UpdateTemplateAsync(string templateId, JObject templateData)
        {
            var content = new StringContent(
                templateData.ToString(),
                Encoding.UTF8,
                "application/json"
            );

            var response = await _httpClient.PutAsync($"/templates/{templateId}", content);
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Delete template
        /// DELETE /templates/{templateID}
        /// </summary>
        public async Task<bool> DeleteTemplateAsync(string templateId)
        {
            var response = await _httpClient.DeleteAsync($"/templates/{templateId}");
            return response.IsSuccessStatusCode;
        }

        #endregion

        #region Prepared Envelope Operations

        /// <summary>
        /// Create prepared envelope
        /// POST /submit/prepare
        /// </summary>
        public async Task<JObject> CreatePreparedEnvelopeAsync(JObject envelopeData)
        {
            var content = new StringContent(
                envelopeData.ToString(),
                Encoding.UTF8,
                "application/json"
            );

            var response = await _httpClient.PostAsync("/submit/prepare", content);
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Submit prepared envelope
        /// POST /submit/{preparedEnvelopeID}
        /// </summary>
        public async Task<JObject> SubmitPreparedEnvelopeAsync(string preparedEnvelopeId)
        {
            var response = await _httpClient.PostAsync($"/submit/{preparedEnvelopeId}", null);
            var result = await response.Content.ReadAsStringAsync();
            
            return JObject.Parse(result);
        }

        /// <summary>
        /// Delete prepared envelope
        /// DELETE /submit/prepare/{preparedEnvelopeID}
        /// </summary>
        public async Task<bool> DeletePreparedEnvelopeAsync(string preparedEnvelopeId)
        {
            var response = await _httpClient.DeleteAsync($"/submit/prepare/{preparedEnvelopeId}");
            return response.IsSuccessStatusCode;
        }

        #endregion

        public void Dispose()
        {
            _httpClient?.Dispose();
        }
    }
}
