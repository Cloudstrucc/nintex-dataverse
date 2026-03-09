# Nintex Dataverse Proxy - Deployment Checklist

## Pre-Deployment

### Environment Setup
- [ ] Visual Studio 2019+ installed
- [ ] .NET Framework 4.6.2 SDK installed
- [ ] Plugin Registration Tool downloaded
- [ ] Dataverse environment access (System Administrator role)
- [ ] All Nintex tables deployed (cs_envelope, cs_signer, cs_document, etc.)

### Nintex Credentials
- [ ] Nintex API URL obtained (e.g., https://api.assuresign.net/v3.7)
- [ ] API Username obtained
- [ ] API Key obtained  
- [ ] Context Username (email) obtained
- [ ] Credentials tested via Postman/cURL

## Build Process

### Step 1: Prepare Project
- [ ] Extract all source files to folder
- [ ] Open folder in Visual Studio Developer PowerShell
- [ ] Files present:
  - [ ] NintexApiClient.cs
  - [ ] DataverseToNintexMapper.cs
  - [ ] EnvelopePlugin.cs
  - [ ] EnvelopeCompleteSubmissionPlugin.cs
  - [ ] EnvelopeStatusUpdatePlugin.cs
  - [ ] NintexDataverseProxy.csproj

### Step 2: Build
- [ ] Run `.\Build.ps1` or manually:
  - [ ] `sn -k NintexDataverseProxy.snk`
  - [ ] `dotnet restore`
  - [ ] `dotnet build --configuration Release`
- [ ] Verify output: `bin/Release/net462/NintexDataverseProxy.dll` exists
- [ ] Check file size (should be ~50-100 KB)

## Plugin Registration

### Step 1: Register Assembly
- [ ] Open Plugin Registration Tool
- [ ] Connect to Dataverse environment
- [ ] Click "Register" → "Register New Assembly"
- [ ] Browse to `NintexDataverseProxy.dll`
- [ ] Settings:
  - [ ] Isolation Mode: **Sandbox**
  - [ ] Location: **Database**
- [ ] Click "Register Selected Plugins"
- [ ] Verify: Assembly appears in tool with version number

### Step 2: Prepare Secure Configuration
- [ ] Create JSON configuration:
```json
{
  "ApiUrl": "https://api.assuresign.net/v3.7",
  "ApiUsername": "YOUR_USERNAME",
  "ApiKey": "YOUR_KEY",
  "ContextUsername": "YOUR_EMAIL"
}
```
- [ ] Replace placeholders with actual values
- [ ] Validate JSON syntax (use jsonlint.com)
- [ ] Copy to clipboard

### Step 3: Register EnvelopeCompleteSubmissionPlugin - CREATE
- [ ] Select `NintexDataverseProxy.Plugins.EnvelopeCompleteSubmissionPlugin`
- [ ] Click "Register New Step"
- [ ] Configuration:
  - [ ] Message: **Create**
  - [ ] Primary Entity: **cs_envelope**
  - [ ] Event Pipeline Stage: **PostOperation**
  - [ ] Execution Mode: **Synchronous**
  - [ ] Deployment: **Server**
- [ ] Paste secure configuration (from Step 2)
- [ ] Leave unsecure configuration empty
- [ ] Execution Order: **1**
- [ ] Click "Register New Step"

### Step 4: Register EnvelopePlugin - UPDATE
- [ ] Select `NintexDataverseProxy.Plugins.EnvelopePlugin`
- [ ] Click "Register New Step"
- [ ] Configuration:
  - [ ] Message: **Update**
  - [ ] Primary Entity: **cs_envelope**
  - [ ] Event Pipeline Stage: **PostOperation**
  - [ ] Execution Mode: **Synchronous**
- [ ] Paste secure configuration
- [ ] Filtering Attributes: **cs_iscancelled**
- [ ] Post-Image:
  - [ ] Name: **PostImage**
  - [ ] Entity Alias: **PostImage**
  - [ ] Parameters: **All Attributes**
- [ ] Click "Register New Step"

### Step 5: Register EnvelopePlugin - DELETE
- [ ] Select `NintexDataverseProxy.Plugins.EnvelopePlugin`
- [ ] Click "Register New Step"
- [ ] Configuration:
  - [ ] Message: **Delete**
  - [ ] Primary Entity: **cs_envelope**
  - [ ] Event Pipeline Stage: **PreOperation**
  - [ ] Execution Mode: **Synchronous**
- [ ] Paste secure configuration
- [ ] Pre-Image:
  - [ ] Name: **PreImage**
  - [ ] Entity Alias: **PreImage**
  - [ ] Parameters: **All Attributes**
- [ ] Click "Register New Step"

### Step 6: Register EnvelopeStatusUpdatePlugin (Optional)
- [ ] Select `NintexDataverseProxy.Plugins.EnvelopeStatusUpdatePlugin`
- [ ] Click "Register New Step"
- [ ] Configuration:
  - [ ] Message: **Retrieve**
  - [ ] Primary Entity: **cs_envelope**
  - [ ] Event Pipeline Stage: **PostOperation**
  - [ ] Execution Mode: **Asynchronous**
- [ ] Paste secure configuration
- [ ] Click "Register New Step"

## Testing

### Test 1: Simple Envelope Creation
- [ ] Open Dataverse Web API or Power Apps
- [ ] Create new cs_envelope record:
  - [ ] cs_name: "Test Envelope"
  - [ ] cs_subject: "Test Subject"
  - [ ] cs_templateid: [valid Nintex template ID]
- [ ] Wait for creation to complete
- [ ] Verify:
  - [ ] cs_envelopeid populated
  - [ ] cs_status populated
  - [ ] cs_requestbody contains JSON
  - [ ] cs_responsebody contains JSON

### Test 2: Complete Envelope with Signers
- [ ] Create cs_envelope
- [ ] Create related cs_signer records:
  - [ ] cs_email: valid email
  - [ ] cs_fullname: "Test Signer"
  - [ ] cs_signerorder: 1
- [ ] Create related cs_document:
  - [ ] cs_filename: "test.pdf"
  - [ ] cs_filecontent: [base64 PDF]
- [ ] Trigger envelope submission
- [ ] Verify all records updated with Nintex IDs

### Test 3: Cancel Envelope
- [ ] Find existing envelope
- [ ] Update: cs_iscancelled = true
- [ ] Verify:
  - [ ] cs_cancelleddate populated
  - [ ] Nintex envelope cancelled
  - [ ] No errors in Plugin Trace Log

### Test 4: Delete Envelope
- [ ] Create test envelope
- [ ] Delete the record
- [ ] Verify:
  - [ ] Nintex envelope cancelled first
  - [ ] Dataverse record deleted
  - [ ] No errors

## Monitoring Setup

### Enable Plugin Trace Log
- [ ] Navigate to Settings → System → Administration
- [ ] Click "System Settings"
- [ ] Go to "Customization" tab
- [ ] Set "Enable logging to plug-in trace log": **All**
- [ ] Click "OK"

### Create Monitoring View
- [ ] Open Power Apps maker portal
- [ ] Go to cs_apirequest table
- [ ] Create view "Failed Requests":
  - [ ] Filter: cs_success = false
  - [ ] Sort by: cs_requestdate descending
- [ ] Save and publish

### Set Up Alerts (Optional)
- [ ] Create Power Automate flow
- [ ] Trigger: When a row is added (cs_apirequest)
- [ ] Condition: cs_success = false
- [ ] Action: Send email to admin
- [ ] Save and turn on

## Post-Deployment

### Documentation
- [ ] Document deployed plugin version
- [ ] Record secure configuration (in secure location)
- [ ] Update runbook with deployment date
- [ ] Share deployment notes with team

### Training
- [ ] Train users on new workflow
- [ ] Provide example API calls
- [ ] Share troubleshooting guide

### Maintenance Schedule
- [ ] Schedule: Review Plugin Trace Logs (weekly)
- [ ] Schedule: Review cs_apirequest failures (daily)
- [ ] Schedule: Rotate API keys (quarterly)
- [ ] Schedule: Update plugin (as needed)

## Rollback Plan

### If Issues Occur
- [ ] Disable problematic plugin step (unregister)
- [ ] Review Plugin Trace Logs for errors
- [ ] Test in separate environment
- [ ] Re-register with fixes
- [ ] Monitor closely

### Emergency Rollback
1. [ ] Open Plugin Registration Tool
2. [ ] Unregister all plugin steps
3. [ ] Verify no errors in environment
4. [ ] Communicate to users
5. [ ] Investigate and fix issues

## Sign-Off

### Deployment Completed By
- Name: _____________________________
- Date: _____________________________
- Environment: _____________________________

### Verified By
- Name: _____________________________
- Date: _____________________________

### Production Approval
- Name: _____________________________
- Date: _____________________________

---

## Notes

Use this space for deployment-specific notes:

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
