// Health-check: verify critical same-origin assets the portal code depends on
// are published Web Files at the EXACT paths the code references.
//   node power-pages/scripts/check-assets.mjs <dev|test>
// Exit code 1 if any required asset is missing / at the wrong path (CI gate).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
function loadEnv(){const t=readFileSync(join(ROOT,".env"),"utf8");const e={};for(const l of t.split("\n")){if(l.trim().startsWith("#"))continue;const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,"");}return e;}
const E=loadEnv();
const TARGETS={dev:"https://dev-ec-esign-01.crm3.dynamics.com",test:"https://test-ec-esign-01.crm3.dynamics.com"};
const ENVNAME=process.argv[2]||"dev";const URL=TARGETS[ENVNAME];if(!URL){console.error("unknown env "+ENVNAME);process.exit(1);}
const SITE="17ed601c-7964-498a-8d9c-a64d08f85583";
// Paths the portal CODE references (editors, Details, header). Keep in sync with the templates.
const REQUIRED=[
  {path:"/js/pdf.min.js",       why:"pdf.js library — loaded by CS-Template-Editor & CS-Envelope-Editor"},
  {path:"/pdf.worker.min.js",   why:"pdf.js worker — editors + CS-Envelope-Details overlay (same-origin, CSP-required)"},
  {path:"/ec-logo.png",         why:"brand logo in CS-header"}
];
let _t;async function tok(){if(_t)return _t;const r=await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({client_id:E.EC_CLIENT_ID,client_secret:E.EC_CLIENT_SECRET,scope:`${URL}/.default`,grant_type:"client_credentials"})});_t=(await r.json()).access_token;return _t;}
async function api(p){const t=await tok();const r=await fetch(`${URL}/api/data/v9.2/${p}`,{headers:{Authorization:`Bearer ${t}`,Accept:"application/json"}});return (await r.json()).value||[];}
function parse(c){try{return JSON.parse(c)||{};}catch{return {};}}
const [files,pages,pub]=await Promise.all([
  api(`powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq 3&$select=name,content&$top=1000`),
  api(`powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq 2&$select=content,powerpagecomponentid&$top=1000`),
  api(`powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq 1&$select=name,powerpagecomponentid&$top=50`)
]);
const pageById={};for(const p of pages){const c=parse(p.content);pageById[p.powerpagecomponentid]={partial:c.partialurl,parent:c.parentpageid,isroot:c.isroot};}
function fullPath(parentId){ // build "/a/b" prefix from the parent page chain
  var parts=[],id=parentId,guard=0;
  while(id&&pageById[id]&&guard++<10){var pu=pageById[id].partial;if(pu&&pu!=="/")parts.unshift(pu);id=pageById[id].parent;}
  return "/"+parts.join("/");
}
// map published full URL -> file
const published={};
for(const f of files){const c=parse(f.content);if(!c.partialurl)continue;const prefix=fullPath(c.parentpageid);const url=(prefix==="/"?"":prefix)+"/"+c.partialurl;published[url]=f.name;}
console.log(`# check-assets target=${ENVNAME}`);
let fail=0;
for(const r of REQUIRED){const ok=published[r.path];console.log(`  ${ok?"PASS":"FAIL"}  ${r.path}${ok?"":"  <-- MISSING"}   (${r.why})`);if(!ok)fail++;}
console.log(fail?`\nFAILED: ${fail} missing asset path(s).`:`\nAll ${REQUIRED.length} critical assets present at their expected paths.`);
process.exit(fail?1:0);
