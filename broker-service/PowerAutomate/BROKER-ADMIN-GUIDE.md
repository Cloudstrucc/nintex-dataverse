# ESign Broker Service - Admin Setup Guide

## Overview

This guide is for **Leonardo Company administrators** setting up and managing the ESign broker service.

## Architecture Overview

```
Client Agencies → Custom Connector → Your Broker Environment → Nintex API
```

Your broker environment acts as the middleware, handling:
- Authentication & authorization
- Approval workflows  
- API integration with Nintex
- Status synchronization
- Audit logging
- Multi-tenant isolation

---

## Initial Setup

### Step 1: Deploy Dataverse Tables

You already have the schema. Ensure these tables are deployed:

- ✅ cs_envelope
- ✅ cs_signer
- ✅ cs_document
- ✅ cs_field
- ✅ cs_template
- ✅ cs_apirequest
- ✅ cs_webhook
- ✅ cs_emailnotification
- ✅ cs_authtoken

### Step 2: Configure Security Roles

Create **Application User** security role with:

**Privileges on Nintex tables:**
- cs_envelope: Create, Read, Write, Append, AppendTo
- cs_signer: Create, Read, Write, Append, AppendTo
- cs_document: Create, Read, Write, Append, AppendTo
- cs_field: Create, Read, Write, Append, AppendTo
- cs_template: Read
- cs_apirequest: Create, Read, Write

**Note:** Users should only see their own records (configure column security)

### Step 3: Enable Web API Access

1. **Settings** → **Administration** → **System Settings**
2. **Customization** tab
3. Enable **Web API** ✅
4. Save

### Step 4: Deploy Broker Flows

Deploy these flows in your broker environment:

#### Flow 1: On Envelope Create - Submit to Nintex

```yaml
Trigger: When a row is added
Table: cs_envelope

Condition: cs_requiresapproval eq false

Steps:
  1. Get related signers
  2. Get related documents
  3. Authenticate with Nintex (HTTP)
  4. Build submission payload
  5. Submit to Nintex (HTTP)
  6. Parse response
  7. Update envelope with Nintex ID
  8. Update signers with signing links
  9. Log to cs_apirequest
```

#### Flow 2: Approval Workflow

```yaml
Trigger: When a row is added
Table: cs_envelope

Condition: cs_requiresapproval eq true

Steps:
  1. Get envelope details
  2. Start approval (built-in Approval action)
     - Assigned to: Director email
     - Title: Envelope approval request
     - Details: Envelope info
  3. Wait for approval response
  4. If approved:
     - Update status: Approved
     - Trigger submission (update record)
  5. If rejected:
     - Update status: Rejected
     - Notify requestor
```

#### Flow 3: Status Sync (Scheduled)

```yaml
Trigger: Recurrence (every 30 minutes)

Steps:
  1. List envelopes
     Filter: cs_status in ('Submitted', 'InProcess')
  
  2. For each envelope:
     - Authenticate with Nintex
     - Get status
     - Update Dataverse record
     - If completed: Download docs
```

---

## Client Onboarding Process

### For Each New Agency:

#### 1. Create Application User (Service Principal)

**Azure Portal:**
```
1. Azure AD → App registrations → New registration
   Name: ESign-[AgencyName]
   
2. Create Client Secret
   Copy: Client ID, Client Secret, Tenant ID

3. API Permissions → Add permission
   - Dynamics CRM → user_impersonation
   - Grant admin consent
```

**Power Platform Admin Center:**
```
1. Environments → [Your Broker Environment]
2. Settings → Users + permissions → Application users
3. New app user
   - App: [The app you created]
   - Business unit: Root
   - Security role: [Your custom role]
```

#### 2. Send Credentials to Agency

Email template:
```
Subject: ESign Elections Canada - Service Principal Credentials

Hello [Agency Contact],

Your ESign service is ready! Here are your credentials:

Tenant ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Client Secret: [secret]
Broker Environment: https://lce-broker.crm3.dynamics.com

Next steps:
1. Import the custom connector (attached)
2. Follow the Client Integration Guide (attached)
3. Test with sample flow

Support: esign-support@leonardo.com

Best regards,
Leonardo IT Team
```

#### 3. Configure Row-Level Security

Ensure application users only see their own records:

**Option A: Owner-based (Recommended)**
```
When agency creates record via API:
- Owner = their application user
- They can only query their records
```

**Option B: Custom field filter**
```
Add field: cs_clientid (Text)
Populate with: Client ID on create
Filter all queries by: cs_clientid eq [their client ID]
```

---

## Customizing the Swagger File

Before distributing to clients, update:

```json
{
  "host": "YOUR-ACTUAL-BROKER-URL.crm3.dynamics.com",
  "securityDefinitions": {
    "oauth2": {
      "authorizationUrl": "https://login.microsoftonline.com/YOUR-TENANT-ID/oauth2/v2.0/authorize",
      "tokenUrl": "https://login.microsoftonline.com/YOUR-TENANT-ID/oauth2/v2.0/token",
      "scopes": {
        "https://YOUR-ACTUAL-BROKER-URL.crm3.dynamics.com/.default": "Access broker service"
      }
    }
  }
}
```

