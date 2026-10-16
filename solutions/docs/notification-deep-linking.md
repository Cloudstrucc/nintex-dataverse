# Notification deep linking

## What changed

Notifications could not point at the record they described. `cs_portalmessage` only carried
`cs_service` — a free-text label like `Envelopes` — so the notification centre's **View** could
offer, at best, "go to the Envelopes list". Two lookup columns now carry the actual record.

### Schema (solution: `ESignaturePortal`, publisher prefix `cs`)

| Column (schema name) | Logical name | Type | Target | Relationship |
|---|---|---|---|---|
| `cs_EnvelopeLink` | `cs_envelopelink` | Lookup | `cs_envelope` | `cs_cs_envelope_cs_portalmessage` |
| `cs_TemplateLink` | `cs_templatelink` | Lookup | `cs_template` | `cs_cs_template_cs_portalmessage` |

Both are **optional**, and the delete behaviour is **RemoveLink** — deleting an envelope or template
clears the link on its notifications rather than cascading a delete. Nothing else on the table changed.

## How the link is resolved

`CS-Notifications` picks the first match, most specific first:

| Condition | Link | Label |
|---|---|---|
| `cs_EnvelopeLink` set | `/envelopes/details/?id=<envelope id>` | Open this envelope |
| `cs_TemplateLink` set | `/edit-template/?id=<template id>` | Open this template |
| neither, `cs_service` matches a known service | that service's list page | Go to &lt;service&gt; |
| neither and no match | *(no button)* | — |

So **existing notifications keep working**. Every message created before this change has both
lookups empty and simply falls back to the service list, exactly as before. There is no backfill
and no migration.

## Populating the lookups

The portal only *reads* these. Whatever creates the notification sets them — in the broker flows
that is an extra line on the Dataverse "Create a new row" action:

```
item/cs_EnvelopeLink@odata.bind   =  /cs_envelopes(@{triggerOutputs()?['body/cs_envelopeid']})
item/cs_TemplateLink@odata.bind   =  /cs_templates(@{...template id...})
```

Set **one** of them — the one matching the notification's subject. Leave both unset for general
messages ("Welcome to the Electronic Signature Service") and the service fallback applies.

Nothing has been wired into the broker flows yet: this change delivers the capability and the UI.
Deciding which notifications deep-link where is a content decision, not a technical one.

## Deploying to another environment

1. **Carry the schema.** Both columns and relationships live in `ESignaturePortal`, so export and
   import that solution. They are ordinary optional lookups — no data migration, and the import is
   additive.
2. **Whitelist the columns for the portal Web API.** The site setting
   `Webapi/cs_portalmessage/fields` must list the read values, and the navigation properties too if
   anything will write them through the portal:

   ```
   _cs_envelopelink_value, _cs_templatelink_value, cs_EnvelopeLink, cs_TemplateLink
   ```

   Wildcards are not an option — Microsoft removed `*` for `fields` on 2026-09-14.
3. **Deploy the web template.** `CS-Notifications` via `deploy-portal-theme.mjs <env> pages`.
4. **Restart the site** (admin centre → Site Actions → Restart).

### Step 4 is not optional, and here is why

The portal caches its Dataverse EDM metadata independently of Dataverse itself. After the columns
existed and were published, the portal still answered:

```
400  Could not find a property named '_cs_templatelink_value' on type '...cs_portalmessage'
```

while happily resolving `_cs_envelopelink_value` — it had refreshed for one column and not the
other. A `PublishAllXml` did not clear it.

Because a failed `$select` fails the **whole** query, that briefly took out the entire notification
centre: the list rendered "Unable to load notifications". The page now defends against this — it
requests both lookups, and on failure retries with only the envelope lookup, then with neither:

```
',_cs_envelopelink_value,_cs_templatelink_value'  ->  ',_cs_envelopelink_value'  ->  ''
```

So the worst case during a metadata lag is that deep links are temporarily unavailable while the
rest of the page works normally, and they light up on their own once the cache catches up. Restart
the site after importing to skip that window entirely.

## Release-note wording

> **Notification deep linking.** Notifications can now link directly to the envelope or template
> they refer to. Selecting **View** on a notification opens the full message and, where the
> notification relates to a specific record, offers a direct link to it. Notifications that do not
> reference a specific record continue to link to the relevant service area.

## Verified in dev (2026-10-16)

A notification linked to envelope `32c57631-54c9-f111-a05c-000d3af46724` rendered
**"Open this envelope" → `/envelopes/details/?id=32c57631-54c9-f111-a05c-000d3af46724`**.

Note: that link was set by hand to prove the mechanism and points a sample notification at an
unrelated test envelope. Clear it with `cs_EnvelopeLink = null` on message
`268292c7-67bc-f111-aaae-000d3af4232b` when the demo data is no longer wanted.
