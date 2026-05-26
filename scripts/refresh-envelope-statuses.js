#!/usr/bin/env node

const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const envPath = path.join(repoRoot, ".env");
const dryRun = !process.argv.includes("--apply");

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

function mapStatus(rawStatus) {
  const status = String(rawStatus || "").toLowerCase();
  switch (status) {
    case "completed":
      return { statecode: 1, statuscode: 5, terminal: true };
    case "cancelled":
      return { statecode: 1, statuscode: 8, terminal: true };
    case "declined":
      return { statecode: 1, statuscode: 10, terminal: true };
    case "expired":
      return { statecode: 1, statuscode: 11, terminal: true };
    case "staled":
      return { statecode: 1, statuscode: 717640008, terminal: true };
    case "signerauthenticationfailed":
      return { statecode: 1, statuscode: 717640009, terminal: true };
    default:
      return { statecode: 0, statuscode: 717640003, terminal: false };
  }
}

async function dataverseToken() {
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

async function nintexToken() {
  const required = [
    "NINTEX_API_USERNAME",
    "NINTEX_API_KEY",
    "NINTEX_CONTEXT_USERNAME",
    "NINTEX_AUTH_URL",
    "NINTEX_API_BASE_URL",
  ];
  for (const name of required) {
    if (!process.env[name]) throw new Error(`${name} is not set in .env`);
  }

  const res = await fetch(`${process.env.NINTEX_AUTH_URL}/authentication/apiUser`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      request: {
        apiUsername: process.env.NINTEX_API_USERNAME,
        key: process.env.NINTEX_API_KEY,
        contextUsername: process.env.NINTEX_CONTEXT_USERNAME,
        sessionLengthInMinutes: 60,
      },
    }),
  });
  const json = await res.json();
  if (!res.ok || !json.result?.token) {
    throw new Error(`Nintex auth failed: ${JSON.stringify(json)}`);
  }
  return json.result.token;
}

async function dv(accessToken, method, url, body) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    Accept: "application/json",
    "OData-MaxVersion": "4.0",
    "OData-Version": "4.0",
  };
  if (body) headers["Content-Type"] = "application/json";

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

async function listEnvelopes(accessToken) {
  const rows = [];
  let url =
    "cs_envelopes?$select=cs_envelopeid,cs_name,cs_preparedenvelopeid,statecode,statuscode,cs_completeddate,cs_cancelleddate,cs_statuscheckrequestedon,cs_statuslastcheckedon&$filter=cs_preparedenvelopeid ne null";
  while (url) {
    const page = await dv(accessToken, "GET", url);
    rows.push(...page.value);
    const next = page["@odata.nextLink"];
    url = next ? next.replace(`${process.env.EC_ENVIRONMENT_URL}/api/data/v9.2/`, "") : null;
  }
  return rows;
}

async function getNintexStatus(token, envelopeId) {
  const res = await fetch(
    `${process.env.NINTEX_API_BASE_URL}/envelopes/${envelopeId}/status`,
    {
      headers: {
        Authorization: `bearer ${token}`,
        "X-AS-UserContext": process.env.NINTEX_CONTEXT_USERNAME,
        Accept: "application/json",
      },
    },
  );
  const json = await res.json();
  if (!res.ok || !json.result?.status) {
    throw new Error(`Nintex status failed for ${envelopeId}: ${JSON.stringify(json)}`);
  }
  return json.result;
}

function updatePayload(row, nintexResult, refreshTime) {
  const mapped = mapStatus(nintexResult.status);
  const payload = {
    statecode: mapped.statecode,
    statuscode: mapped.statuscode,
    cs_statuscheckrequestedon: refreshTime,
    cs_statuslastcheckedon: refreshTime,
  };

  if (mapped.statuscode === 5 && !row.cs_completeddate) {
    payload.cs_completeddate = nintexResult.completedDate || refreshTime;
  }
  if (mapped.statuscode === 8 && !row.cs_cancelleddate) {
    payload.cs_cancelleddate = nintexResult.cancelledDate || refreshTime;
  }
  return payload;
}

function changed(row, payload) {
  return (
    row.statecode !== payload.statecode ||
    row.statuscode !== payload.statuscode ||
    !row.cs_statuscheckrequestedon ||
    !row.cs_statuslastcheckedon ||
    (payload.cs_completeddate && row.cs_completeddate !== payload.cs_completeddate) ||
    (payload.cs_cancelleddate && row.cs_cancelleddate !== payload.cs_cancelleddate)
  );
}

async function main() {
  loadEnv(envPath);
  const [dvToken, asToken] = await Promise.all([dataverseToken(), nintexToken()]);
  const rows = await listEnvelopes(dvToken);
  const summary = { total: rows.length, updated: 0, unchanged: 0, skipped: 0, failed: 0 };

  console.log(`${dryRun ? "DRY RUN" : "APPLY"} refreshing ${rows.length} envelopes`);
  for (const row of rows) {
    if (!row.cs_preparedenvelopeid) {
      summary.skipped += 1;
      continue;
    }

    try {
      const refreshTime = new Date().toISOString();
      const nintexResult = await getNintexStatus(asToken, row.cs_preparedenvelopeid);
      const payload = updatePayload(row, nintexResult, refreshTime);
      const shouldUpdate = changed(row, payload);
      const name = row.cs_name || row.cs_envelopeid;
      console.log(
        `${shouldUpdate ? "update" : "keep  "} ${name} nintex=${nintexResult.status} -> state=${payload.statecode} status=${payload.statuscode}`,
      );

      if (shouldUpdate && !dryRun) {
        await dv(dvToken, "PATCH", `cs_envelopes(${row.cs_envelopeid})`, payload);
      }
      summary[shouldUpdate ? "updated" : "unchanged"] += 1;
    } catch (error) {
      summary.failed += 1;
      console.error(`fail  ${row.cs_envelopeid}: ${error.message}`);
    }
  }

  console.log(`summary ${JSON.stringify(summary)}`);
  if (summary.failed > 0) process.exitCode = 1;
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
