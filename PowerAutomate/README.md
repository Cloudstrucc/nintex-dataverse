# Nintex AssureSign - Power Automate Solution

## 📦 What's Included

This package provides a **complete no-code/low-code solution** for integrating Dataverse with Nintex AssureSign using Power Automate.

### Files in This Package

| File                                                    | Description                                                |
| ------------------------------------------------------- | ---------------------------------------------------------- |
| **NintexAssureSign-CustomConnector.swagger.json** | OpenAPI definition for Custom Connector                    |
| **CUSTOM-CONNECTOR-GUIDE.md**                     | Complete deployment guide with step-by-step instructions   |
| **EXAMPLE-FLOWS.md**                              | 4 ready-to-use flow templates with detailed steps          |
| **SOLUTION-COMPARISON.md**                        | Comparison between C# Plugin and Power Automate approaches |
| **README.md**                                     | This file                                                  |

## 🚀 Quick Start (15 Minutes)

### 1. Import Custom Connector (5 minutes)

```
1. Go to https://make.powerautomate.com
2. Select your environment
3. Data → Custom connectors
4. New custom connector → Import an OpenAPI file
5. Upload: NintexAssureSign-CustomConnector.swagger.json
6. Click through wizard (defaults are fine)
7. Create connector
```

### 2. Create Connection (2 minutes)

```
1. Data → Connections
2. New connection
3. Search "Nintex AssureSign"
4. Leave Authorization blank (token obtained via flows)
5. Create
```

### 3. Build First Flow (8 minutes)

Use the templates in `EXAMPLE-FLOWS.md`:

- **Flow 1**: Submit envelope when Dataverse record created
- **Flow 2**: Scheduled status synchronization
- **Flow 3**: Cancel envelope automation
- **Flow 4**: Custom signing link emails

## ✨ Key Features

### 8 Ready-to-Use Actions

| Action                        | What It Does                 |
| ----------------------------- | ---------------------------- |
| 🔐**Authenticate**      | Get API token                |
| 📤**Submit Envelope**   | Send documents for signature |
| 📊**Get Envelope**      | Retrieve envelope details    |
| ⚡**Get Status**        | Check current status         |
| ❌**Cancel Envelope**   | Stop processing              |
| 🔗**Get Signing Links** | Get signer URLs              |
| 📋**List Templates**    | View all templates           |
| 📄**Get Template**      | Get template details         |

### 4 Complete Flow Templates

All flows include:

- ✅ Error handling
- ✅ Logging to Dataverse
- ✅ Email notifications
- ✅ Proper token management

## 📋 Prerequisites

Before you start, ensure you have:

- ✅ **Power Automate license** (Premium for HTTP actions)
- ✅ **Dataverse environment** with Nintex tables
- ✅ **Nintex API credentials**:
  - API Username
  - API Key
  - Context Email
- ✅ **Environment Admin** or **Maker** role

## 🎯 Use Cases

### Perfect For:

✅ **Citizen Developers** - No coding required
✅ **Flexible Workflows** - Change logic without redeployment
✅ **Multi-System Integration** - Connect to 500+ services
✅ **Approval Processes** - Built-in approval actions
✅ **Custom Notifications** - Branded emails with your logo
✅ **Document Routing** - Auto-save to SharePoint

### Example Workflows:

1. **Contract Submission**

   ```
   Sales rep creates opportunity
   → Manager approves
   → Flow submits to Nintex
   → Customer signs
   → Flow updates CRM
   → Team notified in Teams
   ```
2. **Employee Onboarding**

   ```
   HR creates employee record
   → Flow sends offer letter
   → Candidate signs
   → Flow saves to SharePoint
   → Creates IT ticket
   → Sends welcome email
   ```
3. **Vendor Agreements**

   ```
   Procurement submits NDA
   → Legal reviews
   → Flow sends to vendor
   → Auto-reminder every 3 days
   → Flow archives signed copy
   ```

## 🔧 Configuration

### Environment Variables

Create these in your environment:

```
Name: NintexAPIUsername
Type: String
Value: your-api-username

Name: NintexAPIKey
Type: String (Secure)
Value: your-api-key

Name: NintexContextEmail
Type: String
Value: your-email@company.com
```

### Dataverse Tables Required

- `cs_envelope` - Envelopes
- `cs_signer` - Signers
- `cs_document` - Documents
- `cs_field` - Fields
- `cs_apirequest` - API logging