**Tool to update:** Use find/replace in VS Code

---

## Monitoring & Management

### Dashboard Queries

Create Power BI dashboard with these queries:

**Total Envelopes by Status:**
```sql
SELECT 
  cs_status,
  COUNT(*) as Count
FROM cs_envelope
GROUP BY cs_status
```

**Envelopes by Agency:**
```sql
SELECT 
  ownerid,
  cs_departmentname,
  COUNT(*) as TotalEnvelopes,
  SUM(CASE WHEN cs_status = 'Completed' THEN 1 ELSE 0 END) as Completed
FROM cs_envelope
GROUP BY ownerid, cs_departmentname
```

**Failed Submissions:**
```sql
SELECT 
  cs_name,
  cs_requestoremail,
  cs_errormessage,
  createdon
FROM cs_envelope
WHERE cs_status = 'Failed'
ORDER BY createdon DESC
```

### Alerts

Set up alerts for:
- ❌ Failed envelope submissions (>5 in 1 hour)
- ⏱️ Pending approvals >24 hours old
- 🔐 Authentication failures
- 📊 Usage exceeds quota

---

## Billing & Usage Tracking

### Track Usage per Agency

```sql
SELECT 
  ownerid,
  cs_departmentname,
  COUNT(*) as EnvelopesThisMonth,
  COUNT(*) * 2.50 as VariableFees
FROM cs_envelope
WHERE 
  createdon >= DATEADD(month, -1, GETDATE())
  AND cs_status = 'Completed'
GROUP BY ownerid, cs_departmentname
```

### Generate Monthly Invoices

Create scheduled flow:
```yaml
Trigger: Recurrence (1st of each month)

Steps:
  1. Query usage per agency (last month)
  2. Calculate fees
  3. Generate invoice PDF
  4. Email to billing contact
  5. Log in finance system
```

---

## Troubleshooting

### Client Reports "Unauthorized"

**Check:**
1. Application user exists in environment
2. Security role assigned
3. Client ID/Secret match
4. Token not expired

**Fix:**
```powershell
# Test authentication
$body = @{
    client_id = "client-id"
    client_secret = "secret"
    scope = "https://broker-url.crm3.dynamics.com/.default"
    grant_type = "client_credentials"
}
Invoke-RestMethod -Uri "https://login.microsoftonline.com/tenant-id/oauth2/v2.0/token" -Method POST -Body $body
```

### Envelope Stuck in "Pending Approval"

**Check:**
1. Approval flow is running
2. Director email is correct
3. No errors in flow run history

**Fix:**
- Manually approve via flow
- Check approval action configuration

### Nintex API Calls Failing

**Check:**
1. Nintex credentials in environment variables
2. Token refresh logic working
3. API rate limits

**Fix:**
- Test authentication endpoint directly
- Verify environment variables set
- Check Nintex API status

---

## Scaling Considerations

### Current Architecture Limits

- **Envelopes/day:** ~10,000 (Dataverse API limits)
- **Concurrent requests:** 100 (DLP throttling)
- **Storage:** Unlimited (Dataverse)

### When to Scale

If you exceed:
- 500 envelopes/hour consistently
- 20+ client agencies
- 50,000 envelopes/month total

**Consider:**
1. Multiple broker environments (geographic)
2. Premium capacity (dedicated resources)
3. Azure API Management (caching, throttling)

---

## Security Hardening

### Recommendations

1. **Enable MFA** for all admin accounts
2. **Rotate secrets** quarterly
3. **Monitor API calls** for anomalies
4. **Audit security roles** monthly
5. **Enable DLP policies**
6. **Implement IP restrictions** (if possible)

### Compliance

Maintain:
- ✅ Audit logs (2 years)
- ✅ Security documentation
- ✅ Incident response plan
- ✅ Privacy impact assessment
- ✅ Data classification

---

## Backup & Disaster Recovery

### Backup Strategy

**Weekly:** Full environment backup
**Daily:** Incremental backups
**Retention:** 30 days

**Use:**
```
Power Platform Admin Center → Environments → Backups
```

### Disaster Recovery

**RTO:** 4 hours  
**RPO:** 24 hours

**Plan:**
1. Restore from backup
2. Reconfigure DNS (if needed)
3. Notify clients of maintenance
4. Verify all flows running
5. Test sample envelope submission

---

## Version Control

### Connector Versioning

When updating connector:
1. Increment version in swagger
2. Test in sandbox
3. Notify clients 2 weeks ahead
4. Maintain backward compatibility
5. Deprecate old versions after 3 months

**Example:**
```json
{
  "info": {
    "version": "1.1.0",
    "description": "v1.1.0 - Added bulk submission endpoint"
  }
}
```

---

## Support Escalation

### Tier 1: Client Support
- Email: esign-support@leonardo.com
- Response: 4 business hours
- Handles: Usage questions, connector import, flow examples

