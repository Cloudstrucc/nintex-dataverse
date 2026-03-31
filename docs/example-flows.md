# Power Automate Flow Examples for Nintex AssureSign

## Flow 1: Submit Envelope When Dataverse Record Created

### Description
Automatically submits envelope to Nintex when new cs_envelope record is created in Dataverse.

### Trigger
- **Type**: When a row is added
- **Table**: Envelopes (cs_envelope)

### Flow Steps

```yaml
1. Trigger: When a row is added (cs_envelope)
   
2. Get Nintex Authentication Token
   Action: HTTP Request
   Method: POST
   URI: https://api.assuresign.net/v3.7/authentication/apiUser
   Headers:
     Content-Type: application/json
   Body:
     {
       "APIUsername": "@{parameters('NintexAPIUsername')}",
       "Key": "@{parameters('NintexAPIKey')}",
       "ContextUsername": "@{parameters('NintexContextEmail')}"
     }

3. Parse Authentication Response
   Action: Parse JSON
   Content: @body('Get_Nintex_Authentication_Token')
   Schema:
     {
       "type": "object",
       "properties": {
         "token": {"type": "string"},
         "expires": {"type": "string"}
       }
     }

4. Get Related Signers
   Action: List rows (Dataverse)
   Table: Signers (cs_signer)
   Filter rows: _cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}
   Select columns: cs_email, cs_fullname, cs_signerorder

5. Get Related Documents
   Action: List rows (Dataverse)
   Table: Documents (cs_document)
   Filter rows: _cs_envelopeid_value eq @{triggerOutputs()?['body/cs_envelopeid']}
   Select columns: cs_filename, cs_filecontent, cs_documentorder

6. Build Signers Array
   Action: Select
   From: @outputs('Get_Related_Signers')?['body/value']
   Map:
     {
       "Email": "@{item()?['cs_email']}",
       "FullName": "@{item()?['cs_fullname']}",
       "SignerOrder": @{item()?['cs_signerorder']}
     }

7. Build Documents Array
   Action: Select
   From: @outputs('Get_Related_Documents')?['body/value']
   Map:
     {
       "FileName": "@{item()?['cs_filename']}",
       "FileContent": "@{item()?['cs_filecontent']}"
     }

8. Submit Envelope to Nintex
   Action: HTTP Request
   Method: POST
   URI: https://api.assuresign.net/v3.7/submit
   Headers:
     Authorization: Bearer @{body('Parse_Authentication_Response')?['token']}
     Content-Type: application/json
   Body:
     {
       "TemplateID": "@{triggerOutputs()?['body/cs_templateid']}",
       "Subject": "@{triggerOutputs()?['body/cs_subject']}",
       "Message": "@{triggerOutputs()?['body/cs_message']}",
       "DaysToExpire": @{triggerOutputs()?['body/cs_daystoexpire']},
       "ReminderFrequency": @{triggerOutputs()?['body/cs_reminderfrequency']},
       "Signers": @{outputs('Build_Signers_Array')},
       "Documents": @{outputs('Build_Documents_Array')}
     }

9. Parse Nintex Response
   Action: Parse JSON
   Content: @body('Submit_Envelope_to_Nintex')
   Schema:
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

10. Update Dataverse Envelope
    Action: Update a row (Dataverse)
    Table: Envelopes (cs_envelope)
    Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
    Fields:
      Envelope ID (cs_envelopeid): @{body('Parse_Nintex_Response')?['EnvelopeID']}
      Status (cs_status): @{body('Parse_Nintex_Response')?['Status']}
      Sent Date (cs_sentdate): @{body('Parse_Nintex_Response')?['SentDate']}
      Request Body (cs_requestbody): @{body('Submit_Envelope_to_Nintex')}
      Response Body (cs_responsebody): @{outputs('Submit_Envelope_to_Nintex')?['body']}

11. For Each Signer in Response
    Action: Apply to each
    From: @body('Parse_Nintex_Response')?['Signers']
    Steps:
      a. Update Signer Record
         Action: Update a row (Dataverse)
         Table: Signers (cs_signer)
         Filter: cs_email eq '@{items('For_Each_Signer_in_Response')?['Email']}'
         Fields:
           Signer ID (cs_signerid): @{items('For_Each_Signer_in_Response')?['SignerID']}
           Signing Link (cs_signinglink): @{items('For_Each_Signer_in_Response')?['SigningLink']}

12. Log API Request
    Action: Add a new row (Dataverse)
    Table: API Requests (cs_apirequest)
    Fields:
      Name (cs_name): Envelope Submission - @{utcNow()}
      Envelope ID (cs_envelopeid): @{body('Parse_Nintex_Response')?['EnvelopeID']}
      Method (cs_method): POST
      Endpoint (cs_endpoint): /submit
      Request Body (cs_requestbody): @{body('Submit_Envelope_to_Nintex')}
      Response Body (cs_responsebody): @{outputs('Submit_Envelope_to_Nintex')?['body']}
      Status Code (cs_statuscode): @{outputs('Submit_Envelope_to_Nintex')?['statusCode']}
      Success (cs_success): true
      Request Date (cs_requestdate): @{utcNow()}
```

