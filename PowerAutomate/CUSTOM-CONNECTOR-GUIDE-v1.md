# Nintex AssureSign Custom Connector - Deployment Guide

## Overview

This Custom Connector enables Power Automate and Power Apps users to interact with Nintex AssureSign API without writing code. It exposes common operations as drag-and-drop actions.

## What You Get

### Available Actions

| Action                        | Description                            | Use Case                   |
| ----------------------------- | -------------------------------------- | -------------------------- |
| **Authenticate**        | Get bearer token for API calls         | Initial authentication     |
| **Submit Envelope**     | Create and send envelope for signature | Send contracts, agreements |
| **Get Envelope**        | Retrieve complete envelope details     | Check envelope information |
| **Get Envelope Status** | Get current status                     | Monitor signing progress   |
| **Cancel Envelope**     | Cancel active envelope                 | Stop processing            |
| **Get Signing Links**   | Get URLs for signers                   | Send custom notifications  |
| **List Templates**      | Get all available templates            | Display template picker    |
| **Get Template**        | Get template details                   | Pre-fill template info     |

## Deployment Steps

### Prerequisites

- **Power Platform Environment** with maker access
- **Power Automate** license (included in most M365 licenses)
- **Nintex AssureSign Account** with API credentials
- **Environment Admin** or **System Administrator** role

### Step 1: Import Custom Connector

#### Option A: Using Power Automate Portal (Recommended)

1. **Navigate to Power Automate**

   ```
   https://make.powerautomate.com
   ```
2. **Select Your Environment**

   - Click environment selector (top right)
   - Choose target environment
3. **Go to Custom Connectors**

   - Left menu → Data → Custom connectors
   - Click "New custom connector" → "Import an OpenAPI file"
4. **Upload Swagger File**

   - Connector name: **Nintex AssureSign**
   - Upload: `NintexAssureSign-CustomConnector.swagger.json`
   - Click "Continue"
5. **Review General Tab**

   - Description: Auto-populated from swagger
   - Host: `api.assuresign.net`
   - Base URL: `/v3.7`
6. **Configure Security**

   - Authentication type: **API Key**
   - Parameter label: **Authorization**
   - Parameter name: `Authorization`
   - Parameter location: **Header**
   - Click "Next"
7. **Review Definition**

   - All actions should be listed
   - Review parameters and responses
   - Click "Next"
8. **Test (Optional - Skip for Now)**

   - Click "Create connector"
9. **Note the Connector**

   - Connector is now available in your environment
   - Anyone with appropriate permissions can use it

#### Option B: Using PowerShell

```powershell
# Install Power Platform CLI
dotnet tool install --global Microsoft.PowerApps.CLI.Tool

# Authenticate
pac auth create --environment https://yourenv.crm.dynamics.com

# Import connector
pac connector create --settings-file NintexAssureSign-CustomConnector.swagger.json
```

### Step 2: Create Connection

1. **In Power Automate**

   - Left menu → Data → Connections
   - Click "New connection"
   - Search for "Nintex AssureSign"
   - Click the custom connector
