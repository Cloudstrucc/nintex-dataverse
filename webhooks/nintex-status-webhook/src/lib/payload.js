"use strict";

function valueAtPath(source, path) {
  let current = source;
  for (const part of path) {
    if (current == null || typeof current !== "object") return undefined;
    current = current[part];
  }
  return current;
}

function firstValue(source, paths) {
  for (const path of paths) {
    const value = valueAtPath(source, path);
    if (value !== undefined && value !== null && String(value).trim() !== "") {
      return String(value).trim();
    }
  }
  return "";
}

function extractEnvelopeId(payload) {
  return firstValue(payload, [
    ["envelopeId"],
    ["envelopeID"],
    ["EnvelopeID"],
    ["EnvelopeId"],
    ["Envelope ID"],
    ["envelope", "id"],
    ["envelope", "envelopeId"],
    ["envelope", "envelopeID"],
    ["result", "envelopeID"],
    ["result", "envelopeId"],
    ["data", "envelopeId"],
    ["data", "envelopeID"],
  ]);
}

function extractPayloadStatus(payload) {
  return firstValue(payload, [
    ["status"],
    ["Status"],
    ["statusType"],
    ["envelopeStatus"],
    ["EnvelopeStatus"],
    ["Envelope Status"],
    ["envelope", "status"],
    ["result", "status"],
    ["data", "status"],
  ]);
}

async function readJsonBody(request) {
  const text = await request.text();
  if (!text) return {};

  try {
    return JSON.parse(text);
  } catch {
    return { rawBody: text };
  }
}

module.exports = {
  extractEnvelopeId,
  extractPayloadStatus,
  readJsonBody,
};
