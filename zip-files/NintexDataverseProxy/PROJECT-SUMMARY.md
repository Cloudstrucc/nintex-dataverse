# Nintex Dataverse Proxy Plugin - Complete Package

## 📦 Package Contents

This package contains everything you need to build and deploy a C# plugin library that enables Dataverse to proxy API calls to Nintex AssureSign.

### Core Files

| File | Description |
|------|-------------|
| **NintexApiClient.cs** | HTTP client wrapper for Nintex AssureSign API v3.7 |
| **DataverseToNintexMapper.cs** | Bi-directional mapping between Dataverse entities and Nintex payloads |
| **EnvelopePlugin.cs** | Basic plugin for envelope Create/Update/Delete operations |
| **EnvelopeCompleteSubmissionPlugin.cs** | Advanced plugin that handles complete envelope submission with related signers, documents, and fields |
| **EnvelopeStatusUpdatePlugin.cs** | Plugin for synchronizing envelope status from Nintex to Dataverse |
| **NintexDataverseProxy.csproj** | Visual Studio project file with all dependencies |

### Documentation

| File | Description |
|------|-------------|
| **README.md** | Main documentation with architecture overview and quick start |
| **DEPLOYMENT-GUIDE.md** | Step-by-step deployment instructions with troubleshooting |
| **Build.ps1** | PowerShell script to build the project |

## 🚀 Quick Start (5 Minutes)

### Prerequisites
- Visual Studio 2019+ with Dataverse SDK
- Plugin Registration Tool
- Nintex AssureSign API credentials
- Dataverse environment with Nintex tables deployed

### Steps

```powershell
# 1. Build the plugin
.\Build.ps1

# 2. Register in Plugin Registration Tool
# - Load NintexDataverseProxy.dll from bin/Release/net462/
# - Add secure configuration with your Nintex credentials

# 3. Register plugin steps
# - EnvelopePlugin: Create, Update, Delete on cs_envelope
# - EnvelopeCompleteSubmissionPlugin: Create on cs_envelope
# - EnvelopeStatusUpdatePlugin: Retrieve on cs_envelope

# 4. Test
# Create an envelope record in Dataverse
# Plugin automatically submits to Nintex
```

## 🎯 What This Does

### User Workflow

```
User creates envelope in Dataverse
         ↓
Plugin intercepts Create operation
         ↓
Plugin queries related signers/documents
         ↓
Plugin builds complete Nintex payload
         ↓
Plugin submits to Nintex API
         ↓
Nintex returns envelope ID
         ↓
Plugin updates Dataverse record
         ↓
User gets back envelope with Nintex ID
```

### Supported Operations

| Dataverse Operation | Nintex API Call | Description |
|---------------------|-----------------|-------------|
| Create cs_envelope | POST /submit | Submit new envelope with signers and documents |
| Update cs_envelope (cancel) | PUT /envelopes/{id}/cancel | Cancel active envelope |
| Delete cs_envelope | PUT /envelopes/{id}/cancel + Delete | Cancel then remove |
| Retrieve cs_envelope | GET /envelopes/{id}/status | Sync current status |

## 📋 Configuration Example

### Secure Configuration (JSON)

Store in Plugin Registration Tool:

```json
{
  "ApiUrl": "https://api.assuresign.net/v3.7",
  "ApiUsername": "leonardo_api",
  "ApiKey": "your-api-key-here",
  "ContextUsername": "fred.pearson@leonardo.com"
}
```

**Security Note:** Never commit this configuration to source control!

## 🔍 How It Works

### Example: Creating an Envelope

#### 1. User Action
```http
POST /api/data/v9.2/cs_envelopes
{
  "cs_name": "Employment Contract",
  "cs_subject": "Please sign your employment contract",
  "cs_templateid": "template-123",
  "cs_daystoexpire": 30
}
```

#### 2. Plugin Intercepts
```csharp
// EnvelopeCompleteSubmissionPlugin.Execute() called
// Retrieves related records:
// - cs_signer (2 signers found)
// - cs_document (1 document found)
// - cs_field (5 signature fields found)
```

