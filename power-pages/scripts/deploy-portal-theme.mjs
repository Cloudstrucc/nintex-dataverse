// EC-ESIGN portal theming deploy helper (enhanced data model, Web API only, idempotent).
// Adapted from the EC CoE provisioning pattern (COE/scripts/provisioning/_lib.mjs).
//
// Usage:  node power-pages/scripts/deploy-portal-theme.mjs <dev|test> <phase>
//   phases: core | header-footer | home | settings | all
//
// Creds come from .env (EC_TENANT_ID / EC_CLIENT_ID / EC_CLIENT_SECRET — valid across EC envs).
// Every mutated component's prior content is written to power-pages/backups/... before change,
// so any change can be surgically reverted by re-applying the *.before.json content.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "..");
const WTDIR = join(ROOT, "power-pages", "theme", "webtemplates");

function loadEnv() {
  const t = readFileSync(join(ROOT, ".env"), "utf8");
  const e = {};
  for (const line of t.split("\n")) {
    if (line.trim().startsWith("#")) continue;
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);
    if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, "");
  }
  return e;
}
const E = loadEnv();

const TARGETS = {
  dev:  { url: "https://dev-ec-esign-01.crm3.dynamics.com",  wsid: "17ed601c-7964-498a-8d9c-a64d08f85583" },
  test: { url: "https://test-ec-esign-01.crm3.dynamics.com", wsid: "17ed601c-7964-498a-8d9c-a64d08f85583" },
};
const ENVNAME = process.argv[2] || "dev";
const PHASE = process.argv[3] || "core";
const TGT = TARGETS[ENVNAME];
if (!TGT) { console.error(`unknown env "${ENVNAME}" (use dev|test)`); process.exit(1); }
const SITE = TGT.wsid;
const bind = { "powerpagesiteid@odata.bind": `/powerpagesites(${SITE})` };
const T = { PUBSTATE: 1, PAGE: 2, FILE: 3, PT: 6, SNIP: 7, WT: 8, SETTING: 9, ROLE: 11, MARKER: 13, PERM: 18 };

let _tok = null, _at = 0;
async function token() {
  if (_tok && Date.now() - _at < 45 * 60 * 1000) return _tok;
  const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: E.EC_CLIENT_ID, scope: `${TGT.url}/.default`, grant_type: "client_credentials", client_secret: E.EC_CLIENT_SECRET }),
  });
  if (!r.ok) throw new Error(`token ${r.status}: ${await r.text()}`);
  _tok = (await r.json()).access_token; _at = Date.now(); return _tok;
}
async function api(method, path, body) {
  const t = await token();
  const url = path.startsWith("http") ? path : `${TGT.url}/api/data/v9.2/${path}`;
  const h = { Authorization: `Bearer ${t}`, Accept: "application/json", "OData-Version": "4.0" };
  if (body !== undefined) h["Content-Type"] = "application/json";
  const r = await fetch(url, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined });
  const txt = await r.text(); let json = null; try { json = txt ? JSON.parse(txt) : null; } catch {}
  return { ok: r.ok, status: r.status, json, text: txt, entityId: r.headers.get("odata-entityid") };
}