---

## Flow 2: Scheduled Status Sync

### Description
Runs every 30 minutes to sync envelope status from Nintex to Dataverse.

### Trigger
- **Type**: Recurrence
- **Interval**: 30 minutes

### Flow Steps

```yaml
1. Trigger: Recurrence (every 30 minutes)

2. Get Nintex Authentication Token
   [Same as Flow 1, Step 2]

3. Parse Authentication Response
   [Same as Flow 1, Step 3]

4. List Active Envelopes
   Action: List rows (Dataverse)
   Table: Envelopes (cs_envelope)
   Filter rows: cs_status ne 'Completed' and cs_status ne 'Cancelled'
   Select columns: cs_envelopeid, cs_envelopeid

5. For Each Active Envelope
   Action: Apply to each
   From: @outputs('List_Active_Envelopes')?['body/value']
   Steps:
   
   a. Get Envelope Status from Nintex
      Action: HTTP Request
      Method: GET
      URI: https://api.assuresign.net/v3.7/envelopes/@{items('For_Each_Active_Envelope')?['cs_envelopeid']}/status
      Headers:
        Authorization: Bearer @{body('Parse_Authentication_Response')?['token']}

   b. Parse Status Response
      Action: Parse JSON
      Content: @body('Get_Envelope_Status_from_Nintex')
      Schema:
        {
          "type": "object",
          "properties": {
            "Status": {"type": "string"},
            "CompletedDate": {"type": "string"}
          }
        }

   c. Update Dataverse Record
      Action: Update a row (Dataverse)
      Table: Envelopes (cs_envelope)
      Row ID: @{items('For_Each_Active_Envelope')?['cs_envelopeid']}
      Fields:
        Status (cs_status): @{body('Parse_Status_Response')?['Status']}
        Completed Date (cs_completeddate): @{body('Parse_Status_Response')?['CompletedDate']}

   d. Condition: If Status is Completed
      If: @{equals(body('Parse_Status_Response')?['Status'], 'Completed')}
      Then:
        - Download Signed Documents
          Action: HTTP Request
          Method: POST
          URI: https://api.assuresign.net/v3.7/envelopes/@{items('For_Each_Active_Envelope')?['cs_envelopeid']}/download
          Headers:
            Authorization: Bearer @{body('Parse_Authentication_Response')?['token']}
          Body:
            {
              "DocumentType": "Combined"
            }
        
        - Save to SharePoint
          Action: Create file (SharePoint)
          Site: [Your SharePoint Site]
          Folder: /Signed Documents
          File name: Envelope-@{items('For_Each_Active_Envelope')?['cs_envelopeid']}.pdf
          File content: @{body('Download_Signed_Documents')}
        
        - Update Dataverse with Document Link
          Action: Update a row (Dataverse)
          Table: Envelopes (cs_envelope)
          Row ID: @{items('For_Each_Active_Envelope')?['cs_envelopeid']}
          Fields:
            Signed Document URL (cs_signeddocumenturl): @{outputs('Save_to_SharePoint')?['body/{Link}']}
```

---

## Flow 3: Cancel Envelope When Marked Cancelled

### Description
Cancels envelope in Nintex when cs_iscancelled is set to true in Dataverse.

### Trigger
- **Type**: When a row is modified
- **Table**: Envelopes (cs_envelope)
- **Filter**: cs_iscancelled eq true

### Flow Steps