### Tier 2: Technical Support  
- Email: esign-admin@leonardo.com
- Response: 2 business hours
- Handles: API errors, authentication issues, data problems

### Tier 3: Engineering
- Internal escalation only
- Response: 1 business hour (critical)
- Handles: System outages, security incidents

---

## Appendix: Full Broker Flow Example

### Complete Envelope Submission Flow

```yaml
Name: Process Envelope Submission

Trigger: When a row is added
Table: cs_envelope

Steps:

1. Initialize variables
   - varNintexToken (String)
   - varEnvelopePayload (Object)
   - varNintexResponse (Object)

2. Condition: Check if requires approval
   If: cs_requiresapproval eq true
   Then:
     - Update status: Pending Approval
     - Start approval process
     - Stop (approval flow handles next steps)
   Else: Continue

3. Get related signers
   List rows: cs_signer
   Filter: _cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}
   OrderBy: cs_signerorder asc

4. Get related documents
   List rows: cs_document
   Filter: _cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}
   OrderBy: cs_documentorder asc

5. HTTP - Authenticate Nintex
   Method: POST
   URI: https://api.assuresign.net/v3.7/authentication/apiUser
   Body: {APIUsername, Key, ContextUsername}

6. Parse JSON - Token
   Content: @{body('HTTP_-_Authenticate_Nintex')}

7. Set variable: varNintexToken
   Value: @{body('Parse_JSON_-_Token')?['token']}

8. Select - Build Signers Array
   From: @{outputs('Get_related_signers')?['body/value']}
   Map: {Email, FullName, SignerOrder}

9. Select - Build Documents Array
   From: @{outputs('Get_related_documents')?['body/value']}
   Map: {FileName, FileContent, DocumentOrder}

10. Compose - Build Payload
    {
      "TemplateID": "@{triggerOutputs()?['body/cs_templateid']}",
      "Subject": "@{triggerOutputs()?['body/cs_subject']}",
      "Message": "@{triggerOutputs()?['body/cs_message']}",
      "DaysToExpire": @{triggerOutputs()?['body/cs_daystoexpire']},
      "ReminderFrequency": @{triggerOutputs()?['body/cs_reminderfrequency']},
      "Signers": @{outputs('Select_-_Build_Signers_Array')},
      "Documents": @{outputs('Select_-_Build_Documents_Array')}
    }

11. HTTP - Submit to Nintex
    Method: POST
    URI: https://api.assuresign.net/v3.7/submit
    Headers:
      Authorization: Bearer @{variables('varNintexToken')}
      Content-Type: application/json
    Body: @{outputs('Compose_-_Build_Payload')}

12. Parse JSON - Nintex Response
    Content: @{body('HTTP_-_Submit_to_Nintex')}

13. Update a row - Update Envelope
    Table: cs_envelope
    Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
    Fields:
      cs_nintexenvelopeid: @{body('Parse_JSON_-_Nintex_Response')?['EnvelopeID']}
      cs_status: Submitted
      cs_sentdate: @{utcNow()}
      cs_requestbody: @{outputs('Compose_-_Build_Payload')}
      cs_responsebody: @{body('HTTP_-_Submit_to_Nintex')}

14. Apply to each - Update Signers
    From: @{body('Parse_JSON_-_Nintex_Response')?['Signers']}
    
    Steps:
      Update a row: cs_signer
      Filter: cs_email eq '@{items('Apply_to_each')?['Email']}'
      Fields:
        cs_nintexsignerid: @{items('Apply_to_each')?['SignerID']}
        cs_signinglink: @{items('Apply_to_each')?['SigningLink']}

15. Add a new row - Log API Request
    Table: cs_apirequest
    Fields:
      cs_name: Envelope Submission - @{utcNow()}
      cs_envelopeid: @{triggerOutputs()?['body/cs_envelopeid']}
      cs_method: POST
      cs_endpoint: /submit
      cs_requestbody: @{outputs('Compose_-_Build_Payload')}
      cs_responsebody: @{body('HTTP_-_Submit_to_Nintex')}
      cs_statuscode: 200
      cs_success: true

16. Send email - Notify requestor
    To: @{triggerOutputs()?['body/cs_requestoremail']}
    Subject: Envelope Submitted
    Body: Your envelope has been sent to signers...

--- Error Handling ---

17. Configure run after: HTTP - Submit to Nintex
    Run after: has failed

    Steps:
      a. Update a row - Mark Failed
         Table: cs_envelope
         Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
         Fields:
           cs_status: Failed
           cs_errormessage: @{outputs('HTTP_-_Submit_to_Nintex')?['error']}
      
      b. Add a new row - Log Error
         Table: cs_apirequest
         Fields:
           cs_success: false
           cs_errormessage: @{outputs('HTTP_-_Submit_to_Nintex')?['error']}
      
      c. Send email - Alert Admin
         To: esign-admin@leonardo.com
         Subject: Envelope Submission Failed
```

---

**Your broker service is ready to serve multiple agencies! 🚀**
