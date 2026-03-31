# ESign Elections Canada - Client Agency Integration Guide

## Overview

**ESign Elections Canada** is a managed digital signature service provided by Elections Canada. This service acts as a **broker** between your Dataverse environment and Nintex AssureSign, handling all the complexity of digital signature workflows including approval processes, audit logging, and API integration.

### What This Means for You

Instead of:

- ❌ Managing Nintex API credentials
- ❌ Building complex integration flows
- ❌ Handling token refresh and error retry logic
- ❌ Setting up approval workflows
- ❌ Managing audit trails

You simply:

- ✅ Use our custom connector in your Power Automate flows
- ✅ Submit envelopes with a simple action
- ✅ Automatic approval routing (if configured)
- ✅ Real-time status updates
- ✅ Complete audit trail maintained by broker service

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│          YOUR AGENCY ENVIRONMENT                        │
│                                                          │
│  ┌────────────────────────────────────────────────┐    │
│  │  Your Power Automate Flows / Power Apps       │    │
│  └─────────────────┬──────────────────────────────┘    │
│                    │                                     │
│  ┌─────────────────▼──────────────────────────────┐    │
│  │  ESign Elections Canada Custom Connector       │    │
│  │  (Simple actions for envelope management)      │    │
│  └─────────────────┬──────────────────────────────┘    │
└────────────────────┼─────────────────────────────────┬──┘
                     │ HTTPS/OAuth 2.0                 │
                     │                                  │
┌────────────────────▼──────────────────────────────────▼──┐
│      Elections BROKER SERVICE (Dataverse)                 │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Nintex Signature Tables                          │ │
│  │  • cs_envelope (your requests)                    │ │
│  │  • cs_signer (your signers)                       │ │
│  │  • cs_document (your documents)                   │ │
│  │  • cs_template (available templates)              │ │
│  └────────────────────────────────────────────────────┘ │
│                                                           │
│  ┌────────────────────────────────────────────────────┐ │
│  │  Broker Power Automate Flows                      │ │
│  │  • Approval workflows                             │ │
│  │  • Nintex API integration                         │ │
│  │  • Status synchronization                         │ │
│  │  • Notification routing                           │ │
│  └────────────────┬───────────────────────────────────┘ │
└────────────────────┼───────────────────────────────────┬─┘
                     │                                    │
                     │ Nintex API                         │
                     ▼                                    │
            ┌─────────────────────┐                      │
            │  Nintex AssureSign  │                      │
            │  (Digital Signature │                      │
            │   Platform)         │                      │
            └─────────────────────┘                      │
                                                          │
            Notifications, Status Updates ◄───────────────┘
```

## Benefits of Using the Broker Service

### For Your Project

✅ **No Nintex Expertise Required** - We handle all API integration
✅ **Simplified Integration** - 3 simple actions vs 20+ API calls
✅ **Built-in Approval Workflows** - Optional approval routing
✅ **Automatic Status Sync** - Real-time updates from Nintex
✅ **Comprehensive Audit Trail** - All actions logged
✅ **Centralized Template Management** - Shared template library
✅ **Cost Effective** - Shared Nintex licensing
✅ **Support Included** - Elections provides technical support

### For Your Users

✅ **Faster Time to Signature** - Streamlined submission process
✅ **Consistent Experience** - Same workflow across agencies
✅ **Mobile Friendly** - Sign from any device
✅ **Secure & Compliant**certified

## Prerequisites

Before you begin, ensure you have:

1. **Dataverse Environment**
2. **Power Automate License** (included in most M365 licenses)
3. **Service Principal Access** provided by Elections' Platfrom Engineering Team:

   - Application (Client) ID
   - Client Secret
   - Tenant ID
   - Broker Environment URL

## Deployment Steps

### Step 1: Obtain Service Principal Credentials

Contact Elections Canada IT to request access:

**Email:** esign-support@Elections.com
**Subject:** ESign Service Principal Request

**Include:**

- Your agency name
- Dataverse environment URL
- Primary contact name and email
- Expected monthly envelope volume

You will receive:

```json
{
  "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "ClientSecret": "your-secret-here",
  "BrokerEnvironmentUrl": "https://lce-broker.crm3.dynamics.com"
}
```

⚠️ **Keep these credentials secure!** Store in Azure Key Vault or as environment variables.

---

### Step 2: Import Custom Connector

#### Using Power Automate Portal

1. **Navigate to Power Automate**

   ```
   https://make.powerautomate.com
   ```
2. **Select Your Environment**

   - Top right → Environment selector
   - Choose your agency's environment
3. **Import Custom Connector**

   - Left menu → Data → Custom connectors
   - **New custom connector** → **Import an OpenAPI file**
4. **Upload Connector Definition**

   - Connector name: **ESign Elections Canada**
   - Upload file: `ESignElectionsCanada-CustomConnector.swagger.json`
   - Click **Continue**
5. **Review General Settings**

   - Host: `lce-broker.crm3.dynamics.com` (or your provided URL)
   - Base URL: `/api/data/v9.2`
   - Click **Security** →
6. **Configure OAuth 2.0**

   - Authentication type: **OAuth 2.0**
   - Identity Provider: **Azure Active Directory**
   - Client ID: [Paste your Client ID]
   - Client Secret: [Paste your Client Secret]
   - Resource URL: `https://lce-broker.crm3.dynamics.com`
   - Click **Definition** →