2. **Configure Connection**

   - Connection name: **Nintex AssureSign API**
   - Authorization: Leave blank initially (you'll get token via flow)
   - Click "Create"

### Step 3: Create Authentication Flow

Since Nintex uses bearer tokens that expire, create a helper flow to authenticate:

#### Create "Get Nintex Token" Flow

1. **New Instant Cloud Flow**

   - Name: "Get Nintex Token"
   - Trigger: "Manually trigger a flow"
   - Add outputs:
     - Name: `Token`
     - Type: String
2. **Add Action: Authenticate**

   - Search for "Nintex AssureSign"
   - Select "Authenticate"
   - Fill in:
     - API Username: `your-api-username`
     - API Key: `your-api-key`
     - Context Email: `your-email@company.com`
3. **Parse JSON** (to extract token)

   - Content: `body('Authenticate')`
   - Schema:
     ```json
     {
       "type": "object",
       "properties": {
         "token": {
           "type": "string"
         },
         "expires": {
           "type": "string"
         }
       }
     }
     ```
4. **Return Token**

   - Set output `Token` = `body('Parse_JSON')?['token']`
   - Save flow

### Step 4: Create Example Flow - Submit Envelope

1. **New Automated Cloud Flow**

   - Name: "Submit Nintex Envelope from Dataverse"
   - Trigger: "When a row is added" (Dataverse)
   - Table: `Envelopes` (cs_envelope)
2. **Get Nintex Token**

   - Add action: "Run a Child Flow"
   - Flow: "Get Nintex Token"
   - Store output: `@{outputs('Get_Nintex_Token')?['body/Token']}`
3. **Submit Envelope**

   - Add action: "Submit Envelope" (Nintex AssureSign)
   - Authorization: `Bearer @{outputs('Get_Nintex_Token')?['body/Token']}`
   - Map fields:
     - Subject: Envelope Subject field
     - Message: Envelope Message field
     - Template ID: Envelope Template ID field
     - Days to Expire: `30`
     - Reminder Frequency: `3`
4. **Add Signers** (from related records)

   - Add action: "List rows" (Dataverse)
   - Table: `Signers` (cs_signer)
   - Filter: `_cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}`
5. **Update Submit Envelope Action**

   - In Signers array, click "Switch to input entire array"
   - Use expression:
     ```javascript
     @body('List_rows')?['value']
     ```
6. **Parse Response**

   - Add action: "Parse JSON"
   - Content: `body('Submit_Envelope')`
   - Schema:
     ```json
     {
       "type": "object",
       "properties": {
         "EnvelopeID": {"type": "string"},
         "Status": {"type": "string"},
         "SentDate": {"type": "string"}
       }
     }
     ```
7. **Update Dataverse Record**

   - Add action: "Update a row" (Dataverse)
   - Table: `Envelopes`
   - Row ID: Trigger output ID
   - Map fields:
     - Envelope ID (cs_envelopeid): `body('Parse_JSON')?['EnvelopeID']`
     - Status (cs_status): `body('Parse_JSON')?['Status']`
     - Sent Date (cs_sentdate): `body('Parse_JSON')?['SentDate']`
8. **Save and Test**

## Example Flows

### Flow 1: Submit Envelope When Record Created

```
Trigger: When cs_envelope created
  ↓
Get Nintex Token
  ↓
Get Related Signers (cs_signer)
  ↓
Get Related Documents (cs_document)
  ↓
Submit Envelope to Nintex
  ↓
Update cs_envelope with Envelope ID
  ↓
Update cs_signer records with signer IDs
```

### Flow 2: Check Status and Update

```
Trigger: Recurrence (every 30 minutes)
  ↓
Get Nintex Token
  ↓
List Incomplete Envelopes (Dataverse)
  ↓
For Each Envelope:
  ↓
  Get Envelope Status (Nintex)
  ↓
  Update cs_envelope Status
  ↓
  If Status = "Completed":
    ↓
    Download Signed Documents
    ↓
    Save to SharePoint
```

### Flow 3: Send Custom Signing Email

```
Trigger: When cs_envelope status = "InProcess"
  ↓
Get Nintex Token
  ↓
Get Signing Links
  ↓
For Each Signer:
  ↓
  Send custom email with signing link
  ↓
  Include company branding
```

### Flow 4: Cancel Envelope

```
Trigger: When cs_envelope is cancelled = true
  ↓
Get Nintex Token
  ↓
Cancel Envelope (Nintex)
  ↓
Update cs_envelope cancelled date
  ↓
Send notification to requestor
```

## Power Apps Integration

### Use in Canvas App

1. **Add Data Source**

   - Add data → Connectors
   - Select "Nintex AssureSign"
2. **Submit Envelope from Form**

   ```javascript
   // On Submit button
   Set(varEnvelopeResponse,
       NintexAssureSign.SubmitEnvelope({
           Subject: txtSubject.Text,
           Message: txtMessage.Text,
           Signers: galSigners.AllItems
       })
   );

   // Display result
   Notify("Envelope ID: " & varEnvelopeResponse.EnvelopeID, NotificationType.Success)
   ```
3. **Check Status Button**

   ```javascript
   Set(varStatus,
       NintexAssureSign.GetEnvelopeStatus(txtEnvelopeID.Text)
   );

   lblStatus.Text = varStatus.Status
   ```

### Use in Model-Driven App

Custom connectors can trigger from:

- Business Process Flows
- Real-time workflows (if enabled)
- Power Automate flows triggered from ribbon buttons

## Authentication Best Practices

### Option 1: Flow-Level Authentication

Store credentials in Azure Key Vault:

```
Get Nintex Token Flow:
  ↓
Get Secret from Key Vault (API Username)
  ↓
Get Secret from Key Vault (API Key)
  ↓
Authenticate
  ↓
Store token in variable
```

### Option 2: Environment Variable

1. Create environment variables:

   - `NintexAPIUsername`
   - `NintexAPIKey`
   - `NintexContextEmail`
2. Reference in flows:

   ```javascript
   Environment Variable Value: NintexAPIUsername
   ```

### Option 3: Secure Connection (Recommended)

When creating connection, some orgs prefer admin-managed connections:

1. **Admin creates connection** with API credentials
2. **Shares connection** with makers
3. **Makers use connection** without seeing credentials

## Monitoring

### Flow Run History

- Power Automate → My flows → [Your flow]
- Click run history
- View inputs/outputs for each action
- Check for errors

### Connection Health

- Power Automate → Data → Connections
- View connection status
- Test connection periodically

### Error Handling

Add error handling to flows:

```
Configure run after: "Submit Envelope"
  ↓
Condition: If failed
  ↓
  Compose error message
  ↓
  Send email to admin
  ↓
  Log to SharePoint list
```

## Troubleshooting

### Issue: "Unauthorized" Error

**Cause:** Token expired or invalid credentials

**Solution:**

- Re-run "Get Nintex Token" flow
- Verify API credentials
- Check token is properly formatted: `Bearer {token}`

### Issue: "Bad Request" Error

**Cause:** Invalid payload format

**Solution:**

- Check required fields are provided
- Verify Signers array format
- Ensure Document content is base64 encoded

### Issue: Action Not Found

**Cause:** Connector not properly imported

**Solution:**

- Re-import swagger file
- Verify all actions appear in Definition tab
- Recreate connector if needed

### Issue: Connection Failed

**Cause:** Network or permissions issue

**Solution:**

- Check firewall allows api.assuresign.net
- Verify API credentials are active
- Test in Postman first

## Security Considerations

⚠️ **Important Security Notes:**

1. **Credential Management**

   - Never hardcode API credentials in flows
   - Use Azure Key Vault or environment variables
   - Limit connection sharing to necessary users
2. **Token Handling**

   - Tokens expire after 60 minutes
   - Don't store tokens in Dataverse
   - Refresh tokens as needed
3. **Data Protection**

   - Document content is transmitted as base64
   - Ensure HTTPS for all connections
   - Follow data residency requirements
4. **Access Control**

   - Limit custom connector to specific security groups
   - Review connection permissions regularly
   - Audit flow runs for compliance

## Performance Tips

1. **Token Caching**

   - Cache token in variable for flow duration
   - Don't authenticate for every action
2. **Batch Processing**

   - Use "Apply to each" for multiple envelopes
   - Add delay between submissions (rate limiting)
3. **Async Status Checks**

   - Use scheduled flows for status updates
   - Don't poll synchronously in user flows

## Next Steps

1. **Import connector** using provided swagger file
2. **Create authentication flow** for token management
3. **Build example flow** for envelope submission
4. **Test with sample data** before production use
5. **Share connector** with your team

## Support Resources

- **Nintex API Docs**: https://docs.nintex.com/assuresign/
- **Power Automate Docs**: https://docs.microsoft.com/power-automate/
- **Custom Connectors**: https://docs.microsoft.com/connectors/custom-connectors/
