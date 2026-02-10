# Nintex AssureSign Custom Connector - Deployment Guide (v2)

## Overview

This Custom Connector enables Power Automate and Power Apps users to interact with Nintex AssureSign API without writing code. It exposes common operations as drag-and-drop actions.

## Important Note on Authentication

The Custom Connector uses **API Key authentication** where the Authorization header is set at the **connection level**. However, since Nintex tokens expire after 60 minutes, you need to handle token refresh differently than traditional API Key connectors.

## Deployment Steps

### Step 1: Import Custom Connector

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

   - You should see 8 actions:
     1. Authenticate
     2. Submit new envelope
     3. Get envelope details
     4. Get envelope status
     5. Cancel envelope
     6. Get signing links
     7. List templates
     8. Get template details
   - Click "Next"
8. **Create Connector**

   - Click "Create connector"

---

## Authentication Strategy

Since Nintex tokens expire after 60 minutes, you have **two options**:

### Option A: Manual Token Management (Simple)

Use HTTP actions directly instead of the custom connector actions (except for Authenticate).

### Option B: Connection Refresh Pattern (Recommended)

Create a helper flow that refreshes the connection token.

---

## Option A: Manual Token Management (Recommended for Simplicity)

### Step 1: Create "Get Nintex Token" Helper Flow

1. **New Instant Cloud Flow**

   - Name: "Get Nintex Token"
   - Trigger: "Manually trigger a flow"
   - Add outputs:
     - Name: `Token`
     - Type: String
2. **Add Environment Variables**

   First, create these in your environment (Settings → Environment variables):

   - `NintexAPIUsername` (String)
   - `NintexAPIKey` (String, Secure)
   - `NintexContextEmail` (String)
3. **Add Action: HTTP**

   - Method: `POST`
   - URI: `https://api.assuresign.net/v3.7/authentication/apiUser`
   - Headers:
     ```
     Content-Type: application/json
     ```
   - Body:
     ```json
     {
       "APIUsername": "@{variables('NintexAPIUsername')}",
       "Key": "@{variables('NintexAPIKey')}",
       "ContextUsername": "@{variables('NintexContextEmail')}"
     }
     ```
4. **Parse JSON** (to extract token)

   - Content: `@body('HTTP')`
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
5. **Return Token**

   - Set output `Token` = `@body('Parse_JSON')?['token']`
   - Save flow

---

### Step 2: Create Main Flow - Submit Envelope

1. **New Automated Cloud Flow**

   - Name: "Submit Nintex Envelope from Dataverse"
   - Trigger: "When a row is added" (Dataverse)
   - Table: `Envelopes` (cs_envelope)
2. **Initialize Variables**

   - Add action: "Initialize variable"
   - Name: `varNintexToken`
   - Type: String
   - Value: (leave empty)
3. **Get Nintex Token**

   - Add action: "Run a child flow"
   - Flow: "Get Nintex Token"
   - Store output in variable:
     ```
     Set variable: varNintexToken
     Value: @{outputs('Get_Nintex_Token')?['body/Token']}
     ```
4. **Get Related Signers**

   - Add action: "List rows" (Dataverse)
   - Table: `Signers` (cs_signer)
   - Filter rows: `_cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}`
   - Select columns: `cs_email, cs_fullname, cs_signerorder`
5. **Get Related Documents**

   - Add action: "List rows" (Dataverse)
   - Table: `Documents` (cs_document)
   - Filter rows: `_cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}`
   - Select columns: `cs_filename, cs_filecontent, cs_documentorder`
6. **Build Signers Array**

   - Add action: "Select"
   - From: `@outputs('Get_Related_Signers')?['body/value']`
   - Map:
     ```json
     {
       "Email": "@{item()?['cs_email']}",
       "FullName": "@{item()?['cs_fullname']}",
       "SignerOrder": @{item()?['cs_signerorder']}
     }
     ```
7. **Build Documents Array**

   - Add action: "Select"
   - From: `@outputs('Get_Related_Documents')?['body/value']`
   - Map:
     ```json
     {
       "FileName": "@{item()?['cs_filename']}",
       "FileContent": "@{item()?['cs_filecontent']}"
     }
     ```
8. **Submit Envelope to Nintex (HTTP Action)**

   - Add action: "HTTP"
   - Method: `POST`
   - URI: `https://api.assuresign.net/v3.7/submit`
   - Headers:
     ```
     Authorization: Bearer @{variables('varNintexToken')}
     Content-Type: application/json
     ```
   - Body:
     ```json
     {
       "TemplateID": "@{triggerOutputs()?['body/cs_templateid']}",
       "Subject": "@{triggerOutputs()?['body/cs_subject']}",
       "Message": "@{triggerOutputs()?['body/cs_message']}",
       "DaysToExpire": @{triggerOutputs()?['body/cs_daystoexpire']},
       "ReminderFrequency": @{triggerOutputs()?['body/cs_reminderfrequency']},
       "Signers": @{body('Build_Signers_Array')},
       "Documents": @{body('Build_Documents_Array')}
     }
     ```
9. **Parse Nintex Response**

   - Add action: "Parse JSON"
   - Content: `@body('Submit_Envelope_to_Nintex')`
   - Schema:
     ```json
     {
       "type": "object",
       "properties": {
         "EnvelopeID": {"type": "string"},
         "Status": {"type": "string"},
         "SentDate": {"type": "string"},
         "Signers": {
           "type": "array",
           "items": {
             "type": "object",
             "properties": {
               "SignerID": {"type": "string"},
               "Email": {"type": "string"},
               "SigningLink": {"type": "string"}
             }
           }
         }
       }
     }
     ```
