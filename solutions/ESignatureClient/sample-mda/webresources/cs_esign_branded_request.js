/*
 * cs_esign_branded_request.js  —  SAMPLE model-driven-app command script.
 *
 * Wired to a command-bar button ("Send branded envelope") on the
 * cs_signaturerequest form. On click it:
 *   1. reads Title / Description / Signee 1 / Signee 2 / Template / Party logo,
 *   2. loads the template PDF (TemplateSourcePDF annotation) + its layout
 *      (cs_templatejson),
 *   3. composites the uploaded logo top-right of page 1 with pdf-lib IN THE
 *      BROWSER (no plugin assembly, no PDF service),
 *   4. creates a cs_envelope + EnvelopeSourcePDF annotation + recipients,
 *   5. sets cs_adhocsend = true so the broker "ESign - Send Ad-hoc Envelope"
 *      flow submits it.
 *
 * Dependencies (web resources, load order matters — see README):
 *   cs_/lib/pdf-lib.min.js   (PDFLib UMD global)
 *   cs_/scripts/cs_esign_branded_request.js   (this file)
 *
 * NOTE: this sample assumes the cs_envelope / cs_template tables live in the
 * SAME environment as this app (dev). In a real client environment they are in
 * the broker env — point the create/annotation calls at the broker Web API
 * (see README "Cross-environment").
 */
"use strict";
var ESign = ESign || {};

