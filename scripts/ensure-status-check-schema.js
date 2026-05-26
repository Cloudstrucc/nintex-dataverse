#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const envPath = path.join(repoRoot, ".env");

function loadEnv(filePath) {
  const text = fs.readFileSync(filePath, "utf8");
  for (const rawLine of text.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (!line || line.startsWith("#")) continue;
    const match = line.match(/^([A-Za-z_][A-Za-z0-9_]*)=(.*)$/);
    if (!match) continue;
    const [, key, rawValue] = match;
    let value = rawValue.trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

function label(text) {
  return {
    "@odata.type": "Microsoft.Dynamics.CRM.Label",
    LocalizedLabels: [
      {
        "@odata.type": "Microsoft.Dynamics.CRM.LocalizedLabel",
        Label: text,
        LanguageCode: 1033,
      },
    ],
  };
}

async function token() {
  const required = [
    "EC_ENVIRONMENT_URL",
    "EC_TENANT_ID",
    "EC_CLIENT_ID",
    "EC_CLIENT_SECRET",
  ];
  for (const name of required) {
    if (!process.env[name]) throw new Error(`${name} is not set in .env`);
  }

  const body = new URLSearchParams({
    client_id: process.env.EC_CLIENT_ID,
    client_secret: process.env.EC_CLIENT_SECRET,
    scope: `${process.env.EC_ENVIRONMENT_URL}/.default`,
    grant_type: "client_credentials",
  });
  const res = await fetch(
    `https://login.microsoftonline.com/${process.env.EC_TENANT_ID}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
  );
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new Error(
      `Dataverse auth failed: ${json.error_description || json.error || res.status}`,
    );
  }
  return json.access_token;
}

async function dv(accessToken, method, url, body, extraHeaders = {}) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    Accept: "application/json",
    "OData-MaxVersion": "4.0",
    "OData-Version": "4.0",
    ...extraHeaders,
  };
  if (body) headers["Content-Type"] = "application/json; charset=utf-8";

  const res = await fetch(`${process.env.EC_ENVIRONMENT_URL}/api/data/v9.2/${url}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) {
    const message = json?.error?.message || text || `${res.status} ${res.statusText}`;
    throw new Error(`${method} ${url} failed: ${message}`);
  }
  return json;
}

async function attributeExists(accessToken, logicalName) {
  const result = await dv(
    accessToken,
    "GET",
    `EntityDefinitions(LogicalName='cs_envelope')/Attributes(LogicalName='${logicalName}')/Microsoft.Dynamics.CRM.DateTimeAttributeMetadata?$select=LogicalName`,
  ).catch((error) => {
    if (String(error.message).includes("does not exist")) return null;
    throw error;
  });
  return Boolean(result?.LogicalName);
}

async function ensureDateAttribute(accessToken, definition) {
  if (await attributeExists(accessToken, definition.logicalName)) {
    console.log(`ok   ${definition.logicalName} already exists`);
    return false;
  }

  await dv(
    accessToken,
    "POST",
    "EntityDefinitions(LogicalName='cs_envelope')/Attributes",
    {
      "@odata.type": "Microsoft.Dynamics.CRM.DateTimeAttributeMetadata",
      AttributeType: "DateTime",
      AttributeTypeName: { Value: "DateTimeType" },
      Description: label(definition.description),
      DisplayName: label(definition.displayName),
      RequiredLevel: {
        Value: "None",
        CanBeChanged: true,
        ManagedPropertyLogicalName: "canmodifyrequirementlevelsettings",
      },
      SchemaName: definition.schemaName,
      Format: "DateAndTime",
    },
    { "MSCRM.SolutionUniqueName": "nintex" },
  );
  console.log(`add  ${definition.logicalName}`);
  return true;
}

async function statusOptions(accessToken) {
  const metadata = await dv(
    accessToken,
    "GET",
    "EntityDefinitions(LogicalName='cs_envelope')/Attributes(LogicalName='statuscode')/Microsoft.Dynamics.CRM.StatusAttributeMetadata?$expand=OptionSet",
  );
  return metadata.OptionSet.Options.map((option) => ({
    value: option.Value,
    state: option.State,
    label: option.Label?.UserLocalizedLabel?.Label,
  }));
}

async function ensureStatus(accessToken, status) {
  const options = await statusOptions(accessToken);
  if (options.some((option) => option.value === status.value)) {
    console.log(`ok   status ${status.value} already exists`);
    return false;
  }

  await dv(accessToken, "POST", "InsertStatusValue", {
    AttributeLogicalName: "statuscode",
    EntityLogicalName: "cs_envelope",
    Label: label(status.label),
    StateCode: status.state,
    Value: status.value,
    SolutionUniqueName: "nintex",
  });
  console.log(`add  status ${status.value} ${status.label}`);
  return true;
}

async function publish(accessToken) {
  await dv(accessToken, "POST", "PublishXml", {
    ParameterXml:
      "<importexportxml><entities><entity>cs_envelope</entity></entities></importexportxml>",
  });
  console.log("ok   published cs_envelope customizations");
}

async function main() {
  loadEnv(envPath);
  const accessToken = await token();

  let changed = false;
  changed =
    (await ensureDateAttribute(accessToken, {
      logicalName: "cs_statuscheckrequestedon",
      schemaName: "cs_StatusCheckRequestedOn",
      displayName: "Status Check Requested On",
      description: "Timestamp set by clients to request a Nintex status refresh.",
    })) || changed;
  changed =
    (await ensureDateAttribute(accessToken, {
      logicalName: "cs_statuslastcheckedon",
      schemaName: "cs_StatusLastCheckedOn",
      displayName: "Status Last Checked On",
      description: "Timestamp set by the broker after a Nintex status refresh.",
    })) || changed;

  for (const status of [
    { value: 717640008, state: 1, label: "Staled" },
    { value: 717640009, state: 1, label: "Signer Authentication Failed" },
  ]) {
    changed = (await ensureStatus(accessToken, status)) || changed;
  }

  if (changed) await publish(accessToken);
  console.log(changed ? "done schema updated" : "done schema already current");
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