7. **Review Actions**

   You should see these actions:

   - ✅ Submit envelope for signature
   - ✅ List envelopes
   - ✅ Get envelope details
   - ✅ Update envelope
   - ✅ Delete envelope
   - ✅ Add signer to envelope
   - ✅ Add document to envelope
   - ✅ Get envelope signers
   - ✅ List available templates

   Click **Create connector**
8. **Success!**

   - Connector is now available in your environment
   - Anyone with appropriate permissions can use it

---

### Step 3: Create a Connection

1. **Go to Connections**

   - Power Automate → Data → Connections
   - Click **New connection**
2. **Find ESign Connector**

   - Search: "ESign Elections Canada"
   - Click the custom connector
3. **Authenticate**

   - Sign in with your credentials
   - Grant consent to access broker service
   - Connection created!

---

### Step 4: Test with Sample Flow

Let's create a simple flow to test the connector:

#### Create "Submit Test Envelope" Flow

1. **New Instant Cloud Flow**

   - Name: "Submit Test Envelope"
   - Trigger: "Manually trigger a flow"
2. **Add Inputs**

   - Subject (Text): "Document subject"
   - SignerEmail (Email): "Signer email address"
   - SignerName (Text): "Signer full name"
3. **Add Action: Submit envelope for signature**

   - Connection: ESign Elections Canada
   - Fill in fields:
     - Envelope Name: `Test Envelope - @{utcNow()}`
     - Subject: `@{triggerBody()?['text']}`
     - Message: "Please sign this document at your earliest convenience"
     - Requestor Email: `@{triggerBody()?['email']}`
     - Department: "Your Department Name"
     - Days to Expire: `30`
     - Reminder Frequency: `3`
     - Requires Approval: `false`
4. **Add Action: Add signer to envelope**

   - Connection: ESign Elections Canada
   - Email: `@{triggerBody()?['email_1']}`
   - Full Name: `@{triggerBody()?['text_1']}`
   - Signing Order: `1`
   - Envelope: `/cs_envelopes(@{outputs('Submit_envelope_for_signature')?['body/cs_envelopeid']})`
5. **Save and Test**

   - Click **Test** → **Manually**
   - Enter test data
   - Click **Run flow**
   - Check results!

---

## Common Integration Patterns

### Pattern 1: Contract Submission from Power App

**Scenario:** Sales team submits contracts via Power App

```yaml
Power App Form (Contract Details)
  ↓
Button Click → Run Flow
  ↓
Flow: Submit Contract for Signature
  ↓
1. Submit envelope (ESign connector)
2. Add customer as signer
3. Add sales rep as signer  
4. Attach contract PDF
5. Send confirmation email to sales rep
  ↓
Broker Service:
  - Routes for approval (if required)
  - Submits to Nintex
  - Tracks status
  ↓
Sales rep receives signing link
Customer receives signing link
  ↓
Flow monitors status
  ↓
On completion:
  - Update CRM opportunity
  - Save signed doc to SharePoint
  - Notify team in Teams
```

