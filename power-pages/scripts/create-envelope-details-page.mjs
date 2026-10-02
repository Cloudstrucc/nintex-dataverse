// Create the Envelope Details page (/envelopes/details/?id=) — web template +
// page template + web page (root + EN content) under the Envelopes parent page.
// Idempotent. The web-template SOURCE is also (re)pushed by deploy-portal-theme.mjs `pages`.
//
//   node power-pages/scripts/create-envelope-details-page.mjs <dev|test>
//
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
const WTDIR = join(ROOT, "power-pages", "theme", "webtemplates");
function loadEnv(){const t=readFileSync(join(ROOT,".env"),"utf8");const e={};for(const l of t.split("\n")){if(l.trim().startsWith("#"))continue;const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,"");}return e;}
const E=loadEnv();
const TARGETS={dev:"https://dev-ec-esign-01.crm3.dynamics.com",test:"https://test-ec-esign-01.crm3.dynamics.com"};
const ENVNAME=process.argv[2]||"dev";const URL=TARGETS[ENVNAME];if(!URL){console.error("unknown env "+ENVNAME);process.exit(1);}
const SITE="17ed601c-7964-498a-8d9c-a64d08f85583";
const PUB="b28e4a69-3c59-4737-ad75-e4a0b66ab3ef";   // Published state
const EN="00f8e6d9-91b2-4429-95e4-87fe6a85084e";     // English language
const ENVROOT="248f3b2d-3f3a-f111-88b5-7ced8da586db"; // Envelopes root web page (parent)
const bind={"powerpagesiteid@odata.bind":`/powerpagesites(${SITE})`};
let _t;async function tok(){if(_t)return _t;const r=await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({client_id:E.EC_CLIENT_ID,client_secret:E.EC_CLIENT_SECRET,scope:`${URL}/.default`,grant_type:"client_credentials"})});if(!r.ok)throw new Error("token "+r.status+await r.text());_t=(await r.json()).access_token;return _t;}
async function api(m,p,b,x){const t=await tok();const h={Authorization:`Bearer ${t}`,Accept:"application/json","OData-Version":"4.0",...(x||{})};if(b!==undefined)h["Content-Type"]="application/json";const r=await fetch(p.startsWith("http")?p:`${URL}/api/data/v9.2/${p}`,{method:m,headers:h,body:b!==undefined?JSON.stringify(b):undefined});const tx=await r.text();let j=null;try{j=tx?JSON.parse(tx):null;}catch{}return{ok:r.ok,status:r.status,json:j,text:tx,entityId:r.headers.get("odata-entityid")};}
const q=s=>s.replace(/'/g,"''");const idFrom=e=>e&&e.match(/\(([0-9a-f-]+)\)/i)?e.match(/\(([0-9a-f-]+)\)/i)[1]:null;
async function list(type,extra=""){return (await api("GET",`powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${type}${extra}&$select=name,content,powerpagecomponentid&$top=200`)).json.value||[];}
function show(t,r){console.log(t,r.status,r.ok?"OK":JSON.stringify(r.json&&r.json.error||r.text).slice(0,200));return r;}
async function upsertWT(name,file){const content=JSON.stringify({source:readFileSync(join(WTDIR,file),"utf8")});const ex=await list(8,` and name eq '${q(name)}'`);if(ex.length)return(show("WT PATCH "+name,await api("PATCH",`powerpagecomponents(${ex[0].powerpagecomponentid})`,{content})),ex[0].powerpagecomponentid);return idFrom(show("WT POST "+name,await api("POST","powerpagecomponents",{name,powerpagecomponenttype:8,content,...bind})).entityId);}
async function upsertPT(name,wtId){const content=JSON.stringify({isdefault:false,type:756150001,usewebsiteheaderandfooter:true,webtemplateid:wtId});const ex=await list(6,` and name eq '${q(name)}'`);if(ex.length)return(show("PT PATCH "+name,await api("PATCH",`powerpagecomponents(${ex[0].powerpagecomponentid})`,{content})),ex[0].powerpagecomponentid);return idFrom(show("PT POST "+name,await api("POST","powerpagecomponents",{name,powerpagecomponenttype:6,content,...bind})).entityId);}
async function ensurePage(slug,title,ptId){const wp=await list(2);const P=p=>{try{return JSON.parse(p.content);}catch{return {};}};
  let root=wp.find(p=>{const c=P(p);return c.isroot&&c.partialurl===slug&&c.parentpageid===ENVROOT;});let rootId;
  if(root){rootId=root.powerpagecomponentid;console.log("root exists",slug);}
  else{const content=JSON.stringify({displayorder:20,enablerating:false,enabletracking:false,excludefromsearch:false,feedbackpolicy:756150005,hiddenfromsitemap:false,isroot:true,pagetemplateid:ptId,parentpageid:ENVROOT,partialurl:slug,publishingstateid:PUB,sharedpageconfiguration:false,title});rootId=idFrom(show("WP root "+slug,await api("POST","powerpagecomponents",{name:title,powerpagecomponenttype:2,content,...bind})).entityId);}
  const en=wp.find(p=>{const c=P(p);return !c.isroot&&c.rootwebpageid===rootId;});if(en){console.log("content exists",slug);return;}
  const content=JSON.stringify({displayorder:20,enablerating:false,enabletracking:false,excludefromsearch:false,feedbackpolicy:756150005,hiddenfromsitemap:false,isroot:false,pagetemplateid:ptId,parentpageid:ENVROOT,partialurl:slug,publishingstateid:PUB,rootwebpageid:rootId,sharedpageconfiguration:false,title});
  show("WP content "+slug,await api("POST","powerpagecomponents",{name:title,powerpagecomponenttype:2,content,"powerpagesitelanguageid@odata.bind":`/powerpagesitelanguages(${EN})`,...bind}));}
async function main(){
  console.log(`# create-envelope-details-page target=${ENVNAME} (${URL})`);
  const wt=await upsertWT("CS-Envelope-Details","CS-Envelope-Details.html");
  const pt=await upsertPT("CS-Envelope-Details",wt);
  await ensurePage("details","Envelope Details",pt);
  console.log("publish:",(await api("POST","PublishAllXml",{})).status);
  console.log("done. Restart the site (or pac pages download→edit→upload) to flush cache.");
}
main().catch(e=>{console.error(e);process.exit(1);});
