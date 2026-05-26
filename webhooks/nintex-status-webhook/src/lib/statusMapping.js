"use strict";

const DATAVERSE_STATUS = Object.freeze({
  IN_PROCESS: { statecode: 0, statuscode: 717640003, terminal: false },
  COMPLETED: { statecode: 1, statuscode: 5, terminal: true },
  CANCELLED: { statecode: 1, statuscode: 8, terminal: true },
  DECLINED: { statecode: 1, statuscode: 10, terminal: true },
  EXPIRED: { statecode: 1, statuscode: 11, terminal: true },
  STALED: { statecode: 1, statuscode: 717640008, terminal: true },
  SIGNER_AUTH_FAILED: { statecode: 1, statuscode: 717640009, terminal: true },
});

function normalizeStatus(status) {
  return String(status || "")
    .replace(/[^a-z0-9]/gi, "")
    .toLowerCase();
}

function mapNintexStatus(status) {
  const normalized = normalizeStatus(status);

  switch (normalized) {
    case "completed":
    case "complete":
    case "eco":
    case "envelopecompleted":
      return { ...DATAVERSE_STATUS.COMPLETED, normalized };

    case "cancelled":
    case "canceled":
    case "eca":
    case "envelopecancelled":
    case "envelopecanceled":
      return { ...DATAVERSE_STATUS.CANCELLED, normalized };

    case "declined":
    case "esd":
    case "envelopedeclined":
      return { ...DATAVERSE_STATUS.DECLINED, normalized };

    case "expired":
    case "eex":
    case "envelopeexpired":
      return { ...DATAVERSE_STATUS.EXPIRED, normalized };

    case "staled":
    case "stale":
    case "envelopestaled":
      return { ...DATAVERSE_STATUS.STALED, normalized };

    case "signerauthenticationfailed":
    case "saf":
    case "envelopesignerauthenticationfailed":
      return { ...DATAVERSE_STATUS.SIGNER_AUTH_FAILED, normalized };

    default:
      return { ...DATAVERSE_STATUS.IN_PROCESS, normalized };
  }
}

function getNintexResult(statusResponse) {
  return statusResponse?.result || statusResponse || {};
}

function getNintexStatus(statusResponse) {
  const result = getNintexResult(statusResponse);
  return result.status || result.StatusType || result.statusType || "";
}

function getDocumentStatusDate(statusResponse, statusName) {
  const result = getNintexResult(statusResponse);
  const expected = normalizeStatus(statusName);
  const documentList = Array.isArray(result.documentList) ? result.documentList : [];
  const match = documentList.find((document) => {
    return normalizeStatus(document?.status?.statusType) === expected;
  });
  return match?.status?.statusDate || "";
}

function getTerminalDate(statusResponse, mapped, webhookPayload, refreshTime) {
  const result = getNintexResult(statusResponse);
  const webhook = webhookPayload || {};

  if (mapped.statuscode === DATAVERSE_STATUS.COMPLETED.statuscode) {
    return (
      result.completedDate ||
      result.completionDate ||
      webhook.completedDate ||
      webhook.envelopeCompletionDate ||
      webhook["Envelope Completion Date"] ||
      getDocumentStatusDate(statusResponse, "completed") ||
      refreshTime
    );
  }

  if (mapped.statuscode === DATAVERSE_STATUS.CANCELLED.statuscode) {
    return (
      result.cancelledDate ||
      result.canceledDate ||
      webhook.cancelledDate ||
      webhook.canceledDate ||
      webhook.envelopeCancelledDate ||
      webhook["Envelope Cancelled Date"] ||
      refreshTime
    );
  }

  return "";
}

function buildEnvelopeUpdate(row, statusResponse, mapped, refreshTime, webhookPayload) {
  const update = {
    statecode: mapped.statecode,
    statuscode: mapped.statuscode,
    cs_statuslastcheckedon: refreshTime,
  };

  const terminalDate = getTerminalDate(statusResponse, mapped, webhookPayload, refreshTime);
  if (
    mapped.statuscode === DATAVERSE_STATUS.COMPLETED.statuscode &&
    terminalDate &&
    !row?.cs_completeddate
  ) {
    update.cs_completeddate = terminalDate;
  }

  if (
    mapped.statuscode === DATAVERSE_STATUS.CANCELLED.statuscode &&
    terminalDate &&
    !row?.cs_cancelleddate
  ) {
    update.cs_cancelleddate = terminalDate;
  }

  return update;
}

module.exports = {
  DATAVERSE_STATUS,
  buildEnvelopeUpdate,
  getNintexResult,
  getNintexStatus,
  mapNintexStatus,
  normalizeStatus,
};
