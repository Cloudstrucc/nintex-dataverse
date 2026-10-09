# User Story — Capture signer "decline reason / feedback" from Nintex eSign

> Copy into Azure DevOps. Area: E‑Signature Broker. Tags: broker, nintex-esign, dataverse.

## Title
Capture and expose the signer's decline reason/feedback when an envelope is declined

## User story
**As a** client application consuming the e‑Signature broker,
**I want** the signer's decline reason and comments to be stored on the broker's envelope record,
**so that** I can surface *why* a signer declined in my own CRM without calling the Nintex/AssureSign API directly.

## Background / findings
When a signer clicks **Decline signing** in Nintex eSign (AssureSign) and types feedback, AssureSign returns it in the **envelope status** response (DocumentNOW v3.7), per document:
```
GET {apiBaseUrl}/envelopes/{preparedEnvelopeId}/status
→ result.documentList[].status.statusType   = "declined"
  result.documentList[].status.statusDetails = "Declined by: '<name>' (<email>), Comments: '<signer feedback>'"
```
No dedicated `declineReason` field exists on the signatory object — the feedback is embedded in `statusDetails`. The broker already calls this endpoint (status‑sync and single‑envelope status check), so no new integration is required — only field mapping.

## Scope
In scope: broker schema + the two broker status flows + a client reference flow. Out of scope: client CRM tables (client‑specific), UI changes, history‑endpoint ingestion.

## Acceptance criteria
1. **Given** an envelope is declined in Nintex, **when** the broker runs a status check (recurrence or on‑demand), **then** the envelope's `statuscode` is set to **Declined (10)** and:
   - `cs_envelope.cs_declinereason` contains the full AssureSign `statusDetails` string, and
   - `cs_envelope.cs_declinecomments` contains **only** the signer's typed comment (parsed).
2. **Given** an envelope reaches any non‑declined terminal/active state, **then** `cs_declinereason` / `cs_declinecomments` are left null (not populated for non‑declines).
3. Both the **recurrence** poller (`ESign - Status Sync`) and the **on‑demand** single‑envelope flow (`ESign - Check Envelope Status`, triggered by `cs_statuscheckrequestedon`) exhibit the behaviour.
4. A **client reference flow** demonstrates reading the field(s) from the broker over the cross‑environment connection and recording them in a target record (memo), plus setting a status.
5. Changes are captured in the `ESignatureBroker` / `ESignatureClient` solutions for ALM.

## Implementation details

### Broker (`ESignatureBroker`)
- **Schema:** add two memo columns to `cs_envelope`:
  - `cs_declinereason` (memo, 2000) — raw `statusDetails`.
  - `cs_declinecomments` (memo, 2000) — parsed signer comment only.
- **Flows — `ESign - Check Envelope Status` and `ESign - Status Sync`:** in the `Update_Envelope_Status` (Dataverse UpdateRecord) action — the branch that runs when the normalised status is not completed/cancelled — add two parameters, gated on the declined status:
  - `item/cs_declinereason`:
    ```
    @{if(equals(outputs('Normalize_Nintex_Status'),'declined'),
        coalesce(first(body('HTTP_Get_Envelope_Status')?['result']?['documentList'])?['status']?['statusDetails'], ''),
        null)}
    ```
  - `item/cs_declinecomments` (parse the text after `Comments:` and strip quotes):
    ```
    @{if(and(equals(outputs('Normalize_Nintex_Status'),'declined'),
            contains(coalesce(first(body('HTTP_Get_Envelope_Status')?['result']?['documentList'])?['status']?['statusDetails'],''),'Comments:')),
        trim(replace(last(split(coalesce(first(body('HTTP_Get_Envelope_Status')?['result']?['documentList'])?['status']?['statusDetails'],''),'Comments:')),'''','')),
        null)}
    ```
  (`Normalize_Nintex_Status` already exists: `toLower(result.status)`. Envelope `statuscode` 10 = Declined already exists.)

### Client (`ESignatureClient`) — reference example
- **Flow `SAMPLE - Verify & Update Envelope Status`:** after the broker status check completes and `Get_Envelope_Final` reads the envelope, the `Create Status Update Note` action writes the **raw reason** and the **clean comment** into the note's `notetext` (memo):
  ```
  concat('Updated status from ', oldLabel, ' to ', newLabel, ' on ', timestamp,
         if(empty(cs_declinereason), '',
            concat('\n\nSigner comment: ', cs_declinecomments, '\nDecline reason (raw): ', cs_declinereason)))
  ```
- A real client swaps the note for an **update to their own CRM table**: map `cs_declinecomments` → their "decline reason" column and set their own Declined/Rejected status. (`cs_declinereason` is available too if they want the full audit string.)

## Technical notes
- **Deployment of flow edits:** done in dev by updating each flow's `clientdata` (deactivate → patch → reactivate). Note a Dataverse‑connector **metadata‑cache lag**: a brand‑new column may be rejected by flow save (`WorkflowOperationParametersExtraParameter`) until the connector schema refreshes — retry after a few minutes.
- The feedback text is in the **status** call, not the history call. (The separate `ESign - Get Envelope History` flow is unrelated to this story and has its own schema‑mismatch issue — out of scope here.)

## Verification (done in dev)
- Declined the CCCS sandbox envelope with feedback "my feedback".
- Triggered `ESign - Check Envelope Status`; result:
  - `statuscode` = Declined (10)
  - `cs_declinereason` = `Declined by: 'fpearson' (fpearson613@gmail.com), Comments: 'my feedback'`
  - `cs_declinecomments` = `my feedback`
- Confirmed the parse (`split`/`replace`/`trim`) yields the comment only.

## Tasks
1. Add `cs_declinereason`, `cs_declinecomments` to `cs_envelope` (ESignatureBroker). 
2. Update `ESign - Check Envelope Status` + `ESign - Status Sync` update actions. 
3. Update client `SAMPLE - Verify & Update Envelope Status`. 
4. Export/version both solutions. 
5. Promote dev → test → prod per ALM.