## 📚 Documentation

### Complete Guides

- **[CUSTOM-CONNECTOR-GUIDE.md](CUSTOM-CONNECTOR-GUIDE.md)**

  - Detailed deployment steps
  - Troubleshooting section
  - Security best practices
  - Performance optimization
- **[EXAMPLE-FLOWS.md](EXAMPLE-FLOWS.md)**

  - 4 complete flow templates
  - Step-by-step instructions
  - Copy-paste ready YAML
  - Error handling included
- **[SOLUTION-COMPARISON.md](SOLUTION-COMPARISON.md)**

  - C# Plugin vs Power Automate
  - When to use each
  - Cost comparison
  - Hybrid approach guide

## 💡 Pro Tips

### 1. Token Management

Create a reusable "Get Nintex Token" child flow:

```
Input: None
Output: Token (String)

Steps:
1. Get secret from Key Vault
2. Authenticate with Nintex
3. Parse response
4. Return token
```

Use in other flows:

```
Run child flow: Get Nintex Token
Store: varNintexToken
```

### 2. Error Handling

Add to all HTTP actions:

```
Configure run after: [Action]
  Run after: has failed
Steps:
  - Log error to Dataverse
  - Email admin
  - Update status to "Error"
```

### 3. Performance

- ✅ Cache tokens (valid 60 min)
- ✅ Use parallel branches where possible
- ✅ Batch Dataverse operations
- ✅ Schedule heavy flows off-peak

### 4. Testing

Test in this order:

1. Test connector with Postman first
2. Create "Test" flow with hardcoded values
3. Add Dataverse triggers
4. Enable error handling
5. Deploy to production

## 🆘 Troubleshooting

### Issue: "Unauthorized" Error

**Solution:**

```
1. Verify API credentials in environment variables
2. Check token format: Bearer {token}
3. Ensure token hasn't expired (60 min)
4. Test authentication endpoint separately
```

### Issue: "Bad Request" Error

**Solution:**

```
1. Check required fields are provided
2. Verify JSON structure
3. Ensure base64 encoding for documents
4. Test payload in Postman
```

### Issue: Flow Times Out

**Solution:**

```
1. Split into multiple flows
2. Use asynchronous patterns
3. Implement child flows
4. Add delays between bulk operations
```

## 📊 Monitoring

### View Flow Runs

```
1. Power Automate → My flows
2. Click your flow
3. 28-day run history
4. Click run for details
5. Inspect each action
```

### Set Up Alerts

Create monitoring flow:

```
Trigger: When a flow fails
↓
Get flow details
↓
Send Teams message
↓
Log to SharePoint
```

## 🔐 Security

### Best Practices

✅ **Use Key Vault** for credentials
✅ **Limit connector sharing** to specific users
✅ **Enable DLP policies** in environment
✅ **Audit flow runs** regularly
✅ **Rotate API keys** quarterly

### Compliance

- All data encrypted in transit (HTTPS)
- Flow runs logged for 28 days
- Meets SOC 2, ISO 27001 standards
- GDPR compliant (EU data residency)

## 🎓 Learning Resources

### Official Docs

- [Power Automate Connectors](https://docs.microsoft.com/connectors/)
- [Custom Connectors Guide](https://docs.microsoft.com/connectors/custom-connectors/)
- [Nintex API Documentation](https://docs.nintex.com/assuresign/)

### Training

- Microsoft Learn: Power Automate fundamentals
- Nintex University: AssureSign courses

## 📞 Support

### Internal Support

- **Platform Engineering Help Desk**:
- **Power Platform Admin**: Fred Pearson
- **Nintex Admin**: [Your Nintex Admin]

### External Support

- **Microsoft**: Power Platform support portal
- **Nintex**: support@nintex.com
- **Community**: Power Users Community

## 🎉 Next Steps

1. **Read** CUSTOM-CONNECTOR-GUIDE.md
2. **Import** custom connector
3. **Create** example flows from EXAMPLE-FLOWS.md
4. **Test** with sample data
5. **Deploy** to production
6. **Train** your team

## 📝 Version History

**v1.0.0** (2026-01-20)

- Initial release
- 8 connector actions
- 4 example flows
- Complete documentation

---

**Ready to build no-code workflows? Start with CUSTOM-CONNECTOR-GUIDE.md**
