"use strict";

function readSetting(name, aliases = [], required = true) {
  const names = [name, ...aliases];
  for (const key of names) {
    const value = process.env[key];
    if (value !== undefined && String(value).trim() !== "") {
      return String(value).trim();
    }
  }

  if (required) {
    throw new Error(`Missing required app setting: ${name}`);
  }
  return "";
}

function withoutTrailingSlash(value) {
  return value.replace(/\/+$/, "");
}

function readBoolean(name, defaultValue = false) {
  const value = process.env[name];
  if (value === undefined || value === "") return defaultValue;
  return ["1", "true", "yes", "on"].includes(String(value).toLowerCase());
}

function loadConfig() {
  return {
    dataverse: {
      environmentUrl: withoutTrailingSlash(
        readSetting("DATAVERSE_ENVIRONMENT_URL", ["EC_ENVIRONMENT_URL"]),
      ),
      tenantId: readSetting("DATAVERSE_TENANT_ID", ["EC_TENANT_ID"]),
      clientId: readSetting("DATAVERSE_CLIENT_ID", ["EC_CLIENT_ID"]),
      clientSecret: readSetting("DATAVERSE_CLIENT_SECRET", ["EC_CLIENT_SECRET"]),
    },
    nintex: {
      authUrl: withoutTrailingSlash(readSetting("NINTEX_AUTH_URL")),
      apiBaseUrl: withoutTrailingSlash(readSetting("NINTEX_API_BASE_URL")),
      apiUsername: readSetting("NINTEX_API_USERNAME"),
      apiKey: readSetting("NINTEX_API_KEY"),
      contextUsername: readSetting("NINTEX_CONTEXT_USERNAME"),
    },
    webhook: {
      secret: readSetting("NINTEX_WEBHOOK_SECRET", ["WEBHOOK_SHARED_SECRET"], false),
      allowMissingSecret: readBoolean("NINTEX_ALLOW_MISSING_WEBHOOK_SECRET", false),
      allowPayloadStatusFallback: readBoolean(
        "NINTEX_ALLOW_PAYLOAD_STATUS_FALLBACK",
        false,
      ),
    },
  };
}

module.exports = {
  loadConfig,
  readBoolean,
};