#### Sample Flow

```yaml
Trigger: PowerApps button

1. Submit envelope for signature
   Envelope Name: Contract - @{triggerBody()?['CustomerName']}
   Subject: Please sign your contract
   Message: Thank you for your business...
   Requestor Email: @{triggerBody()?['SalesRepEmail']}
   Department: Sales
   Requires Approval: true

2. Add signer to envelope (Customer)
   Email: @{triggerBody()?['CustomerEmail']}
   Full Name: @{triggerBody()?['CustomerName']}
   Signing Order: 1
   Envelope: /cs_envelopes(@{outputs('Submit_envelope')?['body/cs_envelopeid']})

3. Add signer to envelope (Sales Rep)
   Email: @{triggerBody()?['SalesRepEmail']}
   Full Name: @{triggerBody()?['SalesRepName']}
   Signing Order: 2
   Envelope: /cs_envelopes(@{outputs('Submit_envelope')?['body/cs_envelopeid']})

4. Get file content (SharePoint)
   Site: Your SharePoint site
   File: Contract template

5. Compose - Convert to Base64
   Inputs: @{base64(outputs('Get_file_content')?['body'])}

6. Add document to envelope
   Filename: Contract.pdf
   File Content: @{outputs('Compose_-_Convert_to_Base64')}
   Document Order: 1
   Envelope: /cs_envelopes(@{outputs('Submit_envelope')?['body/cs_envelopeid']})

7. Send email
   To: @{triggerBody()?['SalesRepEmail']}
   Subject: Contract submitted for signature
   Body: Your contract has been submitted...
```

---

### Pattern 2: HR Document Signing Workflow

**Scenario:** Employee onboarding documents

```yaml
Trigger: When employee record created in Dataverse
  ↓
Get employee details
  ↓
Submit envelope for signature
  - Envelope: Employee Onboarding - [Name]
  - Requires Approval: false (auto-send)
  ↓
Add employee as signer (order 1)
Add HR manager as signer (order 2)
  ↓
Add documents:
  - Offer Letter
  - Benefits Enrollment
  - Code of Conduct
  ↓
Broker service submits to Nintex
  ↓
Employee receives signing links
  ↓
Monitor status with scheduled flow:
  - Check every 4 hours
  - If completed: Update employee record
  - If expired: Notify HR
```

---

### Pattern 3: Bulk Document Submission

**Scenario:** Send NDA to 50 vendors

```yaml
Trigger: Recurrence (once) or Manual

1. Get items from Excel/SharePoint
   - Vendor Name
   - Vendor Email
   - Contact Person

2. Apply to each vendor
   
   a. Submit envelope for signature
      Envelope Name: NDA - @{item()?['VendorName']}
      Subject: NDA Signature Request
      Requestor Email: procurement@agency.gov
      Department: Procurement
      Requires Approval: false
   
   b. Add signer
      Email: @{item()?['VendorEmail']}
      Full Name: @{item()?['ContactPerson']}
      Signing Order: 1
   
   c. Add document (NDA template)
      From SharePoint or template
   
   d. Delay
      Wait 2 seconds (rate limiting)
   
   e. Log to SharePoint
      Vendor, Envelope ID, Submission Time

3. Send summary email
   Total submitted: @{length(outputs('Apply_to_each'))}
```

---

### Pattern 4: Approval-Based Envelope Submission

**Scenario:** High-value contracts require director approval before sending

