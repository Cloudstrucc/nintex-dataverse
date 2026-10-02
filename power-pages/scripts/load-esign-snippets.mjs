// Load bilingual (EN+FR) content-snippet records for the optimized e-Sign UI.
//   node power-pages/scripts/load-esign-snippets.mjs <dev|test> [--dry]
// EN is taken from the template defaults (power-pages/scripts/esign-snippets.json),
// FR from the FR map below. Idempotent: PATCHes existing, POSTs missing.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..", "..");
function loadEnv(){const t=readFileSync(join(ROOT,".env"),"utf8");const e={};for(const l of t.split("\n")){if(l.trim().startsWith("#"))continue;const m=l.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/);if(m)e[m[1]]=m[2].replace(/^["']|["']$/g,"");}return e;}
const E=loadEnv();
const TARGETS={dev:"https://dev-ec-esign-01.crm3.dynamics.com",test:"https://test-ec-esign-01.crm3.dynamics.com"};
const ENVNAME=process.argv[2]||"dev";const DRY=process.argv.includes("--dry");const URL=TARGETS[ENVNAME];if(!URL){console.error("unknown env");process.exit(1);}
const SITE="17ed601c-7964-498a-8d9c-a64d08f85583";
const LANG={en:"00f8e6d9-91b2-4429-95e4-87fe6a85084e",fr:"1c59862a-d627-f111-88b5-7ced8da586db"};
const bind={"powerpagesiteid@odata.bind":`/powerpagesites(${SITE})`};
const q=s=>s.replace(/'/g,"''");
let _t;async function tok(){if(_t)return _t;const r=await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`,{method:"POST",headers:{"Content-Type":"application/x-www-form-urlencoded"},body:new URLSearchParams({client_id:E.EC_CLIENT_ID,client_secret:E.EC_CLIENT_SECRET,scope:`${URL}/.default`,grant_type:"client_credentials"})});_t=(await r.json()).access_token;return _t;}
async function api(m,p,b){const t=await tok();const h={Authorization:`Bearer ${t}`,Accept:"application/json","OData-Version":"4.0"};if(b!==undefined)h["Content-Type"]="application/json";const r=await fetch(p.startsWith("http")?p:`${URL}/api/data/v9.2/${p}`,{method:m,headers:h,body:b!==undefined?JSON.stringify(b):undefined});const tx=await r.text();let j=null;try{j=tx?JSON.parse(tx):null;}catch{}return{ok:r.ok,status:r.status,json:j,text:tx};}
async function findSnip(name,langId){const r=await api("GET",`powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq 7 and name eq '${q(name)}' and _powerpagesitelanguageid_value eq ${langId}&$select=powerpagecomponentid,content`);return (r.json&&r.json.value&&r.json.value[0])||null;}
async function upsertSnip(name,langId,value){const content=JSON.stringify({value});const ex=await findSnip(name,langId);if(ex){if(DRY){console.log("  would PATCH",name,langId===LANG.en?"EN":"FR");return;}const r=await api("PATCH",`powerpagecomponents(${ex.powerpagecomponentid})`,{content});console.log(`  PATCH ${name} [${langId===LANG.en?"EN":"FR"}]: ${r.status}`);return;}if(DRY){console.log("  would POST ",name,langId===LANG.en?"EN":"FR");return;}const r=await api("POST","powerpagecomponents",{name,powerpagecomponenttype:7,...bind,"powerpagesitelanguageid@odata.bind":`/powerpagesitelanguages(${langId})`,content});console.log(`  POST  ${name} [${langId===LANG.en?"EN":"FR"}]: ${r.status}${r.ok?"":" "+r.text.slice(0,120)}`);}

const EN = JSON.parse(readFileSync(join(HERE,"esign-snippets.json"),"utf8")); // key -> EN default
const FR = {
"ESIGN/ACT/COL/DETAIL":"Détail","ESIGN/ACT/COL/ITEM":"Élément","ESIGN/ACT/COL/TYPE":"Type","ESIGN/ACT/COL/WHEN":"Date",
"ESIGN/ACT/SUB":"Un relevé combiné de vos enveloppes, modèles, documents et notifications.","ESIGN/ACT/TITLE":"Activité et historique",
"ESIGN/BRIEF/FEATURES":"Fonctionnalités clés","ESIGN/BRIEF/HOW":"Fonctionnement","ESIGN/BRIEF/KICKER":"Aperçu du produit",
"ESIGN/BRIEF/SEC/B":"Toutes les données sont conservées dans Dataverse, au sein du locataire d'Élections Canada. L'accès est régi par Entra ID et les autorisations de table de Power Pages. Chaque événement de signature est consigné, et les documents terminés sont accompagnés d'un certificat de vérification conforme aux normes de sécurité informatique du gouvernement du Canada.",
"ESIGN/BRIEF/SEC/T":"Sécurité et conformité",
"ESIGN/BRIEF/SUB":"Une façon sécurisée et conforme aux normes du GC d'envoyer, de signer et de gérer des documents — bâtie sur la plateforme Nintex AssureSign et Microsoft Power Platform.",
"ESIGN/BRIEF/TITLE":"Service de signature électronique",
"ESIGN/BRIEF/WHAT/B":"Le Service de signature électronique permet aux équipes d'Élections Canada d'obtenir des signatures à force exécutoire sur des documents officiels sans impression, numérisation ni envoi postal. Les enveloppes sont créées à partir de modèles approuvés, acheminées aux signataires dans l'ordre établi, et suivies jusqu'à leur achèvement avec une piste de vérification infalsifiable.",
"ESIGN/BRIEF/WHAT/T":"Description",
"ESIGN/COL/CREATED":"Créé le","ESIGN/COL/ENV":"Enveloppe","ESIGN/COL/MODIFIED":"Modifié le","ESIGN/COL/STATUS":"Statut","ESIGN/COL/SUBJECT":"Objet",
"ESIGN/DETAILS/DOC":"Document",
"ESIGN/ENVELOPES/DESC":"Créez et gérez des enveloppes de signature électronique.","ESIGN/ENVELOPES/TITLE":"Enveloppes",
"ESIGN/FOOTER/BRAND":"elections.ca","ESIGN/FOOTER/DESC":"Usage interne — Service de signature électronique d'Élections Canada","ESIGN/FOOTER/PRIVACY":"Confidentialité","ESIGN/FOOTER/TERMS":"Conditions d'utilisation",
"ESIGN/HEADER/APP":"Service de signature électronique","ESIGN/HEADER/ORG":"Élections Canada",
"ESIGN/HELP/CONTACT/BTN":"Écrire au soutien","ESIGN/HELP/CONTACT/EMAIL":"esign-support@elections.ca",
"ESIGN/HELP/SUB":"Tout ce qu'il vous faut pour envoyer, signer et gérer des documents avec le Service de signature électronique.","ESIGN/HELP/TITLE":"Guide d'aide",
"ESIGN/HOME/ACTIVEVIEW":"Enveloppes actives","ESIGN/HOME/CREATE":"Créer une enveloppe","ESIGN/HOME/ENVTITLE":"Mes enveloppes","ESIGN/HOME/FILTER":"Saisir pour filtrer les lignes...",
"ESIGN/HOME/PORTAL":"Mon portail d'Élections Canada","ESIGN/HOME/SERVICES":"Mes services","ESIGN/HOME/WELCOME":"Bon retour","ESIGN/HOME/WORKSPACE":"Mon espace de travail",
"ESIGN/KPI/DONE":"Terminées","ESIGN/KPI/ERR":"Action requise","ESIGN/KPI/PROC":"En cours","ESIGN/KPI/TOTAL":"Total des enveloppes",
"ESIGN/LIST/SHOW":"Afficher",
"ESIGN/MENU/ACTIVITY":"Activité et historique","ESIGN/MENU/NOTIFICATIONS":"Notifications","ESIGN/MENU/PROFILE":"Mon profil","ESIGN/MENU/SIGNOUT":"Se déconnecter",
"ESIGN/NAV/HELP":"Aide","ESIGN/NAV/HOME":"Accueil","ESIGN/NAV/MENU":"Menu","ESIGN/NAV/NOTIFICATIONS":"Notifications","ESIGN/NAV/WORKSPACE":"Mon espace de travail",
"ESIGN/NOTIF/ACTION":"Action requise","ESIGN/NOTIF/ALL":"Toutes","ESIGN/NOTIF/COL/MSG":"Message","ESIGN/NOTIF/COL/PRI":"Priorité","ESIGN/NOTIF/COL/SVC":"Service","ESIGN/NOTIF/COL/WHEN":"Reçu le",
"ESIGN/NOTIF/FYI":"Pour information","ESIGN/NOTIF/MARKALL":"Tout marquer comme lu","ESIGN/NOTIF/SUB":"Messages et alertes concernant vos enveloppes, modèles et documents.","ESIGN/NOTIF/TITLE":"Centre de notifications","ESIGN/NOTIF/UNREAD":"Non lues",
"ESIGN/PILL/ENVELOPES":"Enveloppes","ESIGN/PILL/TEMPLATES":"Modèles",
"ESIGN/SVC/DOC/L1":"Voir les documents signés","ESIGN/SVC/DOC/L2":"Télécharger la piste de vérification","ESIGN/SVC/DOC/T":"Documents signés",
"ESIGN/SVC/ENV/L1":"Voir mes enveloppes","ESIGN/SVC/ENV/L2":"Créer une nouvelle enveloppe","ESIGN/SVC/ENV/T":"Enveloppes",
"ESIGN/SVC/HELP/C":"Aide et contact","ESIGN/SVC/HELP/L1":"Fonctionnement de la signature électronique","ESIGN/SVC/HELP/L2":"Communiquer avec le soutien","ESIGN/SVC/HELP/T":"Aide et soutien",
"ESIGN/SVC/TPL/C":"Modèles réutilisables","ESIGN/SVC/TPL/L1":"Parcourir les modèles","ESIGN/SVC/TPL/L2":"Créer un modèle","ESIGN/SVC/TPL/T":"Modèles",
"ESIGN/TEMPLATES/ACTIVEVIEW":"Tous les modèles","ESIGN/TEMPLATES/COL_CAT":"Catégorie","ESIGN/TEMPLATES/COL_CREATED":"Créé le","ESIGN/TEMPLATES/COL_MODIFIED":"Modifié le","ESIGN/TEMPLATES/COL_NAME":"Modèle","ESIGN/TEMPLATES/COL_STATUS":"Statut","ESIGN/TEMPLATES/CREATE_BTN":"Créer un modèle",
"ESIGN/TEMPLATES/DESC":"Parcourez les modèles de signature approuvés. Utilisez-en un pour envoyer une enveloppe ou téléchargez le document source.","ESIGN/TEMPLATES/LOADING":"Chargement…","ESIGN/TEMPLATES/SEARCH_PH":"Rechercher des modèles...","ESIGN/TEMPLATES/TABLE_HEADING":"Modèles de signature","ESIGN/TEMPLATES/TITLE":"Modèles",
"ESIGN/TKPI/ACTIVE":"Actifs","ESIGN/TKPI/DOC":"Avec document","ESIGN/TKPI/INACTIVE":"Inactifs","ESIGN/TKPI/TOTAL":"Total des modèles",
"ESIGN/DETAILS/BACK":"Retour aux enveloppes","ESIGN/DETAILS/ENVELOPE":"Enveloppe","ESIGN/DETAILS/LOADING":"Chargement…","ESIGN/DETAILS/REFRESH":"Actualiser le statut","ESIGN/DETAILS/REFRESH_TITLE":"Lance la synchronisation du statut pour cette enveloppe"
};
// EN overrides where the template default differs in intent / to normalize entities
const EN_OVERRIDE={"ESIGN/ACT/TITLE":"Activity & history","ESIGN/MENU/ACTIVITY":"Activity & history","ESIGN/SVC/HELP/T":"Help & support","ESIGN/BRIEF/SEC/T":"Security & compliance","ESIGN/BRIEF/WHAT/T":"What it is",
"ESIGN/DETAILS/BACK":"Back to envelopes","ESIGN/DETAILS/ENVELOPE":"Envelope","ESIGN/DETAILS/LOADING":"Loading…","ESIGN/DETAILS/REFRESH":"Refresh status","ESIGN/DETAILS/REFRESH_TITLE":"Runs the status sync for this envelope"};
function enFor(k){let v=EN_OVERRIDE[k]!==undefined?EN_OVERRIDE[k]:EN[k];if(v==null)return null;return v.replace(/&amp;/g,"&");}

async function main(){
  const keys=Object.keys(FR);
  console.log(`# load-esign-snippets target=${ENVNAME}${DRY?" (dry)":""} — ${keys.length} keys`);
  let miss=[];
  for(const k of keys){const en=enFor(k);if(en==null){miss.push(k);continue;}await upsertSnip(k,LANG.en,en);await upsertSnip(k,LANG.fr,FR[k]);}
  if(miss.length)console.log("NO EN DEFAULT FOUND for:",miss.join(", "));
  console.log("done.");
}
main().catch(e=>{console.error(e);process.exit(1);});
