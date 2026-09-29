// Create the cs_portalmessage table (ESignaturePortal unmanaged solution), enable it for the
// portal Web API, add a table permission, and seed a few demo notifications. Idempotent.
//
//   node power-pages/scripts/create-portalmessage-table.mjs <dev|test>
//
// cs_portalmessage columns: cs_subject (primary), cs_content (memo), cs_service (string),
// cs_prioritytype (choice 717640000 Immediate action required / 717640001 For your information),
// cs_readon (datetime; null = unread), cs_recipientcontactid (lookup -> contact),
// statecode/statuscode (Active / Inactive = archived).
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");
function loadEnv() { const t = readFileSync(join(ROOT, ".env"), "utf8"); const e = {}; for (const line of t.split("\n")) { if (line.trim().startsWith("#")) continue; const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$/); if (m) e[m[1]] = m[2].replace(/^["']|["']$/g, ""); } return e; }
const E = loadEnv();
const TARGETS = { dev: "https://dev-ec-esign-01.crm3.dynamics.com", test: "https://test-ec-esign-01.crm3.dynamics.com" };
const ENVNAME = process.argv[2] || "dev"; const URL = TARGETS[ENVNAME];
if (!URL) { console.error(`unknown env "${ENVNAME}"`); process.exit(1); }

const SITE = "17ed601c-7964-498a-8d9c-a64d08f85583";
const PUBLISHER = "ba1df8f3-5a8d-4b21-b9fa-1aedfd647565"; // "cs" publisher (prefix cs, option prefix 71764)
const SOLUTION = "ESignaturePortal";
const ROLES = ["cc291ece-e88e-4ddf-9668-7c06d00d2b5f", "f88e7e1f-a280-41ae-bf36-0ac0a418c6dc"]; // Admins, Authenticated Users
const bind = { "powerpagesiteid@odata.bind": `/powerpagesites(${SITE})` };
const solHdr = { "MSCRM.SolutionUniqueName": SOLUTION };

let _tok;
async function token() { if (_tok) return _tok; const r = await fetch(`https://login.microsoftonline.com/${E.EC_TENANT_ID}/oauth2/v2.0/token`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: new URLSearchParams({ client_id: E.EC_CLIENT_ID, client_secret: E.EC_CLIENT_SECRET, scope: `${URL}/.default`, grant_type: "client_credentials" }) }); if (!r.ok) throw new Error(`token ${r.status}: ${await r.text()}`); _tok = (await r.json()).access_token; return _tok; }
async function api(method, path, body, extra) { const t = await token(); const h = { Authorization: `Bearer ${t}`, Accept: "application/json", "OData-Version": "4.0", ...(extra || {}) }; if (body !== undefined) h["Content-Type"] = "application/json"; const r = await fetch(path.startsWith("http") ? path : `${URL}/api/data/v9.2/${path}`, { method, headers: h, body: body !== undefined ? JSON.stringify(body) : undefined }); const txt = await r.text(); let json = null; try { json = txt ? JSON.parse(txt) : null; } catch {} return { ok: r.ok, status: r.status, json, text: txt, entityId: r.headers.get("odata-entityid") }; }
const L = (s) => ({ "@odata.type": "Microsoft.Dynamics.CRM.Label", LocalizedLabels: [{ "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel", Label: s, LanguageCode: 1033 }] });
const RL = (v) => ({ Value: v, CanBeChanged: true, ManagedPropertyLogicalName: "canmodifyrequirementlevelsettings" });
function show(t, r) { console.log(t, r.status, r.ok ? "OK" : JSON.stringify(r.json?.error || r.text).slice(0, 240)); return r; }
const attrPath = "EntityDefinitions(LogicalName='cs_portalmessage')/Attributes";
async function hasAttr(ln) { const r = await api("GET", `${attrPath}?$select=LogicalName&$filter=LogicalName eq '${ln}'`); return (r.json?.value || []).length > 0; }

async function main() {
  console.log(`# create-portalmessage-table target=${ENVNAME} (${URL})`);
  // 1. Solution
  if (!(await api("GET", `solutions?$filter=uniquename eq '${SOLUTION}'&$select=solutionid`)).json.value.length)
    show("solution", await api("POST", "solutions", { uniquename: SOLUTION, friendlyname: "E-Signature Portal", version: "1.0.0.0", "publisherid@odata.bind": `/publishers(${PUBLISHER})` }));
  // 2. Entity + primary name
  if ((await api("GET", "EntityDefinitions(LogicalName='cs_portalmessage')?$select=LogicalName")).status === 404)
    show("entity", await api("POST", "EntityDefinitions", { "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata", SchemaName: "cs_PortalMessage", DisplayName: L("Portal Message"), DisplayCollectionName: L("Portal Messages"), Description: L("Notification-centre messages shown to portal users."), OwnershipType: "UserOwned", IsActivity: false, HasNotes: false, HasActivities: false, Attributes: [{ "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata", SchemaName: "cs_Subject", IsPrimaryName: true, MaxLength: 300, FormatName: { Value: "Text" }, AttributeTypeName: { Value: "StringType" }, RequiredLevel: RL("ApplicationRequired"), DisplayName: L("Subject") }] }, solHdr));
  // 3. Attributes  (note: send AttributeTypeName only, NOT AttributeType, or metadata POST 400s)
  if (!(await hasAttr("cs_content"))) show("cs_content", await api("POST", attrPath, { "@odata.type": "Microsoft.Dynamics.CRM.MemoAttributeMetadata", SchemaName: "cs_Content", MaxLength: 2000, Format: "TextArea", ImeMode: "Auto", AttributeTypeName: { Value: "MemoType" }, RequiredLevel: RL("None"), DisplayName: L("Content") }, solHdr));
  if (!(await hasAttr("cs_service"))) show("cs_service", await api("POST", attrPath, { "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata", SchemaName: "cs_Service", MaxLength: 100, FormatName: { Value: "Text" }, AttributeTypeName: { Value: "StringType" }, RequiredLevel: RL("None"), DisplayName: L("Service") }, solHdr));
  if (!(await hasAttr("cs_readon"))) show("cs_readon", await api("POST", attrPath, { "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata", SchemaName: "cs_ReadOn", Format: "DateAndTime", DateTimeBehavior: { Value: "UserLocal" }, AttributeTypeName: { Value: "DateTimeType" }, RequiredLevel: RL("None"), DisplayName: L("Read On") }, solHdr));
  if (!(await hasAttr("cs_prioritytype"))) show("cs_prioritytype", await api("POST", attrPath, { "@odata.type": "Microsoft.Dynamics.CRM.PicklistAttributeMetadata", SchemaName: "cs_PriorityType", AttributeTypeName: { Value: "PicklistType" }, RequiredLevel: RL("None"), DisplayName: L("Priority"), OptionSet: { "@odata.type": "Microsoft.Dynamics.CRM.OptionSetMetadata", IsGlobal: false, OptionSetType: "Picklist", Options: [{ "@odata.type": "Microsoft.Dynamics.CRM.OptionMetadata", Value: 717640000, Label: L("Immediate action required") }, { "@odata.type": "Microsoft.Dynamics.CRM.OptionMetadata", Value: 717640001, Label: L("For your information") }] } }, solHdr));
  if (!(await hasAttr("cs_recipientcontactid"))) show("lookup", await api("POST", "RelationshipDefinitions", { "@odata.type": "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata", SchemaName: "cs_contact_portalmessage", ReferencedEntity: "contact", ReferencingEntity: "cs_portalmessage", ReferencedAttribute: "contactid", Lookup: { "@odata.type": "Microsoft.Dynamics.CRM.LookupAttributeMetadata", SchemaName: "cs_RecipientContactId", DisplayName: L("Recipient"), RequiredLevel: RL("None") }, AssociatedMenuConfiguration: { Behavior: "UseCollectionName", Group: "Details", Order: 10000 }, CascadeConfiguration: { Assign: "NoCascade", Delete: "RemoveLink", Merge: "NoCascade", Reparent: "NoCascade", Share: "NoCascade", Unshare: "NoCascade" } }, solHdr));
  show("publish", await api("POST", "PublishAllXml", {}));

  // 4. Portal Web API + table permission (Global, matching this site's other tables)
  const fields = "cs_portalmessageid,cs_subject,cs_content,cs_service,cs_prioritytype,cs_readon,cs_recipientcontactid,statecode,statuscode,createdon";
  async function upsertComp(type, name, contentObj) { const content = JSON.stringify(contentObj); const ex = (await api("GET", `powerpagecomponents?$filter=_powerpagesiteid_value eq ${SITE} and powerpagecomponenttype eq ${type} and name eq '${name.replace(/'/g, "''")}'&$select=powerpagecomponentid`)).json?.value?.[0]; if (ex) return show(`PATCH ${name}`, await api("PATCH", `powerpagecomponents(${ex.powerpagecomponentid})`, { content })); return show(`POST ${name}`, await api("POST", "powerpagecomponents", { name, powerpagecomponenttype: type, content, ...bind })); }
  await upsertComp(9, "Webapi/cs_portalmessage/enabled", { source: 0, value: "true" });
  await upsertComp(9, "Webapi/cs_portalmessage/fields", { source: 0, value: fields });
  await upsertComp(18, "cs_portalmessage", { append: true, appendto: true, create: true, delete: true, entitylogicalname: "cs_portalmessage", entityname: "cs_portalmessage", read: true, scope: 756150000, write: true, adx_entitypermission_webrole: ROLES });

  // 5. Seed (only if empty) — recipient resolved by email; edit for other environments.
  if ((await api("GET", "cs_portalmessages?$select=cs_portalmessageid&$top=1")).json?.value?.length) { console.log("seed skipped (records exist)"); }
  else {
    const contact = (await api("GET", "contacts?$filter=emailaddress1 eq 'Fredrick.Pearson@Elections.ca'&$select=contactid")).json?.value?.[0]?.contactid;
    if (!contact) { console.log("seed skipped (recipient contact not found)"); }
    else {
      const ago = (h) => new Date(Date.now() - h * 3600e3).toISOString();
      const seeds = [
        { cs_subject: "Action required: a signer declined 'Financial Agent Consent'", cs_content: "The signer Jordan Blake declined to sign envelope 'Financial Agent Consent'. Review the envelope and re-send if appropriate.", cs_service: "Envelopes", cs_prioritytype: 717640000, cs_readon: null },
        { cs_subject: "Envelope 'Nomination Package' completed", cs_content: "All signers have completed 'Nomination Package'. The signed documents are ready to download.", cs_service: "Envelopes", cs_prioritytype: 717640001, cs_readon: null },
        { cs_subject: "Reminder sent to pending signer", cs_content: "A signing reminder was sent to the pending signer on 'Auditor Appointment'.", cs_service: "Envelopes", cs_prioritytype: 717640001, cs_readon: null },
        { cs_subject: "Template 'Candidate Nomination' published", cs_content: "Your template 'Candidate Nomination' is now active and available when creating envelopes.", cs_service: "Templates", cs_prioritytype: 717640001, cs_readon: ago(30) },
        { cs_subject: "Signed document ready: 'Auditor Appointment'", cs_content: "The completed and audited PDF for 'Auditor Appointment' is available in Signed documents.", cs_service: "Documents", cs_prioritytype: 717640001, cs_readon: ago(50) },
      ];
      for (const s of seeds) show("seed: " + s.cs_subject.slice(0, 30), await api("POST", "cs_portalmessages", { ...s, "cs_RecipientContactId@odata.bind": `/contacts(${contact})` }));
    }
  }
  console.log("done. Restart the site to flush the portal cache.");
}
main().catch((e) => { console.error(e); process.exit(1); });
