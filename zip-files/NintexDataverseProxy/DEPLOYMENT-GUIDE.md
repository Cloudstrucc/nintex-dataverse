# Nintex Dataverse Proxy Plugin - Deployment Guide

## Overview

This plugin library enables Dataverse to act as a middleware/proxy for the Nintex AssureSign API. When users create, update, or delete records in Dataverse, the plugin automatically makes corresponding API calls to Nintex.

## Architecture

```
User/App → Dataverse API → Plugin → Nintex AssureSign API
                ↓                           ↓
           Dataverse Tables          Nintex Backend
```

## Components

### 1. **NintexApiClient.cs**
HTTP client for Nintex AssureSign API v3.7
- Handles authentication
- Provides methods for all major API operations
- Manages token lifecycle

### 2. **DataverseToNintexMapper.cs**
Bi-directional mapper between Dataverse entities and Nintex API payloads
- Maps Dataverse → Nintex (for submissions)
- Maps Nintex → Dataverse (for responses)

### 3. **EnvelopePlugin.cs**
Main plugin for cs_envelope entity
- **Create**: Submits new envelope to Nintex
- **Update**: Cancels envelope if marked as cancelled
- **Delete**: Cancels envelope before deletion

### 4. **EnvelopeStatusUpdatePlugin.cs**
Status synchronization plugin
- Retrieves current status from Nintex
- Updates Dataverse record

## Prerequisites

1. **Development Environment**
   - Visual Studio 2019 or later
   - .NET Framework 4.6.2 or later
   - Plugin Registration Tool