```yaml
Trigger: When contract value > $100,000

1. Submit envelope for signature
   Envelope Name: High-Value Contract - @{triggerBody()?['ContractName']}
   Requires Approval: true  ← THIS TRIGGERS BROKER APPROVAL WORKFLOW
   Requestor Email: @{triggerBody()?['SubmitterEmail']}
   Department: @{triggerBody()?['Department']}

2. Add signers
   [Customer signers...]

3. Add documents
   [Contract PDF...]

4. Send notification to submitter
   Subject: Contract submitted for approval
   Body: Your contract requires director approval before sending to customer.
         You will be notified once approved.

--- Meanwhile in Broker Service ---

Broker Flow (automatic):
  ↓
Envelope created with status "Pending Approval"
  ↓
Approval request sent to director
  ↓
If Approved:
  - Submit to Nintex
  - Update status to "Submitted"
  - Notify requestor
  ↓
If Rejected:
  - Update status to "Rejected"
  - Notify requestor with reason

--- Back in Your Environment ---

5. Monitor envelope status (scheduled flow)
   Every 30 minutes:
   - Get envelope details
   - If status changed to "Submitted":
     → Update CRM
     → Notify team
   - If status changed to "Rejected":
     → Notify submitter
     → Log reason
```

---

## Available Actions Reference

### 1. Submit envelope for signature

**Use:** Create a new envelope in broker service

**Parameters:**

- `cs_name` (required): Envelope name/title
- `cs_subject` (required): Email subject for signers
- `cs_message`: Email message body
- `cs_requestoremail` (required): Your email
- `cs_departmentname`: Your department
- `cs_templateid`: Nintex template ID (optional)
- `cs_daystoexpire`: Days until expires (default: 30)
- `cs_reminderfrequency`: Days between reminders (default: 3)
- `cs_requiresapproval`: Trigger approval workflow (default: false)

**Returns:**

- `cs_envelopeid`: Envelope GUID (use for related records)
- `cs_status`: Current status
- `cs_nintexenvelopeid`: Nintex ID (populated after submission)

**Example:**

```javascript
Submit envelope for signature
  Envelope Name: "Contract - Acme Corp"
  Subject: "Please sign your service agreement"
  Message: "Thank you for choosing our services..."
  Requestor Email: "john.smith@agency.gov"
  Department: "Procurement"
  Requires Approval: false
```

---

### 2. Add signer to envelope

**Use:** Add a person who needs to sign

**Parameters:**

- `cs_email` (required): Signer email
- `cs_fullname` (required): Signer full name
- `cs_signerorder` (required): Order (1, 2, 3...)
- `cs_phonenumber`: Phone (optional)
- `cs_envelopeid@odata.bind` (required): `/cs_envelopes(guid)`

**Returns:**

- `cs_signerid`: Signer record GUID

**Example:**

```javascript
Add signer to envelope
  Email: "customer@company.com"
  Full Name: "Jane Doe"
  Signing Order: 1
  Envelope: "/cs_envelopes(@{outputs('Submit_envelope')?['body/cs_envelopeid']})"
```

---

### 3. Add document to envelope

**Use:** Attach PDF/document to envelope

**Parameters:**

- `cs_filename` (required): Filename (e.g., "contract.pdf")
- `cs_filecontent` (required): Base64 encoded content
- `cs_documentorder` (required): Order (1, 2, 3...)
- `cs_envelopeid@odata.bind` (required): `/cs_envelopes(guid)`

**Returns:**

- `cs_documentid`: Document record GUID

**Example:**

```javascript
// First, get file and convert to base64
Get file content (SharePoint)
  File: Contract.pdf

Compose - Base64
  Inputs: @{base64(outputs('Get_file_content')?['body'])}

Add document to envelope
  Filename: "Contract.pdf"
  File Content: @{outputs('Compose_-_Base64')}
  Document Order: 1
  Envelope: "/cs_envelopes(@{outputs('Submit_envelope')?['body/cs_envelopeid']})"
```

---

### 4. Get envelope details

**Use:** Retrieve current status and details

**Parameters:**

- `envelopeId` (required): Envelope GUID

**Returns:**

- Complete envelope details including status, dates, Nintex ID

**Example:**

```javascript
Get envelope details
  Envelope ID: @{triggerOutputs()?['body/cs_envelopeid']}
```

---

### 5. List envelopes

**Use:** Query envelopes with filters

**Parameters:**

- `$filter`: OData filter (e.g., `cs_status eq 'Completed'`)
- `$select`: Columns to return
- `$top`: Number of records (max 5000)

**Returns:**

- Array of envelope records

**Example:**

