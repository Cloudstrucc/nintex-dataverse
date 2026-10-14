#!/usr/bin/env node
/*
 * SAMPLE — Create a branded (ad-hoc) envelope to exercise the logo-injection path.
 *
 * What it does (per run):
 *   1. Generates a one-page "agreement" PDF with a DYNAMIC party logo top-right
 *      (random party + colour each run) using pdf-lib — this stands in for the
 *      client's own "merge the party logo into the PDF" step.
 *   2. Creates a cs_envelope that references a layout template (for the field
 *      positions + signer roles), with recipients = the template's signers all
 *      pointed at TEST_EMAIL so you receive the signing email.
 *   3. Attaches the branded PDF as an annotation (subject 'EnvelopeSourcePDF').
 *   4. Sets cs_adhocsend = true, which fires the "ESign - Send Ad-hoc Envelope"
 *      broker flow → ad-hoc /submit → signing email with the party logo.
 *
 * Prereqs:
 *   - npm install pdf-lib         (in this folder, or adjust the import)
 *   - .env at repo root with EC_CLIENT_ID / EC_CLIENT_SECRET / EC_TENANT_ID
 *   - The "ESign - Send Ad-hoc Envelope" flow must be turned ON (see runbook).
 *
 * Usage:  node sample-create-branded-envelope.mjs [ownerEmail] [templateId] [recipient(s)]
 *
 *   arg2  ownerEmail   OWNER / CREATOR of the envelope. Its contact (found or
 *                      created) is set as cs_OwnerContact, so when this person
 *                      signs into the portal they see it under "My envelopes"
 *                      via the EXISTING owner-contact table permission (no portal
 *                      changes). It is ALSO the default recipient (see arg4), so
 *                      the signing email goes to this same person unless you
 *                      override recipients. Omit (run with no args) to fall back
 *                      to the built-in sample, email-only (not shown in portal).
 *   arg3  templateId   OPTIONAL layout template for field positions + signer
 *                      roles (default: the built-in "Test 2 personal" template).
 *   arg4  recipient(s) OPTIONAL. ONE email, or a COMMA-SEPARATED list for
 *                      multi-recipient. Defaults to the ownerEmail (arg2). Each
 *                      becomes a signer (role from the template's labels, by
 *                      index) and a cs_signer row on the envelope.
 *
 * Examples:
 *   node sample-create-branded-envelope.mjs                         # all defaults; email only
 *   node sample-create-branded-envelope.mjs me@x.com                # owner=recipient=me; shows in portal + emails me
 *   node sample-create-branded-envelope.mjs me@x.com <tpl>          # + specific template
 *   node sample-create-branded-envelope.mjs me@x.com <tpl> a@x.com,b@x.com   # + explicit multi-recipient
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';

const DEV_URL = 'https://dev-ec-esign-01.crm3.dynamics.com';
const ROOT = path.resolve(fileURLToPath(import.meta.url), '../../..');

// ---- config ----
// arg order: [ownerEmail] [templateId] [recipient(s)]
const OWNER_EMAIL = process.argv[2] || null; // owner/creator (shown in portal) AND default recipient
const TEMPLATE_ID = process.argv[3] || '66de5bcb-c4c7-f111-a05c-002248d57f8c'; // default: "Party Participation Agreement (Sample)" (logo placeholder)
const RECIPIENTS  = (process.argv[4] ? process.argv[4].split(',') : (OWNER_EMAIL ? [OWNER_EMAIL] : ['fpearson613@gmail.com']))
  .map((s) => s.trim()).filter(Boolean); // default recipient = owner (or the built-in test address when no owner)
const PARTY_NAME  = 'Sample Party';

// Derive a friendly display name from an email local-part (jane.doe -> "Jane Doe").
function nameFromEmail(email) {
  const local = (email.split('@')[0] || 'Signer').replace(/[._+-]+/g, ' ').trim();
  return local.split(/\s+/).map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' ') || 'Signer';
}

// Find a contact by email, or create a minimal one. Returns contactid.
async function findOrCreateContact(email) {
  const q = await api(`contacts?$select=contactid,fullname&$filter=emailaddress1 eq '${email}'&$top=1`);
  if (q.value && q.value.length) { console.log(`  owner contact: found ${q.value[0].fullname || email} (${q.value[0].contactid})`); return q.value[0].contactid; }
  const nm = nameFromEmail(email).split(' ');
  const created = await api(`contacts`, { method: 'POST', body: { firstname: nm[0], lastname: nm.slice(1).join(' ') || nm[0], emailaddress1: email } });
  const id = created.id || created.contactid;
  console.log(`  owner contact: created ${email} (${id})`);
  return id;
}

// Simple routine: pick a random, readable logo colour each run (random hue, fixed
// saturation/lightness so white initials stay legible). Returns pdf-lib [r,g,b] 0-1.
function randomColor() {
  const h = Math.random() * 360, s = 0.62, l = 0.42; // vivid but dark enough for white text
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - c / 2;
  const [r1, g1, b1] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x]
    : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [r1 + m, g1 + m, b1 + m];
}

// ---- env + dataverse helpers ----
function loadEnv() {
  const t = fs.readFileSync(path.join(ROOT, '.env'), 'utf8'); const e = {};
  for (const line of t.split('\n')) { const m = line.match(/^([A-Z_]+)=(.*)$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, '').trim(); }
  return e;
}
const E = loadEnv(); let _tok = null;
async function tok() {
  if (_tok) return _tok;
  const body = new URLSearchParams({ grant_type: 'client_credentials', client_id: E.EC_CLIENT_ID, client_secret: E.EC_CLIENT_SECRET, scope: `${DEV_URL}/.default` });
  const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  const j = await r.json(); if (!j.access_token) throw new Error('token ' + JSON.stringify(j)); _tok = j.access_token; return _tok;
}
async function api(pathStr, { method = 'GET', body, headers = {} } = {}) {
  const t = await tok(); const url = `${DEV_URL}/api/data/v9.2/${pathStr}`;
  const h = { Authorization: `Bearer ${t}`, 'OData-MaxVersion': '4.0', 'OData-Version': '4.0', Accept: 'application/json', ...headers };
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const r = await fetch(url, { method, headers: h, body: body !== undefined ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined });
  const txt = await r.text(); let data = null; try { data = txt ? JSON.parse(txt) : null; } catch { data = txt; }
  if (!r.ok) { const e = new Error(`${method} ${url} -> ${r.status}`); e.status = r.status; e.data = data; throw e; }
  // capture created id from OData-EntityId header
  const loc = r.headers.get('OData-EntityId'); if (loc) { const m = loc.match(/\(([0-9a-f-]+)\)/i); if (m) return { id: m[1], data }; }
  return data;
}

// ---- branded PDF (logo top-right + signature line at the template's field spot) ----
async function brandedPdf(party, color) {
  const doc = await PDFDocument.create();
  const page = doc.addPage([612, 792]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const [r, g, b] = color;
  page.drawCircle({ x: 540, y: 740, size: 34, color: rgb(r, g, b) });
  const initials = party.split(/\s+/).map((w) => w[0]).join('').slice(0, 3).toUpperCase();
  page.drawText(initials, { x: 540 - bold.widthOfTextAtSize(initials, 16) / 2, y: 734, size: 16, font: bold, color: rgb(1, 1, 1) });
  page.drawText('Party Participation Agreement', { x: 56, y: 720, size: 20, font: bold, color: rgb(0.1, 0.15, 0.25) });
  page.drawText(party, { x: 56, y: 694, size: 13, font, color: rgb(r, g, b) });
  page.drawText('This agreement is entered into as of the date of last signature.', { x: 56, y: 650, size: 11, font, color: rgb(0.2, 0.2, 0.2) });
  // signature line roughly under the template's signature field (x~83, top-origin y~609 -> pdf-lib y ~133..183)
  page.drawText('Signature:', { x: 83, y: 188, size: 11, font: bold, color: rgb(0.2, 0.2, 0.2) });
  page.drawLine({ start: { x: 83, y: 150 }, end: { x: 283, y: 150 }, thickness: 1, color: rgb(0.6, 0.6, 0.6) });
  const bytes = await doc.save();
  return Buffer.from(bytes).toString('base64');
}

async function main() {
  const color = randomColor();
  const party = { name: PARTY_NAME, color };
  console.log(`Logo colour this run: rgb(${color.map((v) => Math.round(v * 255)).join(', ')})`);

  // 1. read the layout template (signers + name)
  const tpl = await api(`cs_templates(${TEMPLATE_ID})?$select=cs_name,cs_templatejson`);
  const tj = JSON.parse(tpl.cs_templatejson || '{}');
  const signers = (tj.signers && tj.signers.length) ? tj.signers : [{ label: 'Primary Signer' }];
  // Map each provided recipient onto a template signer role by index (fallback "Signer N").
  const recipients = RECIPIENTS.map((email, i) => ({ role: (signers[i] && signers[i].label) || `Signer ${i + 1}`, name: nameFromEmail(email), email }));
  console.log(`Template: ${tpl.cs_name} · template roles: ${signers.map((s) => s.label).join(', ')}`);
  console.log(`Recipients (${recipients.length}): ${recipients.map((r) => `${r.email} [${r.role}]`).join(', ')}`);

  // 1b. optional owner-contact (so the envelope shows in the portal for that user)
  let ownerContactId = null;
  if (OWNER_EMAIL) { console.log(`Owner requested: ${OWNER_EMAIL}`); ownerContactId = await findOrCreateContact(OWNER_EMAIL); }

  // 2. create the envelope (references the template for layout; recipients in cs_envelopejson)
  const envName = `${party.name} — ad-hoc ${new Date().toISOString().slice(11, 19)}`;
  const envBody = {
    cs_name: envName, cs_subject: envName,
    cs_templateid: TEMPLATE_ID,
    cs_envelopejson: JSON.stringify({ templateId: TEMPLATE_ID, templateName: tpl.cs_name, recipients }),
    statuscode: 1, // Draft
  };
  if (ownerContactId) envBody['cs_OwnerContact@odata.bind'] = `/contacts(${ownerContactId})`;
  const env = await api(`cs_envelopes`, { method: 'POST', headers: { Prefer: 'return=representation' }, body: envBody });
  const envId = env.id || env.cs_envelopeid;
  console.log(`Created envelope ${envId}${ownerContactId ? ' (owner-contact set)' : ''}`);

  // 2b. create a cs_signer row per recipient (the ad-hoc flow does NOT create these;
  //     they back the portal's per-recipient visibility and the signing-link storage)
  for (let i = 0; i < recipients.length; i++) {
    const r = recipients[i];
    await api(`cs_signers`, { method: 'POST', body: {
      cs_fullname: r.name, cs_email: r.email, cs_signerorder: i + 1,
      cs_language: 'en-US', cs_signerstatus: 'Pending', // cs_signerstatus is a free-text string (Nintex status)
      'cs_EnvelopeLookup@odata.bind': `/cs_envelopes(${envId})`,
    }});
  }
  console.log(`Created ${recipients.length} cs_signer row(s)`);

  // 3. attach the branded PDF as EnvelopeSourcePDF annotation
  const pdfB64 = await brandedPdf(party.name, party.color);
  await api(`annotations`, { method: 'POST', body: {
    subject: 'EnvelopeSourcePDF',
    filename: 'party-agreement.pdf',
    mimetype: 'application/pdf',
    documentbody: pdfB64,
    'objectid_cs_envelope@odata.bind': `/cs_envelopes(${envId})`,
  }});
  console.log('Attached branded PDF (EnvelopeSourcePDF)');

  // 4. flip cs_adhocsend = true -> fires ESign - Send Ad-hoc Envelope
  await api(`cs_envelopes(${envId})`, { method: 'PATCH', body: { cs_adhocsend: true } });
  console.log('Set cs_adhocsend = true — the broker flow will now submit ad-hoc.');
  console.log(`\nWatch: portal /envelopes/details/?id=${envId} , and check ${recipients.map((r) => r.email).join(', ')} for the signing email — the logo is a random colour each run.`);
  if (ownerContactId) console.log(`Portal: signed in as ${OWNER_EMAIL}, this envelope appears under "My envelopes" (owner-contact scope).`);
  else console.log('Portal: no owner set — this envelope is email-only (not shown in the portal list). Pass an ownerEmail as the FIRST argument to assign it.');
}
main().catch((e) => { console.error(e.status || '', JSON.stringify(e.data || e.message).slice(0, 400)); process.exit(1); });