const q = (s) => s.replace(/'/g, "''");
async function find(type, name) {
  const r = await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${type} and name eq '${q(name)}'&$select=powerpagecomponentid,name,content`);
  return r.json?.value?.[0] || null;
}

const BK = join(ROOT, "power-pages", "backups", "e-sign-dev", `deploy-${ENVNAME}-${new Date().toISOString().replace(/[:.]/g, "-")}`);
mkdirSync(BK, { recursive: true });
function backup(label, obj) { writeFileSync(join(BK, `${label}.json`), JSON.stringify(obj, null, 2)); }

async function upsertWT(name, file) {
  const path = join(WTDIR, file);
  if (!existsSync(path)) { console.log(`  SKIP ${name} (missing ${file})`); return null; }
  const content = JSON.stringify({ source: readFileSync(path, "utf8") });
  const ex = await find(T.WT, name);
  if (ex) {
    backup(`WT-${name}.before`, ex);
    const r = await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content });
    console.log(`  PATCH WT ${name}: HTTP ${r.status}${r.ok ? "" : " " + r.text.slice(0, 120)}`);
    return ex.powerpagecomponentid;
  }
  const r = await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: T.WT, ...bind, content });
  const id = r.entityId?.match(/\(([^)]+)\)/)?.[1];
  console.log(`  POST  WT ${name}: HTTP ${r.status} id=${id || r.text.slice(0, 120)}`);
  return id;
}

async function appendInclude(name, includeName) {
  const ex = await find(T.WT, name);
  if (!ex) { console.log(`  MISS ${name} (web template not found)`); return; }
  let src = (JSON.parse(ex.content).source) || "";
  if (src.includes(`'${includeName}'`)) { console.log(`  SKIP ${name} (already includes ${includeName})`); return; }
  backup(`WT-${name}.before`, ex);
  src = `${src}\n{% include '${includeName}' %}\n`;
  const r = await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content: JSON.stringify({ source: src }) });
  console.log(`  PATCH ${name} += include '${includeName}': HTTP ${r.status}${r.ok ? "" : " " + r.text.slice(0, 120)}`);
}

// Derive parentpageid + publishingstateid from an existing WORKING web file so a new file
// serves correctly (ec-esign uses the contentdisposition shape; a wrong publishingstateid
// leaves the file unserved / 404).
async function webFileDefaults() {
  const r = await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${T.FILE} and name eq 'logo-invert.png'&$select=content`);
  const c = JSON.parse(r.json.value[0].content);
  return { parentpageid: c.parentpageid, publishingstateid: c.publishingstateid };
}
async function upsertFile(name, binPath) {
  const d = await webFileDefaults();
  const content = JSON.stringify({ contentdisposition: 756150000, excludefromsearch: false, hiddenfromsitemap: false, parentpageid: d.parentpageid, partialurl: name, publishingstateid: d.publishingstateid });
  const ex = await find(T.FILE, name);
  let id;
  if (ex) { backup(`FILE-${name}.before`, ex); await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content }); id = ex.powerpagecomponentid; console.log(`  PATCH FILE ${name}`); }
  else { const r = await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: T.FILE, ...bind, content }); id = r.entityId?.match(/\(([^)]+)\)/)?.[1]; console.log(`  POST  FILE ${name} id=${id}`); }
  const buf = readFileSync(binPath);
  const t = await token();
  const r = await fetch(`${TGT.url}/api/data/v9.2/powerpagecomponents(${id})/filecontent`, { method: "PATCH", headers: { Authorization: `Bearer ${t}`, "Content-Type": "application/octet-stream", "x-ms-file-name": name }, body: buf });
  console.log(`  filecontent ${name}: HTTP ${r.status} (${buf.length} bytes)${r.ok ? "" : " " + (await r.text()).slice(0, 120)}`);
  return id;
}
async function replaceInWT(name, pairs) {
  const ex = await find(T.WT, name);
  if (!ex) { console.log(`  MISS ${name}`); return; }
  let src = JSON.parse(ex.content).source || ""; let n = 0;
  for (const [a, b] of pairs) { const before = src; src = src.split(a).join(b); if (src !== before) n++; }
  if (n === 0) { console.log(`  SKIP ${name} (no matches)`); return; }
  backup(`WT-${name}.replace.before`, ex);
  const r = await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content: JSON.stringify({ source: src }) });
  console.log(`  PATCH ${name} (${n} replacement groups): HTTP ${r.status}`);
}

async function upsertSetting(name, value) {
  const ex = await find(T.SETTING, name);
  const content = JSON.stringify({ value: String(value) });
  if (ex) {
    backup(`SET-${name.replace(/\//g, "_")}.before`, ex);
    const r = await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content });
    console.log(`  PATCH SET ${name} = ${value}: HTTP ${r.status}`);
    return ex.powerpagecomponentid;
  }
  const r = await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: T.SETTING, ...bind, content });
  console.log(`  POST  SET ${name} = ${value}: HTTP ${r.status}`);
  return r.entityId?.match(/\(([^)]+)\)/)?.[1];
}

