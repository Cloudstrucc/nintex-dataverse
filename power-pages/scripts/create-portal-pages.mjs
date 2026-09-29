// Create the workspace feature pages (root + EN content web page, page template) in the
// e-sign-dev enhanced-model portal. Idempotent: re-running only fills in what is missing.
// The web-template *source* is (re)pushed here and by deploy-portal-theme.mjs `pages` phase.
//
//   node power-pages/scripts/create-portal-pages.mjs <dev|test>
//
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "..");
const WTDIR = join(ROOT, "power-pages", "theme", "webtemplates");

function loadEnv() {
  const t = readFileSync(join(ROOT, ".env"), "utf8"); const e = {};
  for (const line of t.split("\n")) { if (line.trim().startsWith("#")) continue; const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, ""); }
  return e;
}
const E = loadEnv();
const TARGETS = {
  dev:  "https://dev-ec-esign-01.crm3.dynamics.com",
  test: "https://test-ec-esign-01.crm3.dynamics.com",
};
const ENVNAME = process.argv[2] || "dev";
const URL = TARGETS[ENVNAME];
if (!URL) { console.error(`unknown env "${ENVNAME}" (use dev|test)`); process.exit(1); }

// Same website/component GUIDs across dev and test.
const SITE = "17ed601c-7964-498a-8d9c-a64d08f85583";
const HOME = "696f7f46-dd3a-48b6-a333-3e9b17859607";       // Home root web page
const PUB  = "b28e4a69-3c59-4737-ad75-e4a0b66ab3ef";       // Published state
const EN   = "00f8e6d9-91b2-4429-95e4-87fe6a85084e";       // English powerpagesitelanguage
const bind = { "powerpagesiteid@odata.bind": `/powerpagesites(${SITE})` };

let _tok;
async function token() {
  if (_tok) return _tok;
  const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, {
    method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ client_id: E.EC_CLIENT_ID, client_secret: E.EC_CLIENT_SECRET, scope: `${URL}/.default`, grant_type: "client_credentials" }),
  });
  if (!r.ok) throw new Error(`token ${r.status}: ${await r.text()}`);
  _tok = (await r.json()).access_token; return _tok;
}
async function api(method, path, body, extra) {
  const t = await token();
  const h = { Authorization: `Bearer ${t}`, Accept: "application/json", "OData-Version": "4.0", ...(extra || {}) };
  if (body !== undefined) h["Content-Type"] = "application/json";
  const r = await fetch(path.startsWith("http") ? path : `${URL}/api/data/v9.2/${path}`, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined });
  const txt = await r.text(); let json = null; try { json = txt ? JSON.parse(txt) : null; } catch {}
  return { ok: r.ok, status: r.status, json, text: txt, entityId: r.headers.get("odata-entityid") };
}
const q = (s) => s.replace(/'/g, "''");
const idFrom = (e) => e?.match(/\(([0-9a-f-]+)\)/i)?.[1];
async function list(type, extra = "") {
  const r = await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${type}${extra}&$select=name,content,powerpagecomponentid&$top=200`);
  return r.json?.value || [];
}
function show(t, r) { console.log(t, r.status, r.ok ? "OK" : JSON.stringify(r.json?.error || r.text).slice(0, 240)); return r; }

async function upsertWT(name, file) {
  const content = JSON.stringify({ source: readFileSync(join(WTDIR, file), "utf8") });
  const ex = await list(8, ` and name eq '${q(name)}'`);
  if (ex.length) { show(`WT PATCH ${name}`, await api("PATCH", `powerpagecomponents(${ex[0].powerpagecomponentid})`, { content })); return ex[0].powerpagecomponentid; }
  return idFrom(show(`WT POST ${name}`, await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: 8, content, ...bind })).entityId);
}
async function upsertPT(name, wtId) {
  const content = JSON.stringify({ isdefault: false, type: 756150001, usewebsiteheaderandfooter: true, webtemplateid: wtId });
  const ex = await list(6, ` and name eq '${q(name)}'`);
  if (ex.length) { show(`PT PATCH ${name}`, await api("PATCH", `powerpagecomponents(${ex[0].powerpagecomponentid})`, { content })); return ex[0].powerpagecomponentid; }
  return idFrom(show(`PT POST ${name}`, await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: 6, content, ...bind })).entityId);
}
async function ensurePage(slug, title, ptId) {
  const url = "/" + slug;
  const wp = await list(2);
  const parse = (p) => { try { return JSON.parse(p.content); } catch { return {}; } };
  let root = wp.find((p) => { const c = parse(p); return c.isroot && c.partialurl === url; });
  let rootId;
  if (root) { rootId = root.powerpagecomponentid; console.log(`root exists ${slug}`); }
  else {
    const content = JSON.stringify({ displayorder: 20, enablerating: false, enabletracking: false, excludefromsearch: false, feedbackpolicy: 756150005, hiddenfromsitemap: false, isroot: true, pagetemplateid: ptId, parentpageid: HOME, partialurl: url, publishingstateid: PUB, sharedpageconfiguration: false, title });
    rootId = idFrom(show(`WP root ${slug}`, await api("POST", "powerpagecomponents", { name: title, powerpagecomponenttype: 2, content, ...bind })).entityId);
  }
  const en = wp.find((p) => { const c = parse(p); return !c.isroot && c.rootwebpageid === rootId; });
  if (en) { console.log(`content exists ${slug}`); return; }
  const content = JSON.stringify({ displayorder: 20, enablerating: false, enabletracking: false, excludefromsearch: false, feedbackpolicy: 756150005, hiddenfromsitemap: false, isroot: false, pagetemplateid: ptId, partialurl: url, publishingstateid: PUB, rootwebpageid: rootId, sharedpageconfiguration: false, title });
  show(`WP content ${slug}`, await api("POST", "powerpagecomponents", { name: title, powerpagecomponenttype: 2, content, "powerpagesitelanguageid@odata.bind": `/powerpagesitelanguages(${EN})`, ...bind }));
}

const PAGES = [
  { slug: "notifications", wt: "CS-Notifications",     file: "CS-Notifications.html",     title: "Notification centre" },
  { slug: "product-brief", wt: "CS-Product-Brief",     file: "CS-Product-Brief.html",     title: "Product brief" },
  { slug: "help",          wt: "CS-Help-Guide",        file: "CS-Help-Guide.html",        title: "Help guide" },
  { slug: "activity",      wt: "CS-Activity-History",  file: "CS-Activity-History.html",  title: "Activity & history" },
];
async function main() {
  console.log(`# create-portal-pages target=${ENVNAME} (${URL})`);
  for (const p of PAGES) {
    const wtId = await upsertWT(p.wt, p.file);
    const ptId = await upsertPT(p.wt, wtId);
    await ensurePage(p.slug, p.title, ptId);
  }
  console.log("publish:", (await api("POST", "PublishAllXml", {})).status);
  console.log("done. Restart the site (Admin center -> Site Actions -> Restart) to flush cache.");
}
main().catch((e) => { console.error(e); process.exit(1); });
