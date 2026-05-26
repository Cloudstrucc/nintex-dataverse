"use strict";

const { requestJson } = require("./http");

async function getNintexToken(config) {
  const response = await requestJson(`${config.authUrl}/authentication/apiUser`, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      request: {
        apiUsername: config.apiUsername,
        key: config.apiKey,
        contextUsername: config.contextUsername,
        sessionLengthInMinutes: 60,
      },
    }),
  });

  const token = response?.result?.token || response?.token;
  if (!token) {
    throw new Error("Nintex authentication response did not include a token.");
  }

  return token;
}

async function getEnvelopeStatus(config, envelopeId) {
  const token = await getNintexToken(config);
  return requestJson(`${config.apiBaseUrl}/envelopes/${encodeURIComponent(envelopeId)}/status`, {
    method: "GET",
    headers: {
      Authorization: `bearer ${token}`,
      "X-AS-UserContext": config.contextUsername,
      Accept: "application/json",
    },
  });
}

module.exports = {
  getEnvelopeStatus,
  getNintexToken,
};