```javascript
List envelopes
  Filter: "cs_requestoremail eq '@{user()?['email']}' and cs_status eq 'InProcess'"
  Top: 100
```

---

### 6. Update envelope

**Use:** Modify envelope (e.g., cancel)

**Parameters:**

- `envelopeId` (required): Envelope GUID
- `cs_iscancelled`: Set true to cancel
- `cs_notes`: Additional notes

**Example:**

```javascript
Update envelope
  Envelope ID: @{triggerOutputs()?['body/cs_envelopeid']}
  Is Cancelled: true
```

---

### 7. Get envelope signers

**Use:** Retrieve all signers and their status

**Parameters:**

- `envelopeId` (required): Envelope GUID

**Returns:**

- Array of signers with signing links and status

**Example:**

```javascript
Get envelope signers
  Envelope ID: @{variables('varEnvelopeId')}

// Use in Apply to each:
Apply to each
  From: @{outputs('Get_envelope_signers')?['body/value']}
  
  Send email
    To: @{item()?['cs_email']}
    Body: Your signing link: @{item()?['cs_signinglink']}
```

---

### 8. List available templates

**Use:** Get Nintex templates you can use

**Returns:**

- Array of templates with IDs and descriptions

**Example:**

```javascript
List available templates

// Display in dropdown:
Items: outputs('List_available_templates')?['body/value']
Value: cs_nintextemplateid
DisplayName: cs_name
```

---

## Status Values

Envelopes progress through these statuses:

| Status                     | Description                 | What It Means                           |
| -------------------------- | --------------------------- | --------------------------------------- |
| **Pending Approval** | Waiting for approval        | Submitted with requires_approval = true |
| **Approved**         | Approved, queued for Nintex | Broker service will submit to Nintex    |
| **Submitted**        | Sent to Nintex              | Being processed by Nintex               |
| **InProcess**        | Sent to signers             | Signers have signing links              |
| **Completed**        | All signed                  | Envelope is complete                    |
| **Cancelled**        | Cancelled                   | Stopped by user or broker               |
| **Rejected**         | Approval rejected           | Director rejected submission            |
| **Failed**           | Submission error            | Technical error occurred                |

---

## Monitoring and Status Checks

### Option 1: Scheduled Status Sync Flow

Create a flow that runs every 30 minutes to check your envelopes:

```yaml
Trigger: Recurrence (every 30 minutes)

1. List envelopes
   Filter: cs_status ne 'Completed' and cs_status ne 'Cancelled' and cs_requestoremail eq '@{user()?['email']}'

2. Apply to each envelope
   
   a. Get envelope details (for latest status)
   
   b. Condition: Status changed?
      Compare to stored value in your system
   
   c. If changed:
      - Update your CRM/database
      - Send notification
      - If completed: Download signed docs
```

### Option 2: Webhook (Future Feature)

Broker service will support webhooks to push status updates to your environment.

---

## File Handling Best Practices

### Converting Files to Base64

Power Automate provides multiple ways to get base64 content:

#### From SharePoint:

```javascript
Get file content
  Site: Your site
  File: Your file

Compose
  Inputs: @{base64(outputs('Get_file_content')?['body'])}
```

#### From OneDrive:

```javascript
Get file content
  File: File identifier

Compose
  Inputs: @{base64(body('Get_file_content'))}
```

#### From Email Attachment:

```javascript
When a new email arrives (with attachment)

Apply to each (Attachments)
  
  Compose - Base64
    Inputs: @{items('Apply_to_each')?['contentBytes']}
  
  Add document to envelope
    File Content: @{outputs('Compose_-_Base64')}
```

---

## Security & Compliance

### Data Protection

✅ **In Transit:** All data encrypted with TLS 1.2+
✅ **At Rest:** Dataverse encryption
✅ **Authentication:** OAuth 2.0 with service principal
✅ **Authorization:** Row-level security in broker
✅ **Audit:** Complete audit trail maintained

### Compliance Certifications

- **Protected B** (Government of Canada)
- **SOC 2 Type II**
- **ISO 27001**
- **PIPEDA Compliant**

### Data Residency

