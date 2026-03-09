# Nintex Dataverse Proxy Plugin Library

**Version:** 1.0.0  
**Target Framework:** .NET Framework 4.6.2  
**Author:** Leonardo Company Canada

## Overview

This C# plugin library transforms Microsoft Dataverse into a complete middleware/proxy layer for Nintex AssureSign API. When users interact with Dataverse tables via the OData API, Power Apps, or any other interface, the plugins automatically synchronize data with Nintex AssureSign.

## Key Features

✅ **Automatic API Proxying** - CRUD operations on Dataverse tables trigger corresponding Nintex API calls  
✅ **Bi-directional Sync** - Updates from Nintex reflected back in Dataverse  
✅ **Complete Envelope Submission** - Handles envelopes with related signers, documents, and fields  
✅ **Status Synchronization** - Real-time status updates from Nintex  
✅ **Comprehensive Logging** - All API requests logged to cs_apirequest table  
✅ **Secure Configuration** - API credentials stored securely in plugin configuration  

## Architecture

```
┌─────────────────┐
│   User/App      │
└────────┬────────┘
         │ CRUD Operations
         ▼
┌─────────────────────────────────┐
│   Dataverse Tables              │
│   - cs_envelope                 │
│   - cs_signer                   │
│   - cs_document                 │
│   - cs_field                    │
│   - etc.                        │
└────────┬────────────────────────┘
         │ Plugin Trigger
         ▼
┌─────────────────────────────────┐
│   Nintex Proxy Plugins          │
│   - EnvelopePlugin              │
│   - EnvelopeStatusUpdatePlugin  │
│   - etc.                        │
└────────┬────────────────────────┘
         │ HTTP API Calls
         ▼
┌─────────────────────────────────┐
│   Nintex AssureSign API         │
│   https://api.assuresign.net    │
└─────────────────────────────────┘
```

## Project Structure

```
NintexDataverseProxy/
├── Services/
│   └── NintexApiClient.cs           # HTTP client for Nintex API
├── Mappers/
│   └── DataverseToNintexMapper.cs   # Entity/payload transformations
├── Plugins/
│   ├── EnvelopePlugin.cs                    # Basic envelope CRUD
│   ├── EnvelopeCompleteSubmissionPlugin.cs  # Advanced submission with related entities
│   └── EnvelopeStatusUpdatePlugin.cs        # Status synchronization
├── NintexDataverseProxy.csproj      # Project file
└── DEPLOYMENT-GUIDE.md              # Complete deployment instructions
```

## Quick Start

### 1. Build the Project

```bash
# Create strong name key
sn -k NintexDataverseProxy.snk

# Build
dotnet build --configuration Release
```

### 2. Register the Plugin

Use the Plugin Registration Tool:
1. Connect to your Dataverse environment
2. Register `NintexDataverseProxy.dll`
3. Configure secure configuration with Nintex credentials:
   ```json
   {
     "ApiUrl": "https://api.assuresign.net/v3.7",
     "ApiUsername": "your-api-username",
     "ApiKey": "your-api-key",
     "ContextUsername": "context@email.com"
   }
   ```

### 3. Register Plugin Steps

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for complete step registration instructions.

### 4. Test

Create an envelope via Dataverse API:

```http
POST https://yourorg.crm.dynamics.com/api/data/v9.2/cs_envelopes
Content-Type: application/json

{
  "cs_name": "Test Contract",
  "cs_subject": "Please sign",
  "cs_message": "Thank you",
  "cs_templateid": "template-guid",
  "cs_daystoexpire": 30
}
```

The plugin will:
1. Intercept the Create operation
2. Call Nintex `/submit` API
3. Update the envelope with Nintex envelope ID
4. Store request/response bodies
5. Return to caller

## Plugin Classes

### NintexApiClient
- **Purpose**: HTTP client wrapper for Nintex AssureSign API
- **Features**:
  - Token-based authentication
  - Automatic token refresh
  - All major API endpoints covered
  - Async/await support

### DataverseToNintexMapper
- **Purpose**: Transform data between Dataverse and Nintex formats
- **Methods**:
  - `MapEnvelopeToSubmitPayload()` - Convert envelope entity to API payload
  - `MapSignerToNintexSigner()` - Convert signer entity to API format
  - `MapDocumentToNintexDocument()` - Convert document entity
  - `UpdateEnvelopeFromNintexResponse()` - Apply API response to entity