const LANG = { en: "00f8e6d9-91b2-4429-95e4-87fe6a85084e", fr: "1c59862a-d627-f111-88b5-7ced8da586db" };
async function findSnip(name, langId) {
  const r = await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${T.SNIP} and name eq '${q(name)}' and _powerpagesitelanguageid_value eq ${langId}&$select=powerpagecomponentid,content`);
  return r.json?.value?.[0] || null;
}
async function upsertSnip(name, langId, value) {
  const content = JSON.stringify({ type: 756150000, value });
  const ex = await findSnip(name, langId);
  if (ex) { backup(`SNIP-${name.replace(/\//g, "_")}-${langId.slice(0, 4)}.before`, ex); const r = await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content }); console.log(`  PATCH SNIP ${name} [${langId.slice(0, 4)}]: ${r.status}`); return ex.powerpagecomponentid; }
  const r = await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: T.SNIP, ...bind, "powerpagesitelanguageid@odata.bind": `/powerpagesitelanguages(${langId})`, content });
  console.log(`  POST  SNIP ${name} [${langId.slice(0, 4)}]: ${r.status}${r.ok ? "" : " " + r.text.slice(0, 100)}`);
  return r.entityId?.match(/\(([^)]+)\)/)?.[1];
}
// [name, en, fr] — new anon-landing snippets (created only if missing; existing ones untouched).
const LANDING_SNIPPETS = [
  ["ESIGN/HOWITWORKS/TITLE", "How it works", "Fonctionnement"],
  ["ESIGN/SERVICES/TITLE", "Services", "Services"],
  ["ESIGN/STEP1/TITLE", "Create an envelope", "Créer une enveloppe"],
  ["ESIGN/STEP1/DESC", "Start from an approved Nintex AssureSign template or upload your document.", "Commencez à partir d'un modèle Nintex AssureSign approuvé ou téléversez votre document."],
  ["ESIGN/STEP2/TITLE", "Add signers", "Ajouter des signataires"],
  ["ESIGN/STEP2/DESC", "Set the signing order, authentication, and language for each recipient.", "Définissez l'ordre de signature, l'authentification et la langue de chaque destinataire."],
  ["ESIGN/STEP3/TITLE", "Send for signature", "Envoyer pour signature"],
  ["ESIGN/STEP3/DESC", "Recipients are notified and sign securely from any device.", "Les destinataires sont avisés et signent en toute sécurité depuis n'importe quel appareil."],
  ["ESIGN/STEP4/TITLE", "Track & complete", "Suivre et terminer"],
  ["ESIGN/STEP4/DESC", "Follow signing progress in real time and retrieve the completed, audited documents.", "Suivez la progression en temps réel et récupérez les documents complétés et vérifiés."],
];

// Theme-core web templates (dependency closure of EC-Base-Styles + EC-Scripts-Base).
const CORE = [
  ["EC-Brand-Facelift", "EC-Brand-Facelift.html"],
  ["EC-EntityList-Modern-Styles", "EC-EntityList-Modern-Styles.html"],
  ["EC-Notice-Styles", "EC-Notice-Styles.html"],
  ["EC-Subgrid-Modern-Styles", "EC-Subgrid-Modern-Styles.html"],
  ["EC-Wizard-Modern-Styles", "EC-Wizard-Modern-Styles.html"],
  ["EC-EntityList-Modern-Scripts", "EC-EntityList-Modern-Scripts.html"],
  ["EC-GCWeb-Validation", "EC-GCWeb-Validation.html"],
  ["EC-Notice-Scripts", "EC-Notice-Scripts.html"],
  ["EC-Phone-Region-Labels", "EC-Phone-Region-Labels.html"],
  ["EC-Subgrid-Modern-Scripts", "EC-Subgrid-Modern-Scripts.html"],
  ["EC-Wizard-Tiles-Scripts", "EC-Wizard-Tiles-Scripts.html"],
  ["EC-Workspace-Styles", "EC-Workspace-Styles.html"],
  // aggregators last (they {% include %} the partials above)
  ["EC-Base-Styles", "EC-Base-Styles.html"],
  ["EC-Scripts-Base", "EC-Scripts-Base.html"],
];

