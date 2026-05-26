"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  buildEnvelopeUpdate,
  getNintexStatus,
  mapNintexStatus,
} = require("../src/lib/statusMapping");
const { extractEnvelopeId, extractPayloadStatus } = require("../src/lib/payload");

test("maps completed variants to inactive Completed", () => {
  for (const status of ["completed", "Completed", "ECO", "Envelope Completed"]) {
    assert.deepEqual(
      pickStatus(mapNintexStatus(status)),
      { statecode: 1, statuscode: 5 },
    );
  }
});

test("maps terminal failure statuses", () => {
  assert.deepEqual(
    pickStatus(mapNintexStatus("cancelled")),
    { statecode: 1, statuscode: 8 },
  );
  assert.deepEqual(
    pickStatus(mapNintexStatus("declined")),
    { statecode: 1, statuscode: 10 },
  );
  assert.deepEqual(
    pickStatus(mapNintexStatus("expired")),
    { statecode: 1, statuscode: 11 },
  );
  assert.deepEqual(
    pickStatus(mapNintexStatus("Signer Authentication Failed")),
    { statecode: 1, statuscode: 717640009 },
  );
});

test("maps unknown or in-progress statuses to active In Process", () => {
  for (const status of ["iN_PROGRESS", "SigningStepInProgress", "", undefined]) {
    assert.deepEqual(
      pickStatus(mapNintexStatus(status)),
      { statecode: 0, statuscode: 717640003 },
    );
  }
});

test("extracts envelope and status from common DocumentTRAK payload shapes", () => {
  const payload = {
    "Envelope ID": "219a9b3b-f306-495c-9f68-b45600d97518",
    "Envelope Status": "ECO",
  };
  assert.equal(
    extractEnvelopeId(payload),
    "219a9b3b-f306-495c-9f68-b45600d97518",
  );
  assert.equal(extractPayloadStatus(payload), "ECO");
});

test("builds a completed update without empty terminal date fields", () => {
  const response = {
    result: {
      status: "completed",
      documentList: [
        {
          status: {
            statusType: "completed",
            statusDate: "2026-05-26T13:38:40.917",
          },
        },
      ],
    },
  };
  const mapped = mapNintexStatus(getNintexStatus(response));
  const update = buildEnvelopeUpdate({}, response, mapped, "2026-05-26T13:39:00Z", {});

  assert.equal(update.statecode, 1);
  assert.equal(update.statuscode, 5);
  assert.equal(update.cs_completeddate, "2026-05-26T13:38:40.917");
  assert.equal("cs_cancelleddate" in update, false);
});

function pickStatus(mapped) {
  return {
    statecode: mapped.statecode,
    statuscode: mapped.statuscode,
  };
}
