#!/usr/bin/env node
/*
 * SETUP (one-time, idempotent) — create the "Party Participation Agreement (Sample)"
 * cs_template used by sample-create-branded-envelope.mjs.
 *
 * The template PDF is the SAME layout the sample sends, except the party logo is a
 * dashed PLACEHOLDER box ("PARTY LOGO") and the party name is "[Party name]". When an
 * ad-hoc envelope is created from this template, the sent PDF fills that placeholder
 * with the real, coloured party logo — demonstrating the template→envelope relationship.
 *
 * What it does:
 *   1. Generates the placeholder template PDF (pdf-lib).
 *   2. Find-or-update a cs_template named "Party Participation Agreement (Sample)"
 *      (cs_isactive=true, owner-contact = OWNER_EMAIL, signature field at x≈83/y≈609).
 *   3. Replaces its TemplateSourcePDF annotation with the placeholder PDF.
 *   4. Prints the template id — paste it into sample-create-branded-envelope.mjs DEFAULT_TEMPLATE.
 *
 * Usage:  node create-party-agreement-template.mjs [dev|test] [ownerEmail]
 *   target      dev (default) or test  — which EC e-sign environment to create it in
 *   ownerEmail  owner/creator contact for the template (default: fredrick.pearson@elections.ca)
 *
 * Prereqs: npm install pdf-lib ; .env at repo root with EC_CLIENT_ID/SECRET/TENANT.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';

const ENVS = { dev: 'https://dev-ec-esign-01.crm3.dynamics.com', test: 'https://test-ec-esign-01.crm3.dynamics.com' };
const TARGET = (process.argv[2] || 'dev').toLowerCase();
const DEV_URL = ENVS[TARGET]; if (!DEV_URL) { console.error(`Unknown target '${TARGET}' (use dev|test)`); process.exit(1); }
const ROOT = path.resolve(fileURLToPath(import.meta.url), '../../..');
const OWNER_EMAIL = process.argv[3] || 'fredrick.pearson@elections.ca';
const TPL_NAME = 'Party Participation Agreement (Sample)';

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
  const loc = r.headers.get('OData-EntityId'); if (loc) { const m = loc.match(/\(([0-9a-f-]+)\)/i); if (m) return { id: m[1], data }; }
  return data;
}

// Placeholder template PDF: same layout as the envelope's brandedPdf, logo = dashed box.
async function templatePdf() {
  const doc = await PDFDocument.create();
  const page = doc.addPage([612, 792]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  const grey = rgb(0.55, 0.55, 0.55);
  // logo PLACEHOLDER: dashed square centred where the envelope's coloured circle lands (cx540, cy740, r34)
  const x0 = 506, y0 = 706, x1 = 574, y1 = 774;
  const dash = { thickness: 1, color: grey, dashArray: [4, 3] };
  page.drawLine({ start: { x: x0, y: y0 }, end: { x: x1, y: y0 }, ...dash });
  page.drawLine({ start: { x: x0, y: y1 }, end: { x: x1, y: y1 }, ...dash });
  page.drawLine({ start: { x: x0, y: y0 }, end: { x: x0, y: y1 }, ...dash });
  page.drawLine({ start: { x: x1, y: y0 }, end: { x: x1, y: y1 }, ...dash });
  const logo = 'LOGO';
  page.drawText(logo, { x: 540 - bold.widthOfTextAtSize(logo, 11) / 2, y: 745, size: 11, font: bold, color: grey });
  const ph = 'placeholder';
  page.drawText(ph, { x: 540 - font.widthOfTextAtSize(ph, 7) / 2, y: 712, size: 7, font, color: grey });
  // title + body (matches brandedPdf), party name shown as a placeholder token
  page.drawText('Party Participation Agreement', { x: 56, y: 720, size: 20, font: bold, color: rgb(0.1, 0.15, 0.25) });
  page.drawText('[Party name]', { x: 56, y: 694, size: 13, font, color: grey });
  page.drawText('This agreement is entered into as of the date of last signature.', { x: 56, y: 650, size: 11, font, color: rgb(0.2, 0.2, 0.2) });
  page.drawText('Signature:', { x: 83, y: 188, size: 11, font: bold, color: rgb(0.2, 0.2, 0.2) });
  page.drawLine({ start: { x: 83, y: 150 }, end: { x: 283, y: 150 }, thickness: 1, color: rgb(0.6, 0.6, 0.6) });
  const bytes = await doc.save();
  return Buffer.from(bytes).toString('base64');
}

const TEMPLATE_JSON = JSON.stringify({
  signers: [{ label: 'Primary Signer' }],
  signingOrder: 'sequential',
  fields: [{ id: 1, type: 'signature', label: 'Signature', signerIndex: 0, required: true, page: 1, x: 83.49, y: 608.9, w: 200, h: 50 }],
  nextFieldId: 2,
  pdfFilename: 'party-agreement-template.pdf',
  pageWidth: 612, pageHeight: 792,
});

async function findOrCreateContact(email) {
  const q = await api(`contacts?$select=contactid&$filter=emailaddress1 eq '${email}'&$top=1`);
  if (q.value && q.value.length) return q.value[0].contactid;
  const nm = (email.split('@')[0] || 'Owner').replace(/[._+-]+/g, ' ').trim().split(/\s+/);
  const c = await api(`contacts`, { method: 'POST', body: { firstname: nm[0], lastname: nm.slice(1).join(' ') || nm[0], emailaddress1: email } });
  return c.id || c.contactid;
}

async function main() {
  const ownerId = await findOrCreateContact(OWNER_EMAIL);
  console.log(`Owner contact (${OWNER_EMAIL}): ${ownerId}`);

  // find existing template by name (idempotent)
  const existing = await api(`cs_templates?$select=cs_templateid&$filter=cs_name eq '${TPL_NAME.replace(/'/g, "''")}'&$top=1`);
  const fields = {
    cs_name: TPL_NAME,
    cs_isactive: true,
    cs_description: 'Sample ad-hoc template with a party-logo placeholder; the sent envelope injects the real coloured logo.',
    cs_templatepdf_name: 'party-agreement-template.pdf',
    cs_templatejson: TEMPLATE_JSON,
    'cs_OwnerContact@odata.bind': `/contacts(${ownerId})`,
  };
  let tplId;
  if (existing.value && existing.value.length) {
    tplId = existing.value[0].cs_templateid;
    await api(`cs_templates(${tplId})`, { method: 'PATCH', body: fields });
    console.log(`Updated existing template ${tplId}`);
  } else {
    const t = await api(`cs_templates`, { method: 'POST', headers: { Prefer: 'return=representation' }, body: fields });
    tplId = t.id || t.cs_templateid;
    console.log(`Created template ${tplId}`);
  }

  // replace TemplateSourcePDF annotation
  const old = await api(`annotations?$select=annotationid&$filter=_objectid_value eq ${tplId} and subject eq 'TemplateSourcePDF'`);
  for (const a of (old.value || [])) await api(`annotations(${a.annotationid})`, { method: 'DELETE' });
  const pdfB64 = await templatePdf();
  await api(`annotations`, { method: 'POST', body: {
    subject: 'TemplateSourcePDF', filename: 'party-agreement-template.pdf', mimetype: 'application/pdf',
    documentbody: pdfB64, 'objectid_cs_template@odata.bind': `/cs_templates(${tplId})`,
  }});
  console.log('Attached TemplateSourcePDF (placeholder logo).');
  console.log(`\nDONE (${TARGET}). Template id: ${tplId}`);
  console.log(`  dev  -> this is the sample script's DEFAULT_TEMPLATE.`);
  console.log(`  test -> pass it to the sample on test: node sample-create-branded-envelope.mjs <owner> ${tplId}`);
}
main().catch((e) => { console.error(e.status || '', JSON.stringify(e.data || e.message).slice(0, 500)); process.exit(1); });
