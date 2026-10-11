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
 * Usage:  node sample-create-branded-envelope.mjs [templateId] [your@email]
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';

const DEV_URL = 'https://dev-ec-esign-01.crm3.dynamics.com';
const ROOT = path.resolve(fileURLToPath(import.meta.url), '../../..');

// ---- config ----
const TEMPLATE_ID = process.argv[2] || '83551a34-8cc3-f111-aaaf-000d3af4232b'; // "Test 2 personal" (1 signer, 1 signature)
const TEST_EMAIL  = process.argv[3] || 'fpearson613@gmail.com';
const PARTIES = [
  { name: 'Green Future Party',  color: [0.11, 0.50, 0.20] },
  { name: 'Blue Horizon Party',  color: [0.10, 0.33, 0.66] },
  { name: 'Amber Coalition',     color: [0.80, 0.52, 0.05] },
  { name: 'Crimson Alliance',    color: [0.66, 0.12, 0.20] },
];

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
  const party = PARTIES[Math.floor(Math.random() * PARTIES.length)];
  console.log(`Party this run: ${party.name}`);

  // 1. read the layout template (signers + name)
  const tpl = await api(`cs_templates(${TEMPLATE_ID})?$select=cs_name,cs_templatejson`);
  const tj = JSON.parse(tpl.cs_templatejson || '{}');
  const signers = (tj.signers && tj.signers.length) ? tj.signers : [{ label: 'Primary Signer' }];
  const recipients = signers.map((s, i) => ({ role: s.label, name: `Test Signer ${i + 1}`, email: TEST_EMAIL }));
  console.log(`Template: ${tpl.cs_name} · signers: ${signers.map((s) => s.label).join(', ')}`);

  // 2. create the envelope (references the template for layout; recipients in cs_envelopejson)
  const envName = `${party.name} — ad-hoc ${new Date().toISOString().slice(11, 19)}`;
  const env = await api(`cs_envelopes`, { method: 'POST', headers: { Prefer: 'return=representation' }, body: {
    cs_name: envName, cs_subject: envName,
    cs_templateid: TEMPLATE_ID,
    cs_envelopejson: JSON.stringify({ templateId: TEMPLATE_ID, templateName: tpl.cs_name, recipients }),
    statuscode: 1, // Draft
  }});
  const envId = env.id || env.cs_envelopeid;
  console.log(`Created envelope ${envId}`);

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
  console.log(`\nWatch: portal /envelopes/details/?id=${envId} , and check ${TEST_EMAIL} for the signing email with the ${party.name} logo.`);
}
main().catch((e) => { console.error(e.status || '', JSON.stringify(e.data || e.message).slice(0, 400)); process.exit(1); });
