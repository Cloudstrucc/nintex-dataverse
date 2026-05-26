"use strict";

const { odataString, requestJson } = require("./http");

async function getDataverseToken(config) {
  const body = new URLSearchParams({
    client_id: config.clientId,
    client_secret: config.clientSecret,
    grant_type: "client_credentials",
    scope: `${config.environmentUrl}/.default`,
  });

  const response = await requestJson(
    `https://login.microsoftonline.com/${config.tenantId}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
  );

  if (!response?.access_token) {
    throw new Error("Dataverse authentication response did not include an access token.");
  }

  return response.access_token;
}

function dataverseHeaders(accessToken, includeContentType = false) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    Accept: "application/json",
    "OData-MaxVersion": "4.0",
    "OData-Version": "4.0",
  };
  if (includeContentType) headers["Content-Type"] = "application/json";
  return headers;
}

async function dataverseGet(config, accessToken, path) {
  return requestJson(`${config.environmentUrl}/api/data/v9.2/${path}`, {
    method: "GET",
    headers: dataverseHeaders(accessToken),
  });
}

async function dataversePatch(config, accessToken, path, body) {
  await requestJson(`${config.environmentUrl}/api/data/v9.2/${path}`, {
    method: "PATCH",
    headers: dataverseHeaders(accessToken, true),
    body: JSON.stringify(body),
  });
}

async function findEnvelopeByNintexId(config, envelopeId) {
  const token = await getDataverseToken(config);
  const filter = `cs_preparedenvelopeid eq '${odataString(envelopeId)}'`;
  const select = [
    "cs_envelopeid",
    "cs_name",
    "cs_preparedenvelopeid",
    "statecode",
    "statuscode",
    "cs_completeddate",
    "cs_cancelleddate",
    "cs_statuslastcheckedon",
  ].join(",");
  const result = await dataverseGet(
    config,
    token,
    `cs_envelopes?$select=${select}&$filter=${encodeURIComponent(filter)}&$top=2`,
  );
  return { token, rows: result?.value || [] };
}

async function updateEnvelope(config, accessToken, envelopeId, update) {
  await dataversePatch(config, accessToken, `cs_envelopes(${envelopeId})`, update);
}

module.exports = {
  findEnvelopeByNintexId,
  getDataverseToken,
  updateEnvelope,
};