#### 3. Builds Nintex Payload
```json
{
  "TemplateID": "template-123",
  "Subject": "Please sign your employment contract",
  "DaysToExpire": 30,
  "Signers": [
    {"Email": "employee@company.com", "SignerOrder": 1},
    {"Email": "hr@company.com", "SignerOrder": 2}
  ],
  "Documents": [
    {
      "FileName": "contract.pdf",
      "FileContent": "base64-encoded-content",
      "JotBlocks": [
        {"Type": "signature", "X": 0.5, "Y": 0.8, "PageNumber": 1}
      ]
    }
  ]
}
```

#### 4. Calls Nintex API
```
POST https://api.assuresign.net/v3.7/submit
Authorization: Bearer {token}
```

#### 5. Updates Dataverse
```csharp
envelope["cs_envelopeid"] = "ENV-12345";
envelope["cs_status"] = "InProcess";
envelope["cs_requestbody"] = requestPayload;
envelope["cs_responsebody"] = response;
service.Update(envelope);
```

## 📊 Benefits

### For Users
✅ Use familiar Dataverse APIs  
✅ No need to learn Nintex API  
✅ Works with Power Apps, Power Automate  
✅ Unified data model  

### For Developers
✅ Centralized integration logic  
✅ Automatic synchronization  
✅ Built-in error handling  
✅ Comprehensive logging  

### For Operations
✅ Secure credential management  
✅ Audit trail in Dataverse  
✅ Easy monitoring via Plugin Trace Log  
✅ No custom API endpoints needed  

## 🛠 Extending the Solution

### Add New Entity Support

Create a plugin for cs_signer:

```csharp
public class SignerPlugin : IPlugin
{
    public void Execute(IServiceProvider serviceProvider)
    {
        // Get context
        // On Update: Call PUT /envelopes/{id}/signers/{signerId}
        // Update signer email, name, phone
    }
}
```

### Add Webhook Handler

Create a custom API to receive Nintex webhooks:

```csharp
[CustomApi]
public void HandleNintexWebhook(JObject payload)
{
    // Parse webhook
    // Find envelope by envelopeId
    // Update status in Dataverse
}
```

## 📈 Performance Tips

1. **Use Asynchronous Mode** for status updates
2. **Batch Related Entities** to minimize queries
3. **Cache Templates** for repeated submissions
4. **Monitor API Limits** in cs_apirequest table

## ⚠️ Important Notes

### Security
- ✅ Store credentials in secure configuration only
- ✅ Use dedicated Nintex API user with minimal permissions
- ✅ Enable Plugin Trace Log for audit trail
- ❌ Never hardcode credentials in plugin code

### Testing
- ✅ Test in sandbox environment first
- ✅ Verify all related records created correctly
- ✅ Check Plugin Trace Logs for errors
- ✅ Review cs_apirequest table for API call history

### Production
- ✅ Register plugins in Database (not Disk or GAC)
- ✅ Use Sandbox isolation mode
- ✅ Configure appropriate execution order
- ✅ Set up monitoring and alerts

## 📚 Additional Resources

- [Nintex AssureSign API Documentation](https://docs.nintex.com/assuresign/)
- [Dataverse Plugin Development Guide](https://docs.microsoft.com/power-apps/developer/data-platform/plug-ins)
- [Plugin Registration Tool](https://docs.microsoft.com/power-apps/developer/data-platform/download-tools-nuget)

## 🤝 Support

For technical support:
- **Internal**: Fred Pearson / CloudStrucc Inc.
- **Nintex**: support@nintex.com
- **Microsoft**: Power Platform support

## 📝 Version History

**v1.0.0** (2026-01-20)
- Initial release
- Support for envelope Create/Update/Delete
- Complete submission with related entities
- Status synchronization
- Comprehensive logging

---

**Built for Leonardo Company Canada**  
**Developed by CloudStrucc Inc.**
