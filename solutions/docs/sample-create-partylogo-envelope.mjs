#!/usr/bin/env node
/*
 * SAMPLE — ad-hoc branded envelope that uses a REAL political-party logo.
 *
 * Same as sample-create-branded-envelope.mjs, except instead of a generated
 * random-colour logo it pulls the actual party logo (pfa_logo Image column)
 * from the PERS app in dev-ppep-fp-01 and embeds it into the party-agreement PDF.
 * The envelope itself is still created on dev-ec-esign-01 using the SAME
 * "Party Participation Agreement (Sample)" template and the SAME ad-hoc path —
 * nothing in the broker flow changes.
 *
 * Two environments (same service principal, one token each):
 *   - dev-ppep-fp-01       : read pfa_politicalparty.pfa_name + download pfa_logo
 *   - dev-ec-esign-01      : create the cs_envelope (owner-contact, signer, PDF, ad-hoc send)
 *
 * Usage:  node sample-create-partylogo-envelope.mjs [ownerEmail] [politicalPartyId]
 *   arg2  ownerEmail         owner/creator AND recipient (default fredrick.pearson@elections.ca)
 *   arg3  politicalPartyId   pfa_politicalparty id in dev-ppep-fp-01
 *                            (default: Bloc Quebecois 0764a1dd-f1ef-f011-8406-7ced8d0510ea)
 *
 * Prereqs: npm install pdf-lib ; .env with EC_CLIENT_ID/SECRET/TENANT ;
 *          the "ESign - Send Ad-hoc Envelope" flow ON in dev-ec-esign-01.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { PDFDocument, rgb, StandardFonts } from 'pdf-lib';

const FP01  = 'https://dev-ppep-fp-01.crm3.dynamics.com';   // party-logo source
const ESIGN = 'https://dev-ec-esign-01.crm3.dynamics.com';  // envelope/broker target
const TEMPLATE_ID = '66de5bcb-c4c7-f111-a05c-002248d57f8c'; // Party Participation Agreement (Sample) in dev
const ROOT = path.resolve(fileURLToPath(import.meta.url), '../../..');

const OWNER_EMAIL = process.argv[2] || 'fredrick.pearson@elections.ca';
const PARTY_ID    = process.argv[3] || '0764a1dd-f1ef-f011-8406-7ced8d0510ea'; // Bloc Quebecois

function loadEnv() {
  const t = fs.readFileSync(path.join(ROOT, '.env'), 'utf8'); const e = {};
  for (const line of t.split('\n')) { const m = line.match(/^([A-Z_]+)=(.*)$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, '').trim(); }
  return e;
}
const E = loadEnv();
const _toks = {};
async function tok(resource) {
  if (_toks[resource]) return _toks[resource];
  const body = new URLSearchParams({ grant_type: 'client_credentials', client_id: E.EC_CLIENT_ID, client_secret: E.EC_CLIENT_SECRET, scope: `${resource}/.default` });
  const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
  const j = await r.json(); if (!j.access_token) throw new Error('token ' + JSON.stringify(j)); _toks[resource] = j.access_token; return _toks[resource];
}
async function api(resource, pathStr, { method = 'GET', body, headers = {} } = {}) {
  const t = await tok(resource); const url = `${resource}/api/data/v9.2/${pathStr}`;
  const h = { Authorization: `Bearer ${t}`, 'OData-MaxVersion': '4.0', 'OData-Version': '4.0', Accept: 'application/json', ...headers };
  if (body !== undefined) h['Content-Type'] = 'application/json';
  const r = await fetch(url, { method, headers: h, body: body !== undefined ? (typeof body === 'string' ? body : JSON.stringify(body)) : undefined });
  const txt = await r.text(); let data = null; try { data = txt ? JSON.parse(txt) : null; } catch { data = txt; }
  if (!r.ok) { const e = new Error(`${method} ${url} -> ${r.status}`); e.status = r.status; e.data = data; throw e; }
  const loc = r.headers.get('OData-EntityId'); if (loc) { const m = loc.match(/\(([0-9a-f-]+)\)/i); if (m) return { id: m[1], data }; }
  return data;
}

function randomColor() {
  const h = Math.random() * 360, s = 0.62, l = 0.42;
  const c = (1 - Math.abs(2 * l - 1)) * s, x = c * (1 - Math.abs(((h / 60) % 2) - 1)), m = l - c / 2;
  const [r1, g1, b1] = h < 60 ? [c, x, 0] : h < 120 ? [x, c, 0] : h < 180 ? [0, c, x] : h < 240 ? [0, x, c] : h < 300 ? [x, 0, c] : [c, 0, x];
  return [r1 + m, g1 + m, b1 + m];
}

// Fetch the party name + full-size logo bytes from dev-ppep-fp-01.
async function getParty(partyId) {
  const rec = await api(FP01, `pfa_politicalparties(${partyId})?$select=pfa_name,pfa_logoformat,pfa_logoid`);
  let logo = null;
  if (rec.pfa_logoid) {
    const t = await tok(FP01);
    const r = await fetch(`${FP01}/api/data/v9.2/pfa_politicalparties(${partyId})/pfa_logo/$value?size=full`, { headers: { Authorization: `Bearer ${t}` } });
    if (r.ok) { const buf = Buffer.from(await r.arrayBuffer()); if (buf.length) logo = buf; }
  }
  return { name: rec.pfa_name || 'Political Party', logo };
}

// sniff PNG vs JPG from magic bytes
function isPng(buf) { return buf.length > 8 && buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47; }

// Party-agreement PDF with the REAL party logo (or a generated circle if none).
async function brandedPdf(partyName, logoBuf) {
  const doc = await PDFDocument.create();
  const page = doc.addPage([612, 792]);
  const font = await doc.embedFont(StandardFonts.Helvetica);
  const bold = await doc.embedFont(StandardFonts.HelveticaBold);
  // logo box: 64x64 area centred at (540, 740) — same spot as the template placeholder
  const CX = 540, CY = 740, BOX = 64;
  if (logoBuf) {
    const img = isPng(logoBuf) ? await doc.embedPng(logoBuf) : await doc.embedJpg(logoBuf);
    const s = Math.min(BOX / img.width, BOX / img.height);
    const dw = img.width * s, dh = img.height * s;
    page.drawImage(img, { x: CX - dw / 2, y: CY - dh / 2, width: dw, height: dh });
  } else {
    const [r, g, b] = randomColor();
    page.drawCircle({ x: CX, y: CY, size: 34, color: rgb(r, g, b) });
    const initials = partyName.split(/\s+/).map((w) => w[0]).join('').slice(0, 3).toUpperCase();
    page.drawText(initials, { x: CX - bold.widthOfTextAtSize(initials, 16) / 2, y: CY - 6, size: 16, font: bold, color: rgb(1, 1, 1) });
  }
  page.drawText('Party Participation Agreement', { x: 56, y: 720, size: 20, font: bold, color: rgb(0.1, 0.15, 0.25) });
  page.drawText(partyName, { x: 56, y: 694, size: 13, font, color: rgb(0.1, 0.15, 0.25) });
  page.drawText('This agreement is entered into as of the date of last signature.', { x: 56, y: 650, size: 11, font, color: rgb(0.2, 0.2, 0.2) });
  page.drawText('Signature:', { x: 83, y: 188, size: 11, font: bold, color: rgb(0.2, 0.2, 0.2) });
  page.drawLine({ start: { x: 83, y: 150 }, end: { x: 283, y: 150 }, thickness: 1, color: rgb(0.6, 0.6, 0.6) });
  const bytes = await doc.save();
  return Buffer.from(bytes).toString('base64');
}

async function findOrCreateContact(email) {
  const q = await api(ESIGN, `contacts?$select=contactid,fullname&$filter=emailaddress1 eq '${email}'&$top=1`);
  if (q.value && q.value.length) { console.log(`  owner contact: found ${q.value[0].fullname || email}`); return q.value[0].contactid; }
  const nm = (email.split('@')[0] || 'Owner').replace(/[._+-]+/g, ' ').trim().split(/\s+/);
  const c = await api(ESIGN, `contacts`, { method: 'POST', body: { firstname: nm[0], lastname: nm.slice(1).join(' ') || nm[0], emailaddress1: email } });
  console.log(`  owner contact: created ${email}`);
  return c.id || c.contactid;
}

async function main() {
  // 1. party name + logo from fp-01
  const party = await getParty(PARTY_ID);
  console.log(`Party: ${party.name} — logo: ${party.logo ? party.logo.length + ' bytes (' + (isPng(party.logo) ? 'PNG' : 'JPG') + ')' : 'NONE (using generated placeholder)'}`);

  // 2. template (for signer roles) on dev-ec-esign-01
  const tpl = await api(ESIGN, `cs_templates(${TEMPLATE_ID})?$select=cs_name,cs_templatejson`);
  const tj = JSON.parse(tpl.cs_templatejson || '{}');
  const signers = (tj.signers && tj.signers.length) ? tj.signers : [{ label: 'Primary Signer' }];
  const recipients = [{ role: (signers[0] && signers[0].label) || 'Primary Signer', name: party.name, email: OWNER_EMAIL }];
  console.log(`Template: ${tpl.cs_name} · recipient: ${OWNER_EMAIL}`);

  // 3. owner-contact
  console.log(`Owner: ${OWNER_EMAIL}`);
  const ownerContactId = await findOrCreateContact(OWNER_EMAIL);

  // 4. create envelope
  const envName = `${party.name} — party logo ${new Date().toISOString().slice(11, 19)}`;
  const env = await api(ESIGN, `cs_envelopes`, { method: 'POST', headers: { Prefer: 'return=representation' }, body: {
    cs_name: envName, cs_subject: envName, cs_templateid: TEMPLATE_ID,
    cs_envelopejson: JSON.stringify({ templateId: TEMPLATE_ID, templateName: tpl.cs_name, recipients, partyId: PARTY_ID }),
    statuscode: 1,
    'cs_OwnerContact@odata.bind': `/contacts(${ownerContactId})`,
  }});
  const envId = env.id || env.cs_envelopeid;
  console.log(`Created envelope ${envId} (owner-contact set)`);

  // 5. signer row
  await api(ESIGN, `cs_signers`, { method: 'POST', body: {
    cs_fullname: party.name, cs_email: OWNER_EMAIL, cs_signerorder: 1, cs_language: 'en-US', cs_signerstatus: 'Pending',
    'cs_EnvelopeLookup@odata.bind': `/cs_envelopes(${envId})`,
  }});
  console.log('Created cs_signer row');

  // 6. attach the PDF (with the real party logo) as EnvelopeSourcePDF
  const pdfB64 = await brandedPdf(party.name, party.logo);
  await api(ESIGN, `annotations`, { method: 'POST', body: {
    subject: 'EnvelopeSourcePDF', filename: 'party-agreement.pdf', mimetype: 'application/pdf',
    documentbody: pdfB64, 'objectid_cs_envelope@odata.bind': `/cs_envelopes(${envId})`,
  }});
  console.log('Attached branded PDF (real party logo)');

  // 7. fire ad-hoc send
  await api(ESIGN, `cs_envelopes(${envId})`, { method: 'PATCH', body: { cs_adhocsend: true } });
  console.log('Set cs_adhocsend = true — the broker flow will now submit ad-hoc.');
  console.log(`\nWatch: portal /envelopes/details/?id=${envId} , and check ${OWNER_EMAIL} for the signing email.`);
  console.log(`Portal: signed in as ${OWNER_EMAIL}, this envelope appears under "My envelopes" with the ${party.name} logo.`);
}
main().catch((e) => { console.error(e.status || '', JSON.stringify(e.data || e.message).slice(0, 500)); process.exit(1); });
