"use strict";

const { app } = require("@azure/functions");
const crypto = require("node:crypto");
const { loadConfig } = require("../lib/config");
const { findEnvelopeByNintexId, updateEnvelope } = require("../lib/dataverseClient");
const { HttpApiError } = require("../lib/http");
const { getEnvelopeStatus } = require("../lib/nintexClient");
const {
  buildEnvelopeUpdate,
  getNintexStatus,
  mapNintexStatus,
} = require("../lib/statusMapping");
const {
  extractEnvelopeId,
  extractPayloadStatus,
  readJsonBody,
} = require("../lib/payload");

function json(status, body) {
  return { status, jsonBody: body };
}

function queryFlag(request, name) {
  return ["1", "true", "yes"].includes(
    String(request.query.get(name) || "").toLowerCase(),
  );
}

function validateSecret(request, config) {
  const configuredSecret = config.webhook.secret;
  if (!configuredSecret) {
    if (config.webhook.allowMissingSecret) return;
    throw Object.assign(new Error("NINTEX_WEBHOOK_SECRET is not configured."), {
      responseStatus: 500,
    });
  }

  const providedSecret = request.headers.get("x-cs-webhook-secret");
  if (!safeEquals(providedSecret || "", configuredSecret)) {
    throw Object.assign(new Error("Webhook secret is missing or invalid."), {
      responseStatus: 401,
    });
  }
}

function safeEquals(left, right) {
  const leftBuffer = Buffer.from(String(left));
  const rightBuffer = Buffer.from(String(right));
  return (
    leftBuffer.length === rightBuffer.length &&
    crypto.timingSafeEqual(leftBuffer, rightBuffer)
  );
}

async function nintexStatusWebhook(request, context) {
  const checkedAt = new Date().toISOString();

  if (request.method === "GET") {
    return json(200, {
      ok: true,
      service: "nintex-status-webhook",
      checkedAt,
    });
  }

  try {
    const config = loadConfig();
    const payload = await readJsonBody(request);
    const validateOnly = queryFlag(request, "validateOnly");

    if (!validateOnly) {
      validateSecret(request, config);
    }

    const envelopeId =
      request.query.get("envelopeId") ||
      extractEnvelopeId(payload);
    const payloadStatus = extractPayloadStatus(payload);

    if (validateOnly) {
      return json(200, {
        ok: true,
        validateOnly: true,
        envelopeId,
        payloadStatus,
        checkedAt,
      });
    }

    if (!envelopeId) {
      return json(400, {
        ok: false,
        error: "Webhook payload did not include an envelope ID.",
      });
    }

    let nintexStatusResponse;
    try {
      nintexStatusResponse = await getEnvelopeStatus(config.nintex, envelopeId);
    } catch (error) {
      if (!config.webhook.allowPayloadStatusFallback || !payloadStatus) {
        throw error;
      }
      context.warn(
        `Nintex status lookup failed for ${envelopeId}; falling back to webhook payload status.`,
      );
      nintexStatusResponse = { result: { envelopeID: envelopeId, status: payloadStatus } };
    }

    const nintexStatus = getNintexStatus(nintexStatusResponse) || payloadStatus;
    const mappedStatus = mapNintexStatus(nintexStatus);
    const { token, rows } = await findEnvelopeByNintexId(
      config.dataverse,
      envelopeId,
    );

    if (rows.length === 0) {
      return json(404, {
        ok: false,
        error: "No cs_envelope row matched the Nintex envelope ID.",
        envelopeId,
        nintexStatus,
      });
    }

    if (rows.length > 1) {
      return json(409, {
        ok: false,
        error: "Multiple cs_envelope rows matched the Nintex envelope ID.",
        envelopeId,
        matchingRows: rows.map((row) => row.cs_envelopeid),
      });
    }

    const row = rows[0];
    const update = buildEnvelopeUpdate(
      row,
      nintexStatusResponse,
      mappedStatus,
      checkedAt,
      payload,
    );

    await updateEnvelope(config.dataverse, token, row.cs_envelopeid, update);

    return json(200, {
      ok: true,
      envelopeId,
      crmEnvelopeId: row.cs_envelopeid,
      previous: {
        statecode: row.statecode,
        statuscode: row.statuscode,
      },
      nintexStatus,
      mapped: {
        statecode: mappedStatus.statecode,
        statuscode: mappedStatus.statuscode,
      },
      updatedFields: Object.keys(update),
      checkedAt,
    });
  } catch (error) {
    const status =
      error.responseStatus ||
      (error instanceof HttpApiError && error.status >= 400 && error.status < 500
        ? 502
        : 500);
    context.error(error);
    return json(status, {
      ok: false,
      error: error.message,
      checkedAt,
    });
  }
}

app.http("nintexStatusWebhook", {
  methods: ["GET", "POST"],
  authLevel: "function",
  route: "nintex/status-webhook",
  handler: nintexStatusWebhook,
});

module.exports = {
  nintexStatusWebhook,
};