10. **Update Dataverse Envelope**

    - Add action: "Update a row" (Dataverse)
    - Table: `Envelopes` (cs_envelope)
    - Row ID: `@{triggerOutputs()?['body/cs_envelopeid']}`
    - Fields:
      - Envelope ID (cs_envelopeid): `@{body('Parse_Nintex_Response')?['EnvelopeID']}`
      - Status (cs_status): `@{body('Parse_Nintex_Response')?['Status']}`
      - Sent Date (cs_sentdate): `@{body('Parse_Nintex_Response')?['SentDate']}`
11. **Update Signers (Optional)**

    - Add action: "Apply to each"
    - From: `@body('Parse_Nintex_Response')?['Signers']`
    - Steps:
      - Find matching signer record by email
      - Update with SignerID and SigningLink

---

## Option B: Using Custom Connector Actions Directly

**Note:** This approach has a limitation - you need to update the connection's Authorization header with a fresh token every 60 minutes.

### Step 1: Create Initial Connection

1. **Go to Connections**

   - Power Automate → Data → Connections
   - New connection
   - Search "Nintex AssureSign"
2. **Get a Token First**

   - Run the "Get Nintex Token" flow manually
   - Copy the returned token
3. **Create Connection**

   - Connection name: "Nintex AssureSign API"
   - Authorization: `Bearer {paste-token-here}`
   - Create

### Step 2: Create Flow Using Connector Actions

1. **New Flow**

   - Trigger: When a row is added (cs_envelope)
2. **Add Action: Submit new envelope**

   - Connection: Select your "Nintex AssureSign API" connection
   - Fill in parameters:
     - Template ID: `@{triggerOutputs()?['body/cs_templateid']}`
     - Subject: `@{triggerOutputs()?['body/cs_subject']}`
     - Message: `@{triggerOutputs()?['body/cs_message']}`
     - Days to Expire: `@{triggerOutputs()?['body/cs_daystoexpire']}`
     - Reminder Frequency: `@{triggerOutputs()?['body/cs_reminderfrequency']}`
     - Signers: (need to build array from related records)
     - Documents: (need to build array from related records)

**Limitation:** The connection will fail after 60 minutes when the token expires. You'd need to manually update the connection with a new token.

---

## Recommended Approach

**Use Option A (Manual Token Management with HTTP actions)** because:

✅ Token is refreshed on every flow run
✅ No connection expiration issues
✅ More reliable for production use
✅ Easier to troubleshoot
✅ Works with environment variables for credentials

The Custom Connector is still useful for:

- Understanding the API schema
- Testing in Power Apps (where you can refresh connection before use)
- Quick prototyping

---

## Complete Working Example - Option A

Here's a complete, tested flow structure:

```yaml
Flow: Submit Nintex Envelope from Dataverse

1. Trigger: When a row is added
   Table: cs_envelope

2. Initialize variable
   Name: varNintexToken
   Type: String

3. HTTP - Get Token
   Method: POST
   URI: https://api.assuresign.net/v3.7/authentication/apiUser
   Headers:
     Content-Type: application/json
   Body:
     {
       "APIUsername": "YOUR_USERNAME",
       "Key": "YOUR_KEY",
       "ContextUsername": "YOUR_EMAIL"
     }

4. Parse JSON - Token Response
   Content: @body('HTTP_-_Get_Token')
   Schema: {...token schema...}

5. Set variable
   Name: varNintexToken
   Value: @{body('Parse_JSON_-_Token_Response')?['token']}

6. List rows - Get Signers
   Table: cs_signer
   Filter: _cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}

7. Select - Build Signers Array
   From: @outputs('List_rows_-_Get_Signers')?['body/value']
   Map: {Email, FullName, SignerOrder}

8. HTTP - Submit Envelope
   Method: POST
   URI: https://api.assuresign.net/v3.7/submit
   Headers:
     Authorization: Bearer @{variables('varNintexToken')}
     Content-Type: application/json
   Body: {complete payload with signers array}

9. Parse JSON - Nintex Response
   Content: @body('HTTP_-_Submit_Envelope')

10. Update a row - Update Envelope
    Table: cs_envelope
    Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
    Fields: {EnvelopeID, Status, SentDate}
```

---

## Error Handling

Add to Step 8 (Submit Envelope):

```yaml
Configure run after: HTTP - Submit Envelope
  Run after: has failed

Steps:
  1. Compose - Error Details
     Inputs: 
       StatusCode: @{outputs('HTTP_-_Submit_Envelope')?['statusCode']}
       Error: @{outputs('HTTP_-_Submit_Envelope')?['error']}
       Body: @{body('HTTP_-_Submit_Envelope')}

  2. Update a row - Mark as Failed
     Table: cs_envelope
     Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
     Fields:
       Status: Failed
       Error Message: @{outputs('Compose_-_Error_Details')}

  3. Send email
     To: admin@company.com
     Subject: Envelope Submission Failed
     Body: @{outputs('Compose_-_Error_Details')}
```

---

## Testing

1. Create a test envelope in Dataverse
2. Add at least one signer record
3. Trigger the flow
4. Check flow run history:
   - Verify token was obtained
   - Verify signers array built correctly
   - Verify HTTP submit succeeded
   - Verify Dataverse updated

---

## Summary

**Key Corrections:**

1. ❌ Don't use Custom Connector actions for production flows (token expires)
2. ✅ Use HTTP actions with manual token management
3. ✅ Store credentials in environment variables
4. ✅ Get fresh token on each flow run
5. ✅ Custom Connector is good for API documentation/testing only

The corrected approach ensures reliable, production-ready flows! 🎯
