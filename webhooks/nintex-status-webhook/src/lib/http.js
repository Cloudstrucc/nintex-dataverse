"use strict";

class HttpApiError extends Error {
  constructor(message, status, detail) {
    super(message);
    this.name = "HttpApiError";
    this.status = status;
    this.detail = detail;
  }
}

async function requestJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  let body = null;

  if (text) {
    try {
      body = JSON.parse(text);
    } catch {
      body = { raw: text };
    }
  }

  if (!response.ok) {
    const message =
      body?.error?.message ||
      body?.error_description ||
      body?.message ||
      `${response.status} ${response.statusText}`;
    throw new HttpApiError(message, response.status, body);
  }

  return body;
}

function odataString(value) {
  return String(value).replace(/'/g, "''");
}

module.exports = {
  HttpApiError,
  odataString,
  requestJson,
};
