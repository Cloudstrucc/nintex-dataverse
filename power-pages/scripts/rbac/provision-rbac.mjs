// Templates RBAC provisioning — idempotent, Web API only (enhanced data model).
// Creates/ensures the RBAC schema + Power Pages table permissions + Web API config
// for: envelope ownership, My/Global/Shared templates, and the Template Maker role.
//
// Usage:  node power-pages/scripts/rbac/provision-rbac.mjs <dev|test> [--perms-only]
//
// Creds from .env (EC_TENANT_ID / EC_CLIENT_ID / EC_CLIENT_SECRET — System Admin across EC envs).
// Schema goes into the ESignatureBroker unmanaged solution (publisher cs / 71764).
//
// NOTE: table-permission + Web-API-field changes require a site RESTART to take effect
// (admin center -> site -> Site Actions -> Restart). This script only writes them.
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = join(__dirname, "..", "..", "..");
const SOL = "ESignatureBroker";
const TARGETS = {
  dev:  { url: "https://dev-ec-esign-01.crm3.dynamics.com",  wsid: "17ed601c-7964-498a-8d9c-a64d08f85583" },
  test: { url: "https://test-ec-esign-01.crm3.dynamics.com", wsid: "17ed601c-7964-498a-8d9c-a64d08f85583" },
};
const ENVNAME = process.argv[2] || "dev";
const PERMS_ONLY = process.argv.includes("--perms-only");
const T = TARGETS[ENVNAME];
if (!T) { console.error("unknown env:", ENVNAME); process.exit(1); }

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
  const j = await r.json(); if (!j.access_token) throw new Error("token: " + JSON.stringify(j));
  return (_tok = j.access_token);
}
async function api(path, { method = "GET", body, headers = {} } = {}) {
  const t = await tok();
  const url = path.startsWith("http") ? path : `${T.url}/api/data/v9.2/${path}`;
  const h = { Authorization: `Bearer ${t}`, "OData-MaxVersion": "4.0", "OData-Version": "4.0", Accept: "application/json", ...headers };
  if (body !== undefined) h["Content-Type"] = "application/json";
  const r = await fetch(url, { method, headers: h, body: body !== undefined ? (typeof body === "string" ? body : JSON.stringify(body)) : undefined });
  const txt = await r.text(); let data = null; try { data = txt ? JSON.parse(txt) : null; } catch { data = txt; }
  if (!r.ok) { const e = new Error(`${method} ${url} -> ${r.status}`); e.status = r.status; e.data = data; throw e; }
  return data;
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- web role component ids (type 11) ----
async function roleMap() {
  const r = await api(`powerpagecomponents?$select=name,powerpagecomponentid&$filter=powerpagecomponenttype eq 11`);
  const m = {}; for (const x of r.value) m[x.name] = x.powerpagecomponentid; return m;
}

// ---- relationship schema names (stable once created) ----
const REL = {
  envOwner: "cs_contact_csenvelope_ownercontact",
  tplOwner: "cs_contact_cstemplate_ownercontact",
  shareWith: "cs_contact_cstemplateshare_with",
  shareBy: "cs_contact_cstemplateshare_by",
  catalog: "cs_cstemplatecatalog_cstemplate",
};
const SCOPE = { GLOBAL: 756150000, CONTACT: 756150001, PARENT: 756150003 };

async function ensureCatalog() {
  // table
  let tblId;
  try { tblId = (await api(`EntityDefinitions(LogicalName='cs_templatecatalog')?$select=MetadataId`)).MetadataId; console.log("catalog table: exists"); }
  catch (e) { if (e.status !== 404) throw e;
    const r = await api(`EntityDefinitions`, { method: "POST", headers: { Prefer: "return=representation" }, body: {
      "@odata.type": "Microsoft.Dynamics.CRM.EntityMetadata", SchemaName: "cs_templatecatalog",
      DisplayName: { LocalizedLabels: [{ Label: "Template Catalog", LanguageCode: 1033 }] },
      DisplayCollectionName: { LocalizedLabels: [{ Label: "Template Catalogs", LanguageCode: 1033 }] },
      OwnershipType: "UserOwned", IsActivity: false, HasActivities: false, HasNotes: false,
      Attributes: [{ "@odata.type": "Microsoft.Dynamics.CRM.StringAttributeMetadata", SchemaName: "cs_name",
        DisplayName: { LocalizedLabels: [{ Label: "Name", LanguageCode: 1033 }] }, RequiredLevel: { Value: "ApplicationRequired" }, MaxLength: 200, FormatName: { Value: "Text" }, IsPrimaryName: true }],
    }}); tblId = r.MetadataId; console.log("catalog table: created"); await sleep(4000);
  }
  // lookup
  try { const rel = await api(`EntityDefinitions(LogicalName='cs_template')/ManyToOneRelationships?$select=SchemaName&$filter=ReferencingAttribute eq 'cs_catalog'`);
    if ((rel.value || []).length) console.log("cs_catalog lookup: exists");
    else throw { status: 404 };
  } catch {
    for (let i = 0; i < 5; i++) { try {
      await api(`RelationshipDefinitions`, { method: "POST", headers: { Prefer: "return=representation" }, body: {
        "@odata.type": "Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata", SchemaName: REL.catalog,
        ReferencedEntity: "cs_templatecatalog", ReferencingEntity: "cs_template",
        Lookup: { "@odata.type": "Microsoft.Dynamics.CRM.LookupAttributeMetadata", SchemaName: "cs_catalog",
          DisplayName: { LocalizedLabels: [{ Label: "Catalog", LanguageCode: 1033 }] }, RequiredLevel: { Value: "None" } },
        AssociatedMenuConfiguration: { Behavior: "DoNotDisplay", Group: "Details", Order: 10000 },
        CascadeConfiguration: { Assign: "NoCascade", Delete: "RemoveLink", Merge: "NoCascade", Reparent: "NoCascade", Share: "NoCascade", Unshare: "NoCascade" },
      }}); console.log("cs_catalog lookup: created"); break;
    } catch (e) { if (i === 4) throw e; await sleep(8000); } }
  }
  // seed row
  const ex = await api(`cs_templatecatalogs?$select=cs_templatecatalogid&$top=1`);
  let rowId = ex.value?.[0]?.cs_templatecatalogid;
  if (!rowId) { rowId = (await api(`cs_templatecatalogs`, { method: "POST", headers: { Prefer: "return=representation" }, body: { cs_name: "Global Templates" } })).cs_templatecatalogid; console.log("catalog row: created"); }
  else console.log("catalog row: exists");
  return rowId;
}

async function addToSolution(componentId, componentType, label) {
  try { await api(`AddSolutionComponent`, { method: "POST", body: { ComponentId: componentId, ComponentType: componentType, SolutionUniqueName: SOL, AddRequiredComponents: false, DoNotIncludeSubcomponents: false } }); console.log("  +sol:", label); }
  catch (e) { console.log("  +sol", label, "skip", e.status); }
}

// ---- table permissions ----
const rights = (r) => ({ append: !!r.append, appendto: !!r.appendto, create: !!r.create, delete: !!r.del, read: !!r.read, write: !!r.write });
// NB: for type-18 components the component `name` is forced to content.entityname.
// Primary per-table perms use label = table logical name; additional perms use a
// distinct friendly label so names stay unique and findPerm() is idempotent.
function permContent({ label, table, scope, roles, r, contactrelationship, parentrelationship, parententitypermission = null }) {
  const c = { ...rights(r), entitylogicalname: table, entityname: label, scope, parententitypermission };
  if (contactrelationship) c.contactrelationship = contactrelationship;
  if (parentrelationship) c.parentrelationship = parentrelationship;
  c.adx_entitypermission_webrole = roles;
  return c;
}
async function findPerm(name) {
  const r = await api(`powerpagecomponents?$select=powerpagecomponentid&$filter=powerpagecomponenttype eq 18 and name eq '${name.replace(/'/g, "''")}'`);
  return r.value?.[0]?.powerpagecomponentid || null;
}
async function upsertPerm(name, c, bkdir) {
  const id = await findPerm(name);
  const content = JSON.stringify(c, null, 2);
  if (id) {
    const cur = await api(`powerpagecomponents(${id})?$select=content`);
    writeFileSync(join(bkdir, `${name}.${id}.before.json`), cur.content || "");
    await api(`powerpagecomponents(${id})`, { method: "PATCH", body: { content } });
    console.log("  perm updated:", name); return id;
  }
  const r = await api(`powerpagecomponents`, { method: "POST", headers: { Prefer: "return=representation" }, body: { name, powerpagecomponenttype: 18, content, "powerpagesiteid@odata.bind": `/powerpagesites(${T.wsid})` } });
  console.log("  perm created:", name); return r.powerpagecomponentid;
}

async function writePerms(roles, bkdir) {
  const AUTH = roles["Authenticated Users"], ADMIN = roles["Administrators"], MAKER = roles["Template Maker"];
  if (!AUTH || !ADMIN || !MAKER) throw new Error("missing web role(s): " + JSON.stringify({ AUTH, ADMIN, MAKER }));
  // primaries (one per table — keep bare table name as label)
  await upsertPerm("cs_envelope", permContent({ label: "cs_envelope", table: "cs_envelope", scope: SCOPE.CONTACT, roles: [AUTH], r: { append: 1, appendto: 1, create: 1, del: 1, read: 1, write: 1 }, contactrelationship: REL.envOwner }), bkdir);
  await upsertPerm("cs_template", permContent({ label: "cs_template", table: "cs_template", scope: SCOPE.CONTACT, roles: [AUTH], r: { append: 1, appendto: 1, create: 1, del: 1, read: 1, write: 1 }, contactrelationship: REL.tplOwner }), bkdir);
  await upsertPerm("cs_templateshare", permContent({ label: "cs_templateshare", table: "cs_templateshare", scope: SCOPE.CONTACT, roles: [AUTH], r: { read: 1 }, contactrelationship: REL.shareWith }), bkdir);
  // additional perms (distinct friendly labels)
  const catPerm = await upsertPerm("Template Catalog (read)", permContent({ label: "Template Catalog (read)", table: "cs_templatecatalog", scope: SCOPE.GLOBAL, roles: [AUTH, ADMIN], r: { read: 1, appendto: 1 } }), bkdir);
  await upsertPerm("Global Templates (read)", permContent({ label: "Global Templates (read)", table: "cs_template", scope: SCOPE.PARENT, roles: [AUTH], r: { read: 1 }, parentrelationship: REL.catalog, parententitypermission: catPerm }), bkdir);
  await upsertPerm("Global Templates (manage)", permContent({ label: "Global Templates (manage)", table: "cs_template", scope: SCOPE.GLOBAL, roles: [MAKER, ADMIN], r: { append: 1, appendto: 1, create: 1, del: 1, read: 1, write: 1 } }), bkdir);
  await upsertPerm("Template Shares (owner)", permContent({ label: "Template Shares (owner)", table: "cs_templateshare", scope: SCOPE.CONTACT, roles: [AUTH], r: { append: 1, appendto: 1, create: 1, del: 1, read: 1, write: 1 }, contactrelationship: REL.shareBy }), bkdir);
  // Association rights: setting a lookup to contact (owner/share/notification) needs AppendTo on
  // the contact permission; best-effort patch of the existing contact + portalmessage perms.
  await ensureAssocRights();
}

async function ensureAssocRights() {
  for (const name of ["contact_read", "cs_portalmessage"]) {
    const r = await api(`powerpagecomponents?$select=powerpagecomponentid,content&$filter=powerpagecomponenttype eq 18 and name eq '${name}'`);
    const row = r.value?.[0]; if (!row) { console.log("  assoc: MISS", name); continue; }
    const c = JSON.parse(row.content); c.append = true; c.appendto = true; c.read = true;
    if (name === "cs_portalmessage") { c.create = true; c.write = true; }
    await api(`powerpagecomponents(${row.powerpagecomponentid})`, { method: "PATCH", body: { content: JSON.stringify(c, null, 2) } });
    console.log("  assoc rights:", name);
  }
}

// ---- Web API site settings ----
// Field lists need BOTH the `_<lookup>_value` form (for reads) AND the PascalCase navigation
// property (e.g. cs_OwnerContact) for writing that lookup via @odata.bind.
const WEBAPI = {
  cs_template: ["cs_templateid","cs_name","cs_description","cs_category","cs_isactive","cs_templatejson","cs_visibility","_cs_ownercontact_value","_cs_modifiedbycontact_value","_cs_catalog_value","cs_OwnerContact","cs_ModifiedByContact","cs_catalog","cs_templatepdf_name","createdon","modifiedon","_createdby_value","_modifiedby_value"],
  cs_envelope: ["cs_envelopeid","cs_name","cs_subject","_cs_ownercontact_value","cs_OwnerContact","cs_sentdate","cs_statuscheckrequestedon","createdon","modifiedon"],
  cs_templateshare: ["cs_templateshareid","cs_name","_cs_templatelink_value","_cs_sharedwithcontact_value","_cs_sharedbycontact_value","cs_TemplateLink","cs_SharedWithContact","cs_SharedByContact","cs_sharedon","cs_sharedname","cs_sharedcategory","createdon","modifiedon"],
  cs_templatecatalog: ["cs_templatecatalogid","cs_name"],
  cs_portalmessage: ["cs_subject","cs_content","cs_service","cs_prioritytype","_cs_recipientcontactid_value","cs_RecipientContactId"],
};
async function findSetting(name) {
  const r = await api(`powerpagecomponents?$select=powerpagecomponentid,content&$filter=powerpagecomponenttype eq 9 and name eq '${name}'`);
  return r.value?.[0] || null;
}
async function setSetting(name, value) {
  const ex = await findSetting(name); const content = JSON.stringify({ value });
  if (ex) await api(`powerpagecomponents(${ex.powerpagecomponentid})`, { method: "PATCH", body: { content } });
  else await api(`powerpagecomponents`, { method: "POST", headers: { Prefer: "return=representation" }, body: { name, powerpagecomponenttype: 9, content, "powerpagesiteid@odata.bind": `/powerpagesites(${T.wsid})` } });
}
async function writeWebApi() {
  for (const [table, cols] of Object.entries(WEBAPI)) {
    await setSetting(`Webapi/${table}/enabled`, "true");
    const fs = await findSetting(`Webapi/${table}/fields`); let cur = [];
    if (fs) { try { cur = JSON.parse(fs.content).value.split(",").map((s) => s.trim()).filter(Boolean); } catch {} }
    await setSetting(`Webapi/${table}/fields`, Array.from(new Set([...cur, ...cols])).join(","));
    console.log("  webapi:", table);
  }
}

// ---- tag legacy templates as Global ----
async function tagGlobalTemplates(rowId) {
  const tpls = await api(`cs_templates?$select=cs_templateid,_cs_ownercontact_value,_cs_catalog_value`);
  let n = 0;
  for (const t of tpls.value) {
    if (t._cs_ownercontact_value) continue;        // personal -> leave private
    if (t._cs_catalog_value === rowId) continue;   // already tagged
    await api(`cs_templates(${t.cs_templateid})`, { method: "PATCH", body: { cs_visibility: 717640000, "cs_catalog@odata.bind": `/cs_templatecatalogs(${rowId})` } });
    n++;
  }
  console.log("  tagged global templates:", n);
}

(async () => {
  console.log(`RBAC provisioning -> ${ENVNAME} (${T.url})`);
  const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
  const bkdir = join(ROOT, "power-pages", "backups", `e-sign-${ENVNAME}`, `rbac-perms-${ts}`);
  mkdirSync(bkdir, { recursive: true });
  const roles = await roleMap();
  let rowId;
  if (!PERMS_ONLY) { rowId = await ensureCatalog();
    // add catalog table/attr/rel to solution (best effort)
    try { const tbl = await api(`EntityDefinitions(LogicalName='cs_templatecatalog')?$select=MetadataId`); await addToSolution(tbl.MetadataId, 1, "cs_templatecatalog"); } catch {}
    try { const a = await api(`EntityDefinitions(LogicalName='cs_template')/Attributes(LogicalName='cs_catalog')?$select=MetadataId`); await addToSolution(a.MetadataId, 2, "cs_template.cs_catalog"); } catch {}
    try { const rel = await api(`EntityDefinitions(LogicalName='cs_template')/ManyToOneRelationships?$select=MetadataId&$filter=ReferencingAttribute eq 'cs_catalog'`); if (rel.value?.[0]) await addToSolution(rel.value[0].MetadataId, 10, REL.catalog); } catch {}
  } else {
    rowId = (await api(`cs_templatecatalogs?$select=cs_templatecatalogid&$top=1`)).value?.[0]?.cs_templatecatalogid;
  }
  console.log("Permissions:");
  await writePerms(roles, bkdir);
  console.log("Web API:");
  await writeWebApi();
  if (rowId) { console.log("Tagging:"); await tagGlobalTemplates(rowId); }
  console.log(`\nDONE. Backups -> ${bkdir}`);
  console.log("⚠  Restart the site (admin center -> Site Actions -> Restart) to activate permissions + Web API fields.");
})().catch((e) => { console.error("FAILED:", e.status || "", e.message, e.data ? JSON.stringify(e.data).slice(0, 300) : ""); process.exit(1); });
