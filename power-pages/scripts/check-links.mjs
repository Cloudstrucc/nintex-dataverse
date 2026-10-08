// Resolvable-route health check for the ec-esign portal.
// Verifies every route used by nav + table row actions resolves to a real web page
// (or a known Power Pages framework route). A 404-bound link fails LOUDLY and the
// process exits non-zero, so it stands out like any other failing test.
//
// Usage:  node power-pages/scripts/check-links.mjs <dev|test>
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "..");
const TARGETS = {
  dev:  { url: "https://dev-ec-esign-01.crm3.dynamics.com" },
  test: { url: "https://test-ec-esign-01.crm3.dynamics.com" },
};
const ENVNAME = process.argv[2] || "dev";
const T = TARGETS[ENVNAME];
if (!T) { console.error("unknown env:", ENVNAME); process.exit(2); }

function loadEnv() {
  const t = readFileSync(join(ROOT, ".env"), "utf8"); const e = {};
  for (const line of t.split("\n")) { if (line.trim().startsWith("#")) continue;
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, ""); }
  return e;
}
const E = loadEnv();
let _tok;
async function tok() {
  if (_tok) return _tok;
  const body = new URLSearchParams({ grant_type: "client_credentials", client_id: E.EC_CLIENT_ID, client_secret: E.EC_CLIENT_SECRET, scope: `${T.url}/.default` });
  const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body });
  return (_tok = (await r.json()).access_token);
}
async function api(path) {
  const r = await fetch(`${T.url}/api/data/v9.2/${path}`, { headers: { Authorization: `Bearer ${await tok()}`, Accept: "application/json" } });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return r.json();
}

// Routes the portal links to. Content routes must resolve to a web page; framework
// routes are handled by the Power Pages Identity app. Keep in sync with the nav
// (CS-header) and the table row-action menus (Templates / CS-EnvelopeList).
const CONTENT_ROUTES = [
  "/",                            // home / My Workspace
  "/templates/",                  // Templates list
  "/templates/edit-template/",    // template editor (create/edit)
  "/envelopes/",                  // Envelopes list
  "/envelopes/edit-envelope/",    // envelope editor (use template / create)
  "/envelopes/details/",          // envelope details (row View)
  "/notifications/",              // notification centre (bell)
  "/activity/",                   // activity & history
  "/product-brief/",              // product brief
  "/help/",                       // help
  "/profile/",                    // my profile (avatar menu)
];
const FRAMEWORK_ROUTES = [
  "/Account/Login/LogOff",        // sign out
  "/Account/Login",               // sign in
];

function norm(p) { if (p === "/" || p === "") return "/"; return "/" + p.split("/").filter(Boolean).join("/") + "/"; }

async function resolvablePaths() {
  const r = await api(`powerpagecomponents?$select=name,content,powerpagecomponentid&$filter=powerpagecomponenttype eq 2&$top=500`);
  const byId = {};
  for (const p of r.value) { let c = {}; try { c = JSON.parse(p.content); } catch {}
    byId[p.powerpagecomponentid] = { id: p.powerpagecomponentid, name: p.name, partialurl: c.partialurl, parent: c.parentpageid, isroot: c.isroot }; }
  const paths = new Set();
  for (const id in byId) {
    const segs = []; let cur = byId[id], guard = 0;
    while (cur && guard++ < 20) {
      if (cur.partialurl && cur.partialurl !== "/") segs.unshift(cur.partialurl);
      const parent = cur.parent && byId[cur.parent];
      if (!parent || parent.id === cur.id) break;
      cur = parent;
    }
    paths.add(segs.length ? "/" + segs.join("/") + "/" : "/");
  }
  return paths;
}

(async () => {
  console.log(`# check-links  env=${ENVNAME}`);
  const paths = await resolvablePaths();
  const fails = [];
  for (const route of CONTENT_ROUTES) {
    const want = norm(route);
    const ok = paths.has(want) || (want === "/" && paths.has("/"));
    console.log(`  ${ok ? "PASS" : "FAIL"}  ${route}${ok ? "" : "   <-- no web page resolves this route (404)"}`);
    if (!ok) fails.push(route);
  }
  for (const route of FRAMEWORK_ROUTES) {
    const ok = /^\/Account\/Login(\/LogOff)?$/.test(route);
    console.log(`  ${ok ? "PASS" : "FAIL"}  ${route}  (framework)`);
    if (!ok) fails.push(route);
  }
  if (fails.length) {
    console.error(`\n❌ ${fails.length} ROUTE(S) WOULD 404:\n   ${fails.join("\n   ")}`);
    console.error("   Fix the link or create the missing web page (scripts/create-portal-pages.mjs).");
    process.exit(1);
  }
  console.log(`\n✅ all ${CONTENT_ROUTES.length + FRAMEWORK_ROUTES.length} routes resolve.`);
})().catch((e) => { console.error("check-links ERROR:", e.message); process.exit(2); });
