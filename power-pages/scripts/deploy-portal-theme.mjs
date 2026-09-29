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
const T = { PAGE: 2, PT: 6, SNIP: 7, WT: 8, SETTING: 9, ROLE: 11 };

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

async function resolveHomePub() {
  const pages = (await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${T.PAGE} and name eq 'Home'&$select=powerpagecomponentid,content`)).json.value || [];
  const home = pages.find((p) => { try { return JSON.parse(p.content || "{}").isroot === true; } catch { return false; } }) || pages[0];
  const states = (await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq 1&$select=powerpagecomponentid,content`)).json.value || [];
  const pub = states.find((s) => { try { return JSON.parse(s.content || "{}").isdefault; } catch { return false; } }) || states[0];
  return { HOME: home.powerpagecomponentid, PUB: pub.powerpagecomponentid };
}
async function upsertFile(name, binPath, order = 5) {
  const { HOME, PUB } = await resolveHomePub();
  const content = JSON.stringify({ displayorder: order, enabletracking: false, excludefromsearch: true, hiddenfromsitemap: true, parentpageid: HOME, partialurl: name, publishingstateid: PUB });
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
  }
  if (PHASE === "header-footer" || PHASE === "all") {
    console.log("--- Phase 2: load theme via bound header/footer ---");
    await appendInclude("CS-header", "EC-Base-Styles");   // -> EC-Brand-Facelift + modern styles (all CSS)
    await appendInclude("CS-footer", "EC-Scripts-Base");  // -> all EC JS enhancements
  }
  if (PHASE === "logo" || PHASE === "all") {
    console.log("--- Phase 3a: header logo (from coe-dev-fp) ---");
    await upsertFile("ec-logo.png", join(ROOT, "power-pages", "theme", "assets", "ec-logo.png"), 5);
    await replaceInWT("CS-header", [["/logo-bw-contrast.png", "/ec-logo.png"], ["/logo-invert.png", "/ec-logo.png"]]);
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
  console.log("done.");
}
main().catch((e) => { console.error(e); process.exit(1); });