async function main() {
  console.log(`# deploy-portal-theme  target=${ENVNAME} (${TGT.url})  phase=${PHASE}`);
  console.log(`# backups -> ${BK}`);
  if (PHASE === "core" || PHASE === "all") {
    console.log("--- Phase 1: theme-core web templates ---");
    for (const [n, f] of CORE) await upsertWT(n, f);
    await appendInclude("EC-Base-Styles", "EC-Workspace-Styles"); // load workspace CSS site-wide
  }
  if (PHASE === "header-footer" || PHASE === "all") {
    console.log("--- Phase 2: load theme via bound header/footer ---");
    await appendInclude("CS-header", "EC-Base-Styles");   // -> EC-Brand-Facelift + modern styles (all CSS)
    await appendInclude("CS-footer", "EC-Scripts-Base");  // -> all EC JS enhancements
  }
  if (PHASE === "logo" || PHASE === "all") {
    console.log("--- Phase 3a: header logo (from coe-dev-fp) ---");
    await upsertFile("ec-logo.png", join(ROOT, "power-pages", "theme", "assets", "ec-logo.png"));
    await replaceInWT("CS-header", [["/logo-bw-contrast.png", "/ec-logo.png"], ["/logo-invert.png", "/ec-logo.png"]]);
  }
  if (PHASE === "landing" || PHASE === "all") {
    console.log("--- Phase 4: anonymous landing (COE design, e-sign content) ---");
    await upsertWT("CS-Home-WET", "CS-Home-WET.html");
  }
  if (PHASE === "snippets" || PHASE === "all") {
    console.log("--- Phase 4b: anon-landing content snippets (EN/FR, editable) ---");
    for (const [n, en, fr] of LANDING_SNIPPETS) { await upsertSnip(n, LANG.en, en); await upsertSnip(n, LANG.fr, fr); }
  }
  if (PHASE === "classfix" || PHASE === "all") {
    // ec-esign was forked from the COE lineage with a `pepp-` typo; the theme styles the
    // `ppep-` prefix (.ppep-app 29 rules, .ppep-anon-header 15, .ppep-anon 10). Fixing the
    // typo makes every app page adopt the COE container/anon styling. Safe class-name change.
    console.log("--- Phase 4/5: align pepp- -> ppep- (landing + app pages inherit theme) ---");
    for (const n of ["CS-header", "CS-Home-WET", "CS-Envelopes", "CS-Envelope-Editor", "CS Template Editor", "CS Templates", "Templates"]) {
      await replaceInWT(n, [["pepp-", "ppep-"]]);
    }
  }
  if (PHASE === "headerfooter" || PHASE === "all") {
    console.log("--- header/footer (coe nav + footer) ---");
    await upsertWT("CS-header", "CS-header.html");
    await upsertWT("CS-footer", "CS-footer.html");
  }
  if (PHASE === "dashboard" || PHASE === "all") {
    console.log("--- My Workspace dashboard + shared envelope list ---");
    await upsertWT("CS-EnvelopeList", "CS-EnvelopeList.html"); // shared list component
    await upsertWT("CS-Home-WET", "CS-Home-WET.html");
  }
  if (PHASE === "pages" || PHASE === "all") {
    // Content-only redeploy of the workspace feature pages. The page-template + web-page
    // records are created once by scripts/create-portal-pages.mjs; this re-pushes their source.
    console.log("--- feature-page web templates (notifications, brief, help, activity) ---");
    await upsertWT("CS-Notifications", "CS-Notifications.html");
    await upsertWT("CS-Product-Brief", "CS-Product-Brief.html");
    await upsertWT("CS-Help-Guide", "CS-Help-Guide.html");
    await upsertWT("CS-Activity-History", "CS-Activity-History.html");
    await upsertWT("CS-Envelope-Details", "CS-Envelope-Details.html"); // /envelopes/details/ (records via create-envelope-details-page.mjs)
    await upsertFile("pdf.worker.min.js", join(ROOT, "power-pages", "theme", "assets", "pdf.worker.min.js")); // same-origin pdf.js worker (CSP blocks cross-origin worker)
  }
  if (PHASE === "lists" || PHASE === "all") {
    // Facelifted service list pages (envelopes + templates) to match the workspace design.
    console.log("--- service list pages (envelopes, templates) ---");
    await upsertWT("CS-EnvelopeList", "CS-EnvelopeList.html"); // shared list component (same as My Workspace)
    await upsertWT("CS-Envelopes", "CS-Envelopes.html");
    await upsertWT("Templates", "Templates.html"); // the live /templates/ web template (3ecb30b4; RBAC sections)
  }
  if (PHASE === "editors" || PHASE === "all") {
    // Template + envelope editors — carry the RBAC owner/visibility stamping.
    console.log("--- editors (template + envelope) ---");
    await upsertWT("CS Template Editor", "CS-Template-Editor.html");
    await upsertWT("CS-Envelope-Editor", "CS-Envelope-Editor.html");
  }
  console.log("done.");
}
main().catch((e) => { console.error(e); process.exit(1); });