- Broker service hosted in **Canada (Toronto)**
- Nintex data stored in **North America**
- No data crosses borders without approval

---

## Troubleshooting

### Issue: "Unauthorized" Error

**Cause:** Service principal credentials invalid or expired

**Solution:**

1. Verify Client ID and Secret are correct
2. Check connection is active (Data → Connections)
3. Delete and recreate connection
4. Contact Elections if issue persists

---

### Issue: "Envelope not submitted to Nintex"

**Cause:** Pending approval or missing required data

**Solution:**

1. Check envelope status: `Get envelope details`
2. If "Pending Approval": Wait for director approval
3. If "Failed": Check error message in `cs_errormessage`
4. Ensure all required signers and documents added

---

### Issue: "Signer not receiving email"

**Cause:** Email in spam or envelope not yet submitted

**Solution:**

1. Check envelope status is "InProcess" (not "Pending Approval")
2. Get signing link: `Get envelope signers`
3. Send link directly via your own email
4. Check signer's spam folder

---

### Issue: "Document not attached"

**Cause:** Base64 encoding issue or file too large

**Solution:**

1. Verify file is properly base64 encoded
2. Check file size (max 10MB per document)
3. Test with small sample PDF first
4. Ensure `cs_filecontent` field populated

---

## Support & Contact

### For Technical Issues

**Email:** esign-support@Elections.com
**Phone:** 1-800-XXX-XXXX
**Hours:** Monday-Friday, 8 AM - 6 PM ET

**Include in Support Request:**

- Your agency name
- Environment URL
- Envelope ID (if applicable)
- Error message screenshot
- Flow run history link

### For Service Principal Access

**Email:** esign-admin@Elections.com

### For Training

Training sessions available:

- Monthly webinars (register online)
- Custom training for your team
- Video tutorials (YouTube channel)

---

## Pricing

### Included Services

✅ Custom connector access
✅ Unlimited envelope submissions
✅ Status synchronization
✅ Audit logging
✅ Template library access
✅ Technical support
✅ Monthly usage reports

### Pricing Model

- **Base Fee:** $500/month per agency
- **Per Envelope:** $2.50 per completed envelope
- **Bulk Discount:** >1000 envelopes/month (contact for pricing)

**Example:**

- 200 envelopes/month = $500 + (200 × $2.50) = $1,000/month

---

## Best Practices

### ✅ Do's

1. **Test in Sandbox First**

   - Create test flows before production
   - Use test email addresses
   - Verify all scenarios
2. **Use Environment Variables**

   - Store service principal credentials
   - Never hardcode in flows
3. **Implement Error Handling**

   - Add "Configure run after" for failures
   - Log errors to SharePoint or Dataverse
   - Notify admins of issues
4. **Monitor Usage**

   - Track monthly envelope count
   - Review failed submissions
   - Optimize flows based on metrics
5. **Secure Credentials**

   - Store in Azure Key Vault
   - Rotate secrets quarterly
   - Limit access to connections

### ❌ Don'ts

1. **Don't Share Credentials**

   - Each agency gets unique service principal
   - Don't share Client Secret
2. **Don't Skip Testing**

   - Always test with small batches first
   - Verify status updates work
3. **Don't Hardcode Emails**

   - Use dynamic expressions
   - Pull from Dataverse/SharePoint
4. **Don't Ignore Errors**

   - Check flow run history regularly
   - Address failures promptly

---

## Appendix: Complete Example Flow

### Full Contract Submission Workflow