### EnvelopePlugin
- **Triggers**: Create, Update, Delete on cs_envelope
- **Functionality**:
  - **Create**: Submit envelope to Nintex
  - **Update**: Cancel envelope if marked cancelled
  - **Delete**: Cancel envelope before deletion

### EnvelopeCompleteSubmissionPlugin
- **Triggers**: Create on cs_envelope
- **Functionality**:
  - Retrieves related signers (cs_signer)
  - Retrieves related documents (cs_document)
  - Retrieves fields for each document (cs_field)
  - Builds complete submission payload
  - Submits to Nintex
  - Updates all related records with response data
  - Logs request to cs_apirequest

### EnvelopeStatusUpdatePlugin
- **Triggers**: Retrieve on cs_envelope (or custom action)
- **Functionality**:
  - Fetches current status from Nintex
  - Updates Dataverse record
  - Can run asynchronously in background

## Use Cases

### 1. Power App Integration
Users fill out a Power App form → Creates envelope in Dataverse → Plugin submits to Nintex

### 2. Power Automate Workflows
Flow creates envelope record → Plugin handles API call → Flow continues based on status

### 3. External API Calls
Third-party app calls Dataverse OData API → Plugin proxies to Nintex → Response returned

### 4. Bulk Operations
Import tool creates multiple envelope records → Plugins process each asynchronously

## Configuration

### Secure Configuration (Required)
```json
{
  "ApiUrl": "https://api.assuresign.net/v3.7",
  "ApiUsername": "your-api-username",
  "ApiKey": "your-api-key",
  "ContextUsername": "context@email.com"
}
```

### Unsecure Configuration (Optional)
```json
{
  "Environment": "Production",
  "EnableLogging": true,
  "RetryAttempts": 3
}
```

## Error Handling

The plugins include comprehensive error handling:

- **Authentication Failures**: Throws InvalidPluginExecutionException with clear message
- **API Errors**: Captured and logged to Plugin Trace Log
- **Network Issues**: Timeout handling and retry logic
- **Invalid Data**: Validation before API submission

View errors in:
- Settings → System → Plugin Trace Log
- cs_apirequest table (error messages in cs_errormessage)

## Extending the Library

### Add Support for New Entity

1. Create new plugin class:
```csharp
public class SignerPlugin : IPlugin
{
    // Implement IPlugin.Execute
}
```

2. Add mapper methods:
```csharp
public static void UpdateSignerFromNintex(Entity signer, JObject response)
{
    // Mapping logic
}
```

3. Register plugin steps for the entity

### Add New API Endpoints

Add methods to `NintexApiClient.cs`:
```csharp
public async Task<JObject> GetUserAccountsAsync(string username)
{
    var response = await _httpClient.GetAsync($"/users/{username}/accounts");
    var result = await response.Content.ReadAsStringAsync();
    return JObject.Parse(result);
}
```

## Dependencies

- **Microsoft.CrmSdk.CoreAssemblies** (9.0.2.46) - Dataverse SDK
- **Newtonsoft.Json** (13.0.3) - JSON serialization
- **System.Net.Http** (4.3.4) - HTTP client

## Security Considerations

⚠️ **Important Security Notes:**

1. **Never hardcode credentials** - Always use Secure Configuration
2. **Rotate API keys regularly** - Update plugin configuration periodically
3. **Use dedicated API user** - Don't use personal accounts
4. **Monitor API usage** - Review cs_apirequest table regularly
5. **Enable audit logging** - Track all plugin executions

## Performance

- **Token Caching**: Authentication tokens cached for 55 minutes
- **Async Operations**: Status updates run asynchronously
- **Batch Processing**: Multiple envelopes can be processed in parallel
- **Rate Limiting**: Consider Nintex API rate limits for bulk operations

## Troubleshooting

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for detailed troubleshooting steps.

Common issues:
- Authentication failures → Check credentials in secure config
- Timeout errors → Use asynchronous execution mode
- Missing assembly → IL Merge dependencies

## Support

For issues or questions:
- Internal: Contact CloudStrucc Inc. / Fred Pearson
- Nintex API: https://docs.nintex.com/assuresign/
- Dataverse Plugins: https://docs.microsoft.com/power-apps/developer/data-platform/plug-ins

## License

Proprietary - Leonardo Company Canada

---

**Built with ❤️ for Leonardo Company Canada**