```yaml
1. Trigger: When a row is modified (cs_envelope)
   Trigger conditions: cs_iscancelled eq true

2. Get Nintex Authentication Token
   [Same as Flow 1, Step 2]

3. Parse Authentication Response
   [Same as Flow 1, Step 3]

4. Cancel Envelope in Nintex
   Action: HTTP Request
   Method: PUT
   URI: https://api.assuresign.net/v3.7/envelopes/@{triggerOutputs()?['body/cs_envelopeid']}/cancel
   Headers:
     Authorization: Bearer @{body('Parse_Authentication_Response')?['token']}

5. Update Dataverse Record
   Action: Update a row (Dataverse)
   Table: Envelopes (cs_envelope)
   Row ID: @{triggerOutputs()?['body/cs_envelopeid']}
   Fields:
     Cancelled Date (cs_cancelleddate): @{utcNow()}
     Status (cs_status): Cancelled

6. Send Notification Email
   Action: Send an email (V2)
   To: @{triggerOutputs()?['body/cs_requestoremail']}
   Subject: Envelope Cancelled
   Body: Your envelope @{triggerOutputs()?['body/cs_name']} has been cancelled.
```

---

## Flow 4: Get Signing Links and Send Custom Email

### Description
When envelope is sent, retrieves signing links and sends custom branded email to signers.

### Trigger
- **Type**: When a row is modified
- **Table**: Envelopes (cs_envelope)
- **Filter**: cs_status eq 'InProcess'

### Flow Steps

```yaml
1. Trigger: When a row is modified (cs_envelope)
   Trigger conditions: cs_status eq 'InProcess'

2. Get Nintex Authentication Token
   [Same as Flow 1, Step 2]

3. Parse Authentication Response
   [Same as Flow 1, Step 3]

4. Get Signing Links
   Action: HTTP Request
   Method: GET
   URI: https://api.assuresign.net/v3.7/envelope/@{triggerOutputs()?['body/cs_envelopeid']}/signingLinks
   Headers:
     Authorization: Bearer @{body('Parse_Authentication_Response')?['token']}

5. Parse Signing Links
   Action: Parse JSON
   Content: @body('Get_Signing_Links')
   Schema:
     {
       "type": "array",
       "items": {
         "type": "object",
         "properties": {
           "SignerEmail": {"type": "string"},
           "SigningLink": {"type": "string"}
         }
       }
     }

6. For Each Signer
   Action: Apply to each
   From: @body('Parse_Signing_Links')
   Steps:
   
   a. Send Custom Email
      Action: Send an email (V2)
      To: @{items('For_Each_Signer')?['SignerEmail']}
      Subject: Action Required: Sign @{triggerOutputs()?['body/cs_subject']}
      Body:
        <html>
        <body style="font-family: Arial, sans-serif;">
          <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <img src="[Your Company Logo URL]" alt="Company Logo" style="max-width: 200px;">
            <h2>Document Signature Required</h2>
            <p>Hello,</p>
            <p>@{triggerOutputs()?['body/cs_message']}</p>
            <p>
              <a href="@{items('For_Each_Signer')?['SigningLink']}" 
                 style="background-color: #0078D4; color: white; padding: 12px 24px; 
                        text-decoration: none; border-radius: 4px; display: inline-block;">
                Click Here to Sign
              </a>
            </p>
            <p>If you have any questions, please contact us.</p>
            <p>Thank you,<br>Elections Canada</p>
          </div>
        </body>
        </html>
```

---

## Implementation Notes

### Prerequisites for All Flows

1. **Environment Variables** (create these first):
   - `NintexAPIUsername` (String)
   - `NintexAPIKey` (String - Secure)
   - `NintexContextEmail` (String)

2. **Dataverse Tables** (must exist):
   - cs_envelope
   - cs_signer
   - cs_document
   - cs_field
   - cs_apirequest

3. **Connections** (will be created automatically):
   - Dataverse
   - Office 365 Outlook (for emails)
   - SharePoint (for Flow 2)

### Error Handling

Add to each flow:

```yaml
Configure run after: [Main action]
  Run after: has failed
  
Steps:
  1. Compose Error Message
     Inputs: 
       Error: @{outputs('[Main_Action]')?['error']}
       Details: @{outputs('[Main_Action]')?['body']}
  
  2. Send Email to Admin
     To: admin@company.com
     Subject: Flow Failed: [Flow Name]
     Body: @{outputs('Compose_Error_Message')}
  
  3. Log Error to Dataverse
     Action: Add a new row
     Table: API Requests (cs_apirequest)
     Fields:
       Name: ERROR - [Flow Name]
       Error Message: @{outputs('Compose_Error_Message')}
       Success: false
```

### Testing

1. **Test Flow 1** first with sample envelope
2. Verify envelope created in Nintex
3. Check Dataverse records updated
4. Then enable **Flow 2** for status sync
5. Test **Flow 3** by marking envelope cancelled
6. Finally enable **Flow 4** for custom emails

---

**Ready to import? Create these flows in Power Automate!**
