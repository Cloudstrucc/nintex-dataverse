# Nintex Status Webhook Azure Function

This Function App receives Nintex eSign DocumentTRAK webhook events and updates the matching broker `cs_envelope` row in Dataverse.

The webhook is used as a wake-up signal. The function still calls Nintex `GET /envelopes/{id}/status` before writing Dataverse so the broker stores the canonical Nintex status.

## Endpoint

After deployment, the route is:

```text
POST https://<function-app>.azurewebsites.net/api/nintex/status-webhook?code=<function-key>
```

The function also expects a shared-secret header:

```text
x-cs-webhook-secret: <NINTEX_WEBHOOK_SECRET>
```

Use this route for a simple health check:

```text
GET https://<function-app>.azurewebsites.net/api/nintex/status-webhook?code=<function-key>
```

## App Settings

| Setting | Purpose |
|---|---|
| `DATAVERSE_ENVIRONMENT_URL` | Broker Dataverse URL, for example `https://test-ec-esign-01.crm3.dynamics.com` |
| `DATAVERSE_TENANT_ID` | Microsoft Entra tenant ID |
| `DATAVERSE_CLIENT_ID` | App registration/client ID with Dataverse application user |
| `DATAVERSE_CLIENT_SECRET` | App registration secret |
| `NINTEX_AUTH_URL` | Usually `https://account.assuresign.net/api/v3.7` |
| `NINTEX_API_BASE_URL` | Nintex DocumentNOW base URL, for example `https://sb.assuresign.net/api/documentnow/v3.7` |
| `NINTEX_API_USERNAME` | Nintex API user |
| `NINTEX_API_KEY` | Nintex API key |
| `NINTEX_CONTEXT_USERNAME` | Nintex context user |
| `NINTEX_WEBHOOK_SECRET` | Long random shared secret sent by Nintex in the header |

For local development, copy `local.settings.example.json` to `local.settings.json` and fill in values. Do not commit `local.settings.json`.

## Nintex DocumentTRAK Body

Create a Custom Webhook in Nintex eSign and use a JSON body similar to:

```json
{
  "event": "Envelope Completed",
  "envelopeId": "[Envelope ID]",
  "envelopeName": "[Envelope Name]",
  "envelopeStatus": "[Envelope Status]",
  "envelopeCompletionDate": "[Envelope Completion Date]",
  "envelopeCancelledDate": "[Envelope Cancelled Date]",
  "envelopeDeclinedDate": "[Envelope Declined Date]"
}
```

Assign the webhook to each Simple Setup template for the status events you care about:

- Envelope Started
- Envelope Completed
- Envelope Cancelled
- Envelope Declined
- Envelope Expired
- Envelope Signer Authentication Failed

## Dataverse Update

The function finds the broker row with:

```text
cs_envelope.cs_preparedenvelopeid == envelopeId
```

Then it patches:

| Nintex status | Dataverse state/status |
|---|---|
| `completed`, `ECO` | `statecode=1`, `statuscode=5` |
| `cancelled`, `ECA` | `statecode=1`, `statuscode=8` |
| `declined`, `ESD` | `statecode=1`, `statuscode=10` |
| `expired`, `EEX` | `statecode=1`, `statuscode=11` |
| `staled` | `statecode=1`, `statuscode=717640008` |
| `Signer Authentication Failed`, `SAF` | `statecode=1`, `statuscode=717640009` |
| anything else | `statecode=0`, `statuscode=717640003` |

It always sets `cs_statuslastcheckedon` to the webhook processing time. It sets `cs_completeddate` and `cs_cancelleddate` only when the matching terminal status occurs and the Dataverse field is currently empty.

## Validate Without Updating

During Nintex setup you can test parsing without calling Nintex or Dataverse:

```text
POST https://<function-app>.azurewebsites.net/api/nintex/status-webhook?code=<function-key>&validateOnly=true
```

`validateOnly=true` returns the parsed envelope ID and status from the payload only.

## Local Commands

```bash
npm install
npm test
npm start
```