```yaml
Name: Submit Vendor Contract for Signature

Trigger: When a new contract record is created in Dataverse
Table: Contracts

Variables:
  - varEnvelopeId (String)
  - varContractPDF (String - Base64)

Steps:

1. Get contract details
   Source: Trigger outputs
   Store:
     - Vendor Name
     - Vendor Email
     - Contract Value
     - Department

2. Condition: Requires Approval?
   If: Contract Value > 100000
   Then: Set Requires Approval = true
   Else: Set Requires Approval = false

3. Get contract template from SharePoint
   Site: Your SharePoint
   Library: Contract Templates
   File: Standard Vendor Agreement.pdf

4. Convert to Base64
   Set variable: varContractPDF
   Value: @{base64(outputs('Get_file_content')?['body'])}

5. Submit envelope for signature
   Envelope Name: Vendor Contract - @{outputs('Get_contract_details')?['VendorName']}
   Subject: Service Agreement - Action Required
   Message: Please review and sign the attached service agreement...
   Requestor Email: @{triggerOutputs()?['body/submitteremail']}
   Department: @{outputs('Get_contract_details')?['Department']}
   Template ID: (leave blank if using uploaded doc)
   Days to Expire: 30
   Reminder Frequency: 3
   Requires Approval: @{variables('varRequiresApproval')}

6. Set variable: varEnvelopeId
   Value: @{outputs('Submit_envelope_for_signature')?['body/cs_envelopeid']}

7. Add vendor as signer
   Email: @{outputs('Get_contract_details')?['VendorEmail']}
   Full Name: @{outputs('Get_contract_details')?['VendorContactName']}
   Signing Order: 1
   Envelope: /cs_envelopes(@{variables('varEnvelopeId')})

8. Add procurement officer as signer
   Email: procurement.officer@agency.gov
   Full Name: John Smith
   Signing Order: 2
   Envelope: /cs_envelopes(@{variables('varEnvelopeId')})

9. Add contract document
   Filename: Vendor_Agreement.pdf
   File Content: @{variables('varContractPDF')}
   Document Order: 1
   Envelope: /cs_envelopes(@{variables('varEnvelopeId')})

10. Update contract record in Dataverse
    Table: Contracts
    Row ID: @{triggerOutputs()?['body/contractid']}
    Fields:
      Envelope ID: @{variables('varEnvelopeId')}
      Status: @{if(variables('varRequiresApproval'), 'Pending Approval', 'Submitted for Signature')}
      Submitted Date: @{utcNow()}

11. Send confirmation email
    To: @{triggerOutputs()?['body/submitteremail']}
    Subject: Contract Submitted for Signature
    Body:
      Your contract with @{outputs('Get_contract_details')?['VendorName']} has been submitted.
    
      Envelope ID: @{variables('varEnvelopeId')}
      Status: @{if(variables('varRequiresApproval'), 'Awaiting director approval', 'Sent to signers')}
    
      You will receive updates as the contract progresses.

12. Error Handling (Configure run after: Any action has failed)
  
    Compose - Error Details
      Error: @{outputs('Submit_envelope_for_signature')?['error']}
      Details: @{body('Submit_envelope_for_signature')}
  
    Send email to admin
      To: esign-admin@agency.gov
      Subject: Contract Submission Failed
      Body: @{outputs('Compose_-_Error_Details')}
  
    Update contract record
      Status: Failed
      Error Message: @{outputs('Compose_-_Error_Details')}
```

---

## FAQ

**Q: Can I use this in Power Apps?**
A: Yes! Add the connector as a data source and call actions from buttons.

**Q: How long do envelopes take to process?**
A: Immediate if no approval required. With approval, depends on director response time.

**Q: Can I customize email templates?**
A: Not yet. Template customization coming in Q2 2026.

**Q: What file formats are supported?**
A: PDF recommended. Word/Excel converted to PDF automatically.

**Q: Can I get signing links without sending email?**
A: Yes! Use "Get envelope signers" to retrieve links and send via your own method.

**Q: Is there a test environment?**
A: Yes, Elections provides sandbox environment for testing.

**Q: Can I integrate with my CRM?**
A: Absolutely! Use standard Power Automate connectors alongside ESign connector.

**Q: What happens if Elections service goes down?**
A: SLA guarantees 99.9% uptime. Status page: status.Elections-esign.com

---

## Next Steps

1. ✅ **Request service principal** from Elections
2. ✅ **Import custom connector** to your environment
3. ✅ **Create test flow** with sample envelope
4. ✅ **Build production flows** for your scenarios
5. ✅ **Train your team** on the connector
6. ✅ **Go live!**

---

**Ready to get started? Contact us at esign-support@Elections.com**

**Built by Elections Canada**
**Powered by Nintex AssureSign**
**Secured by Microsoft Dataverse**