ESign.sendBrandedEnvelope = function (primaryControl) {
  var formContext = primaryControl;
  var Xrm = window.parent.Xrm || window.Xrm;

  function fail(msg, e) {
    console.error("[ESign] " + msg, e);
    formContext.ui.setFormNotification((msg + (e && e.message ? (": " + e.message) : "")), "ERROR", "esign");
  }
  function info(msg) { formContext.ui.setFormNotification(msg, "INFO", "esign"); }

  function b64ToBytes(b64) {
    var bin = atob(b64), len = bin.length, bytes = new Uint8Array(len);
    for (var i = 0; i < len; i++) bytes[i] = bin.charCodeAt(i);
    return bytes;
  }
  function bytesToB64(bytes) {
    var bin = "", chunk = 0x8000;
    for (var i = 0; i < bytes.length; i += chunk) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
    return btoa(bin);
  }

  (async function () {
    try {
      if (typeof PDFLib === "undefined") { fail("pdf-lib web resource not loaded (cs_/lib/pdf-lib.min.js)"); return; }
      var id = formContext.data.entity.getId().replace(/[{}]/g, "");

      // save pending edits first so the file column + lookups are persisted
      if (formContext.data.entity.getIsDirty()) { await formContext.data.save(); }

      info("Preparing branded envelope…");

      var g = function (n) { var a = formContext.getAttribute(n); return a ? a.getValue() : null; };
      var title = g("cs_title") || "Signature request";
      var tplLk = g("cs_template"); var s1 = g("cs_signee1"); var s2 = g("cs_signee2");
      if (!tplLk || !tplLk[0]) { fail("Pick a Template first."); return; }
      if (!s1 || !s1[0]) { fail("Pick Signee 1 first."); return; }
      var templateId = tplLk[0].id.replace(/[{}]/g, "");

      // 1. template json (layout + signer labels)
      var tpl = await Xrm.WebApi.retrieveRecord("cs_template", templateId, "?$select=cs_name,cs_templatejson");
      var tj = {}; try { tj = JSON.parse(tpl.cs_templatejson || "{}"); } catch (e) {}
      var signers = (tj.signers && tj.signers.length) ? tj.signers : [{ label: "Primary Signer" }];

      // 2. template source PDF (annotation)
      var notes = await Xrm.WebApi.retrieveMultipleRecords("annotation",
        "?$select=documentbody&$filter=_objectid_value eq " + templateId + " and subject eq 'TemplateSourcePDF'&$top=1");
      if (!notes.entities.length || !notes.entities[0].documentbody) { fail("Template has no TemplateSourcePDF to brand."); return; }
      var pdfBytes = b64ToBytes(notes.entities[0].documentbody);

      // 3. party logo (File column) — download the bytes
      var logoBytes = null, logoType = "";
      try {
        var apiUrl = Xrm.Utility.getGlobalContext().getClientUrl() +
          "/api/data/v9.2/cs_signaturerequests(" + id + ")/cs_partylogo/$value";
        var resp = await fetch(apiUrl, { headers: { "Accept": "application/octet-stream" }, credentials: "include" });
        if (resp.ok) { logoBytes = new Uint8Array(await resp.arrayBuffer()); logoType = resp.headers.get("content-type") || ""; }
      } catch (e) { console.warn("[ESign] no logo file", e); }

      // 4. composite with pdf-lib
      var doc = await PDFLib.PDFDocument.load(pdfBytes.buffer);
      if (logoBytes && logoBytes.length) {
        var img;
        try { img = (logoType.indexOf("png") >= 0) ? await doc.embedPng(logoBytes) : await doc.embedJpg(logoBytes); }
        catch (e) { try { img = await doc.embedPng(logoBytes); } catch (e2) { img = await doc.embedJpg(logoBytes); } }
        var page = doc.getPages()[0];
        var pw = page.getWidth(), ph = page.getHeight();
        var boxW = 90, scale = boxW / img.width, boxH = img.height * scale;
        page.drawImage(img, { x: pw - boxW - 36, y: ph - boxH - 36, width: boxW, height: boxH });
      }
      var brandedB64 = bytesToB64(await doc.save());

      // 5. recipients from the two contact lookups (match template signer labels by order)
      async function contact(lk, roleLabel) {
        if (!lk || !lk[0]) return null;
        var cid = lk[0].id.replace(/[{}]/g, "");
        var c = await Xrm.WebApi.retrieveRecord("contact", cid, "?$select=fullname,emailaddress1");
        return { role: roleLabel, name: c.fullname || lk[0].name || "Signer", email: c.emailaddress1 || "" };
      }
      var recipients = [];
      var r1 = await contact(s1, (signers[0] && signers[0].label) || "Primary Signer"); if (r1) recipients.push(r1);
      if (signers[1]) { var r2 = await contact(s2, signers[1].label); if (r2) recipients.push(r2); }

      // 6. create the envelope (same-env sample)
      var env = await Xrm.WebApi.createRecord("cs_envelope", {
        cs_name: title, cs_subject: title,
        cs_templateid: templateId,
        cs_envelopejson: JSON.stringify({ templateId: templateId, templateName: tpl.cs_name, recipients: recipients }),
        statuscode: 1
      });
      var envId = env.id.replace(/[{}]/g, "");

      // 7. attach the branded PDF
      await Xrm.WebApi.createRecord("annotation", {
        subject: "EnvelopeSourcePDF", filename: "branded.pdf", mimetype: "application/pdf",
        documentbody: brandedB64,
        "objectid_cs_envelope@odata.bind": "/cs_envelopes(" + envId + ")"
      });

      // 8. flip cs_adhocsend -> broker flow submits
      await Xrm.WebApi.updateRecord("cs_envelope", envId, { cs_adhocsend: true });

      formContext.ui.clearFormNotification("esign");
      info("Branded envelope sent. Track it in E-Sign ▸ Envelopes (id " + envId.slice(0, 8) + ").");
    } catch (e) { fail("Could not send branded envelope", e); }
  })();
};

// Optional: enable/disable the button. Returns true when a template + signee 1 are set.
ESign.canSend = function (primaryControl) {
  try {
    var fc = primaryControl;
    var t = fc.getAttribute("cs_template") && fc.getAttribute("cs_template").getValue();
    var s = fc.getAttribute("cs_signee1") && fc.getAttribute("cs_signee1").getValue();
    return !!(t && s);
  } catch (e) { return true; }
};