2. **Nintex AssureSign Account**
   - API Username
   - API Key
   - Context Username (email)
   - API Base URL (e.g., https://api.assuresign.net/v3.7)

3. **Dataverse Environment**
   - System Administrator access
   - All Nintex tables deployed (cs_envelope, cs_signer, etc.)

## Building the Plugin

### Step 1: Create Strong Name Key

```bash
# In Visual Studio Developer Command Prompt
cd <project-directory>
sn -k NintexDataverseProxy.snk
```

### Step 2: Build the Project

```bash
dotnet build NintexDataverseProxy.csproj --configuration Release
```

Or in Visual Studio:
- Build → Build Solution
- Output: `bin/Release/net462/NintexDataverseProxy.dll`

### Step 3: Sign the Assembly

The assembly is already configured to use the SNK file. Verify:
- Solution Explorer → Properties → Signing
- "Sign the assembly" should be checked
- Strong name key file: NintexDataverseProxy.snk

## Registering the Plugin

### Using Plugin Registration Tool

1. **Connect to your Dataverse environment**

2. **Register New Assembly**
   - Click "Register" → "Register New Assembly"
   - Browse to `NintexDataverseProxy.dll`
   - Isolation Mode: Sandbox
   - Location: Database
   - Click "Register Selected Plugins"

3. **Configure Secure Configuration**

   Create a JSON configuration string with your Nintex credentials:
   ```json
   {
     "ApiUrl": "https://api.assuresign.net/v3.7",
     "ApiUsername": "your-api-username",
     "ApiKey": "your-api-key",
     "ContextUsername": "context@yourdomain.com"
   }
   ```

4. **Register Plugin Steps**

   #### For EnvelopePlugin:

   **Create Step:**
   - Message: Create
   - Primary Entity: cs_envelope
   - Event Pipeline Stage: PostOperation
   - Execution Mode: Synchronous
   - Secure Configuration: [Your JSON config from step 3]
   - Execution Order: 1

   **Update Step:**
   - Message: Update
   - Primary Entity: cs_envelope
   - Event Pipeline Stage: PostOperation
   - Execution Mode: Synchronous
   - Secure Configuration: [Your JSON config]
   - Post-Image: Required (Name: "PostImage", Attributes: All)
   - Filtering Attributes: cs_iscancelled

   **Delete Step:**
   - Message: Delete
   - Primary Entity: cs_envelope
   - Event Pipeline Stage: PreOperation
   - Execution Mode: Synchronous
   - Secure Configuration: [Your JSON config]
   - Pre-Image: Required (Name: "PreImage", Attributes: cs_envelopeid)

   #### For EnvelopeStatusUpdatePlugin:

   **Retrieve Step (Optional - for automatic sync):**
   - Message: Retrieve
   - Primary Entity: cs_envelope
   - Event Pipeline Stage: PostOperation
   - Execution Mode: Asynchronous
   - Secure Configuration: [Your JSON config]

## Testing the Plugin

### Test 1: Create Envelope

```javascript
// Using Web API
POST https://yourorg.crm.dynamics.com/api/data/v9.2/cs_envelopes
{
  "cs_name": "Test Contract",
  "cs_subject": "Please sign this document",
  "cs_message": "Thank you for your prompt attention",
  "cs_templateid": "your-template-id",
  "cs_daystoexpire": 30,
  "cs_reminderfrequency": 3
}
```

**Expected Result:**
- Envelope created in Dataverse
- API call made to Nintex `/submit` endpoint
- `cs_envelopeid` populated with Nintex envelope ID
- `cs_status` set to returned status
- `cs_requestbody` and `cs_responsebody` populated

### Test 2: Cancel Envelope

```javascript
// Update the envelope
PATCH https://yourorg.crm.dynamics.com/api/data/v9.2/cs_envelopes(guid)
{
  "cs_iscancelled": true
}
```

**Expected Result:**
- Envelope updated in Dataverse
- Nintex API `/envelopes/{id}/cancel` called
- `cs_cancelleddate` populated

### Test 3: Delete Envelope

```javascript
DELETE https://yourorg.crm.dynamics.com/api/data/v9.2/cs_envelopes(guid)
```

**Expected Result:**
- Envelope deleted from Dataverse
- Nintex envelope cancelled first
- Deletion proceeds

## Monitoring and Debugging

### Enable Tracing

1. **Plugin Trace Log**
   - Settings → System → Plugin Trace Log
   - Enable for "All" or "Exception"

2. **View Traces**
   ```
   Settings → Customizations → Plugin Trace Logs
   ```

3. **Common Trace Messages**
   - "EnvelopePlugin: CREATE on cs_envelope" - Plugin triggered
   - "Nintex response: {json}" - API response received
   - "HandleCreate: Envelope submitted successfully" - Success

### Common Issues

#### 1. Authentication Failed
**Error:** "Failed to authenticate with Nintex API"

**Solution:**
- Verify API credentials in secure configuration
- Check API URL is correct
- Ensure Context Username has access to Nintex account

#### 2. Assembly Load Error
**Error:** "Could not load file or assembly"

**Solution:**
- Ensure all dependencies are present (Newtonsoft.Json, System.Net.Http)
- IL Merge dependencies into single DLL if needed

#### 3. Timeout Errors
**Error:** Task timeout or network errors

**Solution:**
- Use Asynchronous execution mode for long-running operations
- Implement retry logic
- Consider using Azure Service Bus for complex workflows

## Advanced Configuration

### Multi-Environment Setup

Use unsecure configuration for environment-specific settings:

**Secure Config (Credentials):**
```json
{
  "ApiKey": "secret-key",
  "ApiUsername": "api-user"
}
```

**Unsecure Config (Environment):**
```json
{
  "ApiUrl": "https://sandbox.assuresign.net/v3.7",
  "ContextUsername": "dev@company.com"
}
```

### Extending for Other Entities

To add plugin support for other tables (cs_signer, cs_document, etc.):

1. Create new plugin class inheriting from IPlugin
2. Implement entity-specific logic
3. Register steps for that entity
4. Add mapping methods to DataverseToNintexMapper

## Performance Considerations

1. **Synchronous vs Asynchronous**
   - Create/Update: Synchronous (user needs immediate feedback)
   - Status updates: Asynchronous (can happen in background)
   - Bulk operations: Use asynchronous

2. **Caching**
   - Cache authentication tokens (implemented in NintexApiClient)
   - Consider caching template data

3. **Rate Limiting**
   - Nintex API may have rate limits
   - Implement throttling if needed
   - Use async patterns for bulk operations

## Security Best Practices

1. **Never store credentials in code**
   - Always use Secure Configuration
   - Rotate API keys regularly

2. **Least Privilege**
   - Create dedicated Nintex API user
   - Grant minimum required permissions

3. **Audit Logging**
   - Enable Plugin Trace Log
   - Monitor API Request table (cs_apirequest)
   - Set up alerts for failures

## Next Steps

1. **Implement Related Entity Handling**
   - When creating envelope, query and include related signers
   - Query and include related documents
   - Submit complete payload to Nintex

2. **Webhook Handler**
   - Create custom API endpoint to receive Nintex webhooks
   - Update Dataverse when events occur in Nintex

3. **Error Handling**
   - Implement retry logic with exponential backoff
   - Create error logging table
   - Send notifications on failures

4. **Batch Operations**
   - Support bulk envelope creation
   - Implement queue-based processing

## Support and Resources

- **Nintex API Documentation**: https://docs.nintex.com/assuresign/
- **Dataverse Plugin Development**: https://docs.microsoft.com/power-apps/developer/data-platform/plug-ins
- **Sample Code**: See EnvelopePlugin.cs for complete example

## License

Proprietary - Leonardo Company Canada
