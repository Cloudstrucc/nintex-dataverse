#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { randomUUID } = require("crypto");

const repoRoot = path.resolve(__dirname, "..");
const envPath = path.join(repoRoot, ".env");
const dryRun = process.argv.includes("--dry-run");

const SOLUTION_UNIQUE_NAME = "nintex";
const COMPONENT_TYPES = {
  savedQuery: 26,
  systemForm: 60,
};

const CONTROL_CLASS = {
  default: "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}",
  string: "{4273EDBD-AC1D-40d3-9FB2-095C621B552D}",
  memo: "{E0DECE4B-6FC8-4A8F-A065-082708572369}",
  lookup: "{270BD3DB-D9AF-4782-9025-509E298DEC0A}",
  owner: "{270BD3DB-D9AF-4782-9025-509E298DEC0A}",
  datetime: "{5B773807-9FB2-42DB-97C3-7A91EFF8ADFF}",
  picklist: "{3EF39988-22BB-4F0B-BBBE-64B5A3748AEE}",
  boolean: "{67FAC785-CD58-4f9f-ABB3-4B7DDC6ED5ED}",
  number: "{C6D124CA-7EDA-4A60-AEA9-7FB8D318B68F}",
  status: "{5D68B988-0661-4db2-BC3E-17598AD3BE6C}",
};

const STATUS_HEADER = ["", "", "statuscode"];

const ENTITIES = {
  cs_envelope: {
    label: "Envelope",
    fields: {
      left: [
        ["Summary", [
          "cs_name",
          "cs_subject",
          "cs_templateid",
          "cs_preparedenvelopeid",
          "cs_sentdate",
          "cs_completeddate",
          "cs_cancelleddate",
          "cs_expirationdate",
        ]],
        ["Status Check", [
          "cs_statuscheckrequestedon",
          "cs_statuslastcheckedon",
          "cs_status",
          "cs_iscancelled",
          "cs_requesthistory",
        ]],
      ],
      right: [
        ["Delivery", [
          "cs_message",
          "cs_daystoexpire",
          "cs_reminderfrequency",
          "cs_processingmode",
          "cs_redirecturl",
          "cs_callbackurl",
        ]],
        ["Ownership", ["ownerid", "createdon", "modifiedon"]],
      ],
    },
    extraTabs: [
      {
        label: "Diagnostics",
        columns: 1,
        sections: [
          ["Payloads", ["cs_envelopejson", "cs_requestbody", "cs_responsebody"]],
        ],
      },
    ],
    subgrids: [
      ["Documents", "cs_document", "cs_envelope_cs_envelopelookup_cs_document"],
      ["Signers", "cs_signer", "cs_envelope_cs_envelopelookup_cs_signer"],
      ["Fields", "cs_field", "cs_envelope_cs_envelopelookup_cs_field"],
      ["Sender Inputs", "cs_senderinput", "cs_envelope_cs_envelopelookup_cs_senderinput"],
      [
        "Email Notifications",
        "cs_emailnotification",
        "cs_envelope_cs_envelopelookup_cs_emailnotification",
      ],
      ["Webhooks", "cs_webhook", "cs_envelope_cs_envelopelookup_cs_webhook"],
      ["History", "cs_envelopehistory", "cs_envelope_cs_envelopelookup_cs_envelopehistory"],
      ["Access Links", "cs_accesslink", "cs_envelope_cs_envelopelookup_cs_accesslink"],
    ],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_subject",
      "cs_preparedenvelopeid",
      "cs_templateid",
      "cs_statuslastcheckedon",
      "modifiedon",
    ],
  },
  cs_document: {
    label: "Document",
    fields: {
      left: [["Document", [
        "cs_name",
        "cs_filename",
        "cs_fileextension",
        "cs_documenttype",
        "cs_documentorder",
        "cs_pagecount",
      ]]],
      right: [["Envelope", [
        "cs_envelopelookup",
        "cs_envelopeid",
        "cs_documentid",
        "cs_envelopesignerid",
        "cs_requestsignedcopy",
        "ownerid",
      ]]],
    },
    extraTabs: [["Content", [["Stored Content", ["cs_filecontent", "cs_signedcontent"]]]]],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_filename",
      "cs_documenttype",
      "cs_documentorder",
      "cs_pagecount",
      "cs_requestsignedcopy",
    ],
  },
  cs_signer: {
    label: "Signer",
    fields: {
      left: [["Signer", [
        "cs_name",
        "cs_fullname",
        "cs_email",
        "cs_signerorder",
        "cs_signerstatus",
        "cs_envelopelookup",
        "cs_envelopesignerid",
      ]]],
      right: [["Authentication & Activity", [
        "cs_authenticationtype",
        "cs_accesscode",
        "cs_language",
        "cs_phonenumber",
        "cs_sendreminder",
        "cs_vieweddate",
        "cs_signeddate",
      ]]],
    },
    extraTabs: [
      ["Details", [
        ["Delegation & Decline", [
          "cs_delegatedto",
          "cs_declineddate",
          "cs_declinedreason",
          "cs_signinglink",
          "cs_signatureimage",
        ]],
      ]],
    ],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_fullname",
      "cs_email",
      "cs_signerorder",
      "cs_signerstatus",
      "cs_signeddate",
    ],
  },
  cs_field: {
    label: "Field",
    fields: {
      left: [["Field", [
        "cs_name",
        "cs_fieldtype",
        "cs_inputtype",
        "cs_value",
        "cs_defaultvalue",
        "cs_documentid",
        "cs_signerid",
        "cs_envelopelookup",
      ]]],
      right: [["Placement & Validation", [
        "cs_pagenumber",
        "cs_positionx",
        "cs_positiony",
        "cs_width",
        "cs_height",
        "cs_minlength",
        "cs_maxlength",
        "cs_validationregex",
      ]]],
    },
    extraTabs: [["Instructions", [["Instructions", ["cs_groupname", "cs_instructions"]]]]],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_fieldtype",
      "cs_inputtype",
      "cs_documentid",
      "cs_signerid",
      "cs_value",
    ],
  },
  cs_template: {
    label: "Template",
    fields: {
      left: [["Template", [
        "cs_name",
        "cs_category",
        "cs_isactive",
        "cs_createddate",
        "cs_modifieddate",
      ]]],
      right: [["Description", ["cs_description", "ownerid", "createdon", "modifiedon"]]],
    },
    extraTabs: [["Template JSON", [["Template JSON", ["cs_templatejson"]]]]],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_category",
      "cs_isactive",
      "cs_createddate",
      "cs_modifieddate",
    ],
  },
  cs_senderinput: {
    label: "Sender Input",
    fields: {
      left: [["Input", ["cs_name", "cs_inputname", "cs_inputtype", "cs_inputvalue"]]],
      right: [["Template & Envelope", [
        "cs_templateid",
        "cs_envelopelookup",
        "cs_envelopeid",
        "ownerid",
      ]]],
    },
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_inputname",
      "cs_inputtype",
      "cs_templateid",
      "cs_inputvalue",
    ],
  },
  cs_emailnotification: {
    label: "Email Notification",
    fields: {
      left: [["Notification", [
        "cs_name",
        "cs_stage",
        "cs_step",
        "cs_subject",
        "cs_recipients",
        "cs_envelopelookup",
      ]]],
      right: [["Design & Message", [
        "cs_emaildesignid",
        "cs_emaildesignsetid",
        "cs_custommessage",
        "cs_body",
      ]]],
    },
    viewColumns: ["cs_name", "statuscode", "cs_stage", "cs_step", "cs_subject", "cs_recipients"],
  },
  cs_webhook: {
    label: "Webhook",
    fields: {
      left: [["Event", [
        "cs_name",
        "cs_eventtype",
        "cs_eventdate",
        "cs_processeddate",
        "cs_envelopelookup",
      ]]],
      right: [["Payload & Errors", ["cs_payload", "cs_errorlog"]]],
    },
    viewColumns: ["cs_name", "statuscode", "cs_eventtype", "cs_eventdate", "cs_processeddate"],
  },
  cs_envelopehistory: {
    label: "Envelope History",
    fields: {
      left: [["Event", [
        "cs_name",
        "cs_eventtype",
        "cs_eventdate",
        "cs_username",
        "cs_ipaddress",
        "cs_envelopelookup",
      ]]],
      right: [["Description", ["cs_description"]]],
    },
    viewColumns: ["cs_name", "statuscode", "cs_eventtype", "cs_eventdate", "cs_username", "cs_ipaddress"],
  },
  cs_accesslink: {
    label: "Access Link",
    fields: {
      left: [["Link", [
        "cs_name",
        "cs_linktype",
        "cs_documenttype",
        "cs_linkurl",
        "cs_expiresat",
      ]]],
      right: [["Envelope", [
        "cs_envelopelookup",
        "cs_envelopeid",
        "cs_signerid",
        "ownerid",
      ]]],
    },
    viewColumns: ["cs_name", "statuscode", "cs_linktype", "cs_documenttype", "cs_signerid", "cs_expiresat"],
  },
  cs_authtoken: {
    label: "Auth Token",
    fields: {
      left: [["Token", [
        "cs_name",
        "cs_apiusername",
        "cs_contextusername",
        "cs_issuedat",
        "cs_expiresat",
        "cs_sessionlength",
        "cs_isactive",
      ]]],
      right: [["Ownership", ["ownerid", "createdon", "modifiedon"]]],
    },
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_apiusername",
      "cs_contextusername",
      "cs_expiresat",
      "cs_isactive",
    ],
  },
  cs_apirequest: {
    label: "API Request",
    fields: {
      left: [["Request", [
        "cs_name",
        "cs_method",
        "cs_endpoint",
        "cs_requestdate",
        "cs_requestid",
        "cs_authtoken",
      ]]],
      right: [["Response", [
        "cs_statuscode",
        "cs_responsetime",
        "cs_errormessage",
        "ownerid",
      ]]],
    },
    extraTabs: [["Payloads", [["Payloads", ["cs_requestbody", "cs_responsebody"]]]]],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_method",
      "cs_endpoint",
      "cs_statuscode",
      "cs_requestdate",
      "cs_responsetime",
    ],
  },
  cs_useraccount: {
    label: "User Account",
    fields: {
      left: [["User", ["cs_name", "cs_username", "cs_accountid", "cs_contextidentifier"]]],
      right: [["Environment", ["cs_environmentname", "cs_environmentid", "ownerid"]]],
    },
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_username",
      "cs_accountid",
      "cs_environmentname",
      "cs_environmentid",
    ],
  },
  cs_assuresign: {
    label: "AssureSign",
    fields: {
      left: [["Request", [
        "cs_name",
        "cs_formselection",
        "cs_requestor",
        "cs_completeddata",
      ]]],
      right: [["Contacts & Signees", [
        "cs_contact1",
        "cs_contact2",
        "cs_contact3",
        "cs_contact4",
        "cs_signee1",
        "cs_signee2",
      ]]],
    },
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_formselection",
      "cs_requestor",
      "cs_completeddata",
    ],
  },
  cs_digitalsignature: {
    label: "Digital Signature",
    fields: {
      left: [["Request", [
        "cs_name",
        "cs_documentname",
        "cs_recipientname",
        "cs_recipientemail",
        "cs_requestdate",
        "cs_signaturedate",
        "cs_expirydate",
      ]]],
      right: [["Nintex", ["cs_nintexrequestid", "cs_callbackurl", "ownerid"]]],
    },
    extraTabs: [["Documents", [["Document Content", ["cs_documentcontent", "cs_signaturedocument"]]]]],
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_documentname",
      "cs_recipientname",
      "cs_recipientemail",
      "cs_signaturedate",
    ],
  },
  cs_item: {
    label: "Item",
    fields: {
      left: [["Item", ["cs_name", "cs_choicefield", "cs_datetimefield"]]],
      right: [["Values", ["cs_emailfield", "cs_lookupfield", "cs_richtextfield", "ownerid"]]],
    },
    viewColumns: [
      "cs_name",
      "statuscode",
      "cs_choicefield",
      "cs_datetimefield",
      "cs_emailfield",
    ],
  },
};

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

function guid() {
  return `{${randomUUID()}}`;
}

function escapeXml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function label(text) {
  return `<labels><label description="${escapeXml(text)}" languagecode="1033" /></labels>`;
}

function isFieldPresent(entityMeta, field) {
  return Boolean(entityMeta.attributes[field]);
}

function fieldLabel(entityMeta, field) {
  if (!field) return "";
  return entityMeta.attributes[field]?.label || field;
}

function controlClass(entityMeta, field) {
  const type = entityMeta.attributes[field]?.type;
  if (field === "statuscode") return CONTROL_CLASS.status;
  if (field === "statecode") return CONTROL_CLASS.picklist;
  if (type === "Memo") return CONTROL_CLASS.memo;
  if (type === "Lookup" || type === "Customer") return CONTROL_CLASS.lookup;
  if (type === "Owner") return CONTROL_CLASS.owner;
  if (type === "DateTime") return CONTROL_CLASS.datetime;
  if (type === "Picklist") return CONTROL_CLASS.picklist;
  if (type === "Boolean") return CONTROL_CLASS.boolean;
  if (["Integer", "Decimal", "Double", "Money", "BigInt"].includes(type)) {
    return CONTROL_CLASS.number;
  }
  if (type === "Status") return CONTROL_CLASS.status;
  if (type === "State") return CONTROL_CLASS.picklist;
  return CONTROL_CLASS.default;
}

function fieldCell(entityMeta, field, options = {}) {
  const cellId = guid();
  if (!field) {
    return `<cell id="${cellId}" showlabel="false" locklevel="0">${label("")}</cell>`;
  }
  const controlId = options.header ? `header_${field}` : field;
  const disabled = options.disabled ? ' disabled="true"' : ' disabled="false"';
  return [
    `<cell id="${cellId}" showlabel="true" locklevel="0">`,
    label(fieldLabel(entityMeta, field)),
    `<control id="${controlId}" classid="${controlClass(entityMeta, field)}" datafieldname="${field}"${disabled} />`,
    "</cell>",
  ].join("");
}

function fieldRows(entityMeta, fields) {
  return fields
    .filter((field) => isFieldPresent(entityMeta, field))
    .map((field) => `<row>${fieldCell(entityMeta, field)}</row>`)
    .join("");
}

function sectionXml(entityMeta, sectionLabel, fields) {
  const rows = fieldRows(entityMeta, fields);
  if (!rows) return "";
  return [
    `<section name="${safeName(sectionLabel)}" showlabel="true" showbar="false" columns="1" IsUserDefined="1" id="${guid()}" celllabelposition="Left" labelwidth="130">`,
    label(sectionLabel),
    `<rows>${rows}</rows>`,
    "</section>",
  ].join("");
}

function columnsXml(entityMeta, fieldConfig) {
  const leftSections = fieldConfig.left
    .map(([name, fields]) => sectionXml(entityMeta, name, fields))
    .join("");
  const rightSections = fieldConfig.right
    .map(([name, fields]) => sectionXml(entityMeta, name, fields))
    .join("");
  return [
    '<columns>',
    `<column width="50%"><sections>${leftSections}</sections></column>`,
    `<column width="50%"><sections>${rightSections}</sections></column>`,
    '</columns>',
  ].join("");
}

function normalizeExtraTab(tab) {
  if (Array.isArray(tab)) {
    const [tabLabel, sections] = tab;
    return { label: tabLabel, columns: 1, sections };
  }
  return tab;
}

function regularTabXml(entityMeta, tabLabel, sections, columns = 1) {
  const sectionXmls = sections
    .map(([name, fields]) => sectionXml(entityMeta, name, fields))
    .join("");
  if (!sectionXmls) return "";

  const columnCount = Math.min(Math.max(columns, 1), 2);
  if (columnCount === 2) {
    const midpoint = Math.ceil(sections.length / 2);
    return [
      `<tab name="${safeName(tabLabel)}" verticallayout="true" id="${guid()}" IsUserDefined="1" showlabel="true" expanded="true">`,
      label(tabLabel),
      "<columns>",
      `<column width="50%"><sections>${sections
        .slice(0, midpoint)
        .map(([name, fields]) => sectionXml(entityMeta, name, fields))
        .join("")}</sections></column>`,
      `<column width="50%"><sections>${sections
        .slice(midpoint)
        .map(([name, fields]) => sectionXml(entityMeta, name, fields))
        .join("")}</sections></column>`,
      "</columns>",
      "</tab>",
    ].join("");
  }

  return [
    `<tab name="${safeName(tabLabel)}" verticallayout="true" id="${guid()}" IsUserDefined="1" showlabel="true" expanded="false">`,
    label(tabLabel),
    `<columns><column width="100%"><sections>${sectionXmls}</sections></column></columns>`,
    "</tab>",
  ].join("");
}

function subgridParameters(childEntity, relationshipName, viewId) {
  return [
    "<RecordsPerPage>10</RecordsPerPage>",
    "<AutoExpand>Fixed</AutoExpand>",
    "<EnableQuickFind>false</EnableQuickFind>",
    "<EnableViewPicker>false</EnableViewPicker>",
    "<EnableChartPicker>false</EnableChartPicker>",
    "<ChartGridMode>Grid</ChartGridMode>",
    `<TargetEntityType>${childEntity}</TargetEntityType>`,
    `<ViewId>{${viewId}}</ViewId>`,
    `<ViewIds>{${viewId}}</ViewIds>`,
    `<RelationshipName>${relationshipName}</RelationshipName>`,
    "<IsUserView>false</IsUserView>",
  ].join("");
}

function subgridControlDescription(uniqueId, childEntity, relationshipName, viewId) {
  const gridControls = [0, 1, 2]
    .map((formFactor) => [
      `<customControl formFactor="${formFactor}" name="MscrmControls.Grid.ReadOnlyGrid">`,
      "<parameters>",
      '<data-set name="Grid">',
      `<ViewId>{${viewId}}</ViewId>`,
      "<IsUserView>false</IsUserView>",
      `<RelationshipName>${relationshipName}</RelationshipName>`,
      `<TargetEntityType>${childEntity}</TargetEntityType>`,
      "<EnableViewPicker>false</EnableViewPicker>",
      `<FilteredViewIds>{${viewId}}</FilteredViewIds>`,
      "</data-set>",
      '<EnableGroupBy static="true" type="Enum">no</EnableGroupBy>',
      '<EnableEditing static="true" type="Enum">no</EnableEditing>',
      '<ReflowBehavior static="true" type="Enum">ListOnly</ReflowBehavior>',
      '<ListLayoutDirection static="true" type="Enum">Horizontal</ListLayoutDirection>',
      '<EnableSubGridAutoCollapse static="true" type="Enum">false</EnableSubGridAutoCollapse>',
      '<EnableFiltering static="true" type="Enum">no</EnableFiltering>',
      "</parameters>",
      "</customControl>",
    ].join(""))
    .join("");

  return [
    `<controlDescription forControl="${uniqueId}">`,
    '<customControl id="{E7A81278-8635-4D9E-8D4D-59480B391C5B}">',
    `<parameters>${subgridParameters(childEntity, relationshipName, viewId)}</parameters>`,
    "</customControl>",
    gridControls,
    "</controlDescription>",
  ].join("");
}

function subgridXml(labelText, childEntity, relationshipName, viewId, descriptions) {
  const controlName = safeName(`${childEntity}_${labelText}`);
  const uniqueId = guid();
  descriptions.push(
    subgridControlDescription(uniqueId, childEntity, relationshipName, viewId),
  );
  return [
    `<section name="${safeName(labelText)}" showlabel="true" showbar="false" columns="1" IsUserDefined="1" id="${guid()}" celllabelposition="Left" labelwidth="130">`,
    label(labelText),
    "<rows>",
    `<row><cell id="${guid()}" rowspan="8" colspan="1" auto="false" showlabel="false">`,
    label(labelText),
    `<control indicationOfSubgrid="true" id="${controlName}" classid="{F9A8A302-114E-466A-B582-6771B2AE0D92}" uniqueid="${uniqueId}">`,
    `<parameters>${subgridParameters(childEntity, relationshipName, viewId)}</parameters>`,
    "</control>",
    "</cell></row>",
    "<row /><row /><row /><row /><row /><row /><row />",
    "</rows>",
    "</section>",
  ].join("");
}

function relatedTabXml(config, viewsByEntity, descriptions) {
  if (!config.subgrids?.length) return "";
  const sections = config.subgrids
    .map(([labelText, childEntity, relationshipName]) => {
      const view = viewsByEntity[childEntity]?.associated;
      if (!view) return "";
      return subgridXml(
        labelText,
        childEntity,
        relationshipName,
        view.savedqueryid,
        descriptions,
      );
    })
    .join("");
  if (!sections) return "";
  return [
    `<tab name="tab_related" verticallayout="true" id="${guid()}" IsUserDefined="1" showlabel="true" expanded="false">`,
    label("Related"),
    `<columns><column width="100%"><sections>${sections}</sections></column></columns>`,
    "</tab>",
  ].join("");
}

function headerXml(entityMeta) {
  const cells = STATUS_HEADER.map((field) => fieldCell(entityMeta, field, { header: true }));
  return [
    `<header id="${guid()}" columns="111" celllabelposition="Top" labelwidth="115">`,
    `<rows><row>${cells.join("")}</row></rows>`,
    "</header>",
  ].join("");
}

function buildFormXml(entityMeta, config, viewsByEntity, objectTypeCodes) {
  const controlDescriptions = [];
  const tabs = [
    `<tab name="tab_general" verticallayout="true" id="${guid()}" IsUserDefined="1" showlabel="true" expanded="true">`,
    label("General"),
    columnsXml(entityMeta, config.fields),
    "</tab>",
  ];

  for (const tab of config.extraTabs || []) {
    const normalized = normalizeExtraTab(tab);
    const xml = regularTabXml(
      entityMeta,
      normalized.label,
      normalized.sections,
      normalized.columns,
    );
    if (xml) tabs.push(xml);
  }

  const related = relatedTabXml(config, viewsByEntity, controlDescriptions);
  if (related) tabs.push(related);

  const descriptionsXml = controlDescriptions.length
    ? `<controlDescriptions>${controlDescriptions.join("")}</controlDescriptions>`
    : "";

  return `<form><tabs>${tabs.join("")}</tabs>${headerXml(entityMeta)}${descriptionsXml}</form>`;
}

function safeName(value) {
  return String(value)
    .replace(/[^a-z0-9]+/gi, "_")
    .replace(/^_+|_+$/g, "")
    .toLowerCase();
}

function primaryId(entityName) {
  return `${entityName}id`;
}

function buildFetchXml(entityName, columns, activeOnly) {
  const attrs = [primaryId(entityName), ...columns].filter(unique);
  const filter = activeOnly
    ? '<filter type="and"><condition attribute="statecode" operator="eq" value="0" /></filter>'
    : "";
  return [
    `<fetch version="1.0" mapping="logical">`,
    `<entity name="${entityName}">`,
    attrs.map((attr) => `<attribute name="${attr}" />`).join(""),
    `<order attribute="modifiedon" descending="true" />`,
    filter,
    "</entity>",
    "</fetch>",
  ].join("");
}

function buildLayoutXml(entityName, columns, objectTypeCode) {
  const cells = columns
    .filter(unique)
    .map((column, index) => {
      const width = index === 0 ? 250 : column === "statuscode" ? 140 : 160;
      return `<cell name="${column}" width="${width}" />`;
    })
    .join("");
  return [
    `<grid name="resultset" jump="cs_name" select="1" icon="1" preview="1" object="${objectTypeCode}">`,
    `<row name="result" id="${primaryId(entityName)}">${cells}</row>`,
    "</grid>",
  ].join("");
}

function unique(value, index, array) {
  return value && array.indexOf(value) === index;
}

function envValue(name) {
  const value = process.env[name];
  if (!value) throw new Error(`${name} is not set in .env`);
  return value;
}

async function dataverseToken() {
  const environmentUrl = envValue("DATAVERSE_ENVIRONMENT_URL").replace(/\/+$/, "");
  const body = new URLSearchParams({
    client_id: envValue("DATAVERSE_CLIENT_ID"),
    client_secret: envValue("DATAVERSE_CLIENT_SECRET"),
    grant_type: "client_credentials",
    scope: `${environmentUrl}/.default`,
  });
  const res = await fetch(
    `https://login.microsoftonline.com/${envValue("DATAVERSE_TENANT_ID")}/oauth2/v2.0/token`,
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body,
    },
  );
  const json = await res.json();
  if (!res.ok || !json.access_token) {
    throw new Error(`Dataverse auth failed: ${json.error_description || json.error}`);
  }
  return { token: json.access_token, environmentUrl };
}

async function dv(ctx, method, endpoint, body) {
  const headers = {
    Authorization: `Bearer ${ctx.token}`,
    Accept: "application/json",
    "OData-MaxVersion": "4.0",
    "OData-Version": "4.0",
  };
  if (body !== undefined) headers["Content-Type"] = "application/json";
  const res = await fetch(`${ctx.environmentUrl}/api/data/v9.2/${endpoint}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  const json = text ? JSON.parse(text) : null;
  if (!res.ok) {
    throw new Error(`${method} ${endpoint} failed: ${json?.error?.message || text}`);
  }
  return json;
}

async function getEntityMeta(ctx, entityName) {
  const [entity, attrs] = await Promise.all([
    dv(
      ctx,
      "GET",
      `EntityDefinitions(LogicalName='${entityName}')?$select=LogicalName,ObjectTypeCode,PrimaryNameAttribute,DisplayName`,
    ),
    dv(
      ctx,
      "GET",
      `EntityDefinitions(LogicalName='${entityName}')/Attributes?$select=LogicalName,AttributeType,DisplayName,IsValidForRead`,
    ),
  ]);
  const attributes = {};
  for (const attr of attrs.value) {
    if (!attr.IsValidForRead) continue;
    attributes[attr.LogicalName] = {
      type: attr.AttributeType,
      label: attr.DisplayName?.UserLocalizedLabel?.Label || attr.LogicalName,
    };
  }
  return {
    logicalName: entityName,
    objectTypeCode: entity.ObjectTypeCode,
    primaryNameAttribute: entity.PrimaryNameAttribute,
    label: entity.DisplayName?.UserLocalizedLabel?.Label || entityName,
    attributes,
  };
}

async function getForms(ctx, entityName) {
  const filter = encodeURIComponent(`objecttypecode eq '${entityName}' and type eq 2`);
  const result = await dv(
    ctx,
    "GET",
    `systemforms?$select=formid,name,type,objecttypecode,formactivationstate&$filter=${filter}`,
  );
  return result.value || [];
}

async function getViews(ctx, entityName) {
  const filter = encodeURIComponent(`returnedtypecode eq '${entityName}'`);
  const result = await dv(
    ctx,
    "GET",
    `savedqueries?$select=savedqueryid,name,returnedtypecode,querytype,isdefault&$filter=${filter}`,
  );
  const views = {};
  for (const view of result.value || []) {
    if (view.querytype === 0 && view.name.startsWith("Active ")) views.active = view;
    if (view.querytype === 2) views.associated = view;
  }
  return views;
}

async function addSolutionComponent(ctx, componentType, componentId) {
  if (dryRun) return;
  try {
    await dv(ctx, "POST", "AddSolutionComponent", {
      ComponentType: componentType,
      ComponentId: componentId,
      SolutionUniqueName: SOLUTION_UNIQUE_NAME,
      AddRequiredComponents: false,
      DoNotIncludeSubcomponents: true,
    });
  } catch (error) {
    if (!/already.*(solution|component)|exists/i.test(error.message)) {
      throw error;
    }
  }
}

async function updateView(ctx, entityName, view, columns, objectTypeCode, activeOnly) {
  if (!view) return false;
  const payload = {
    layoutxml: buildLayoutXml(entityName, columns, objectTypeCode),
    fetchxml: buildFetchXml(entityName, columns, activeOnly),
  };
  if (!dryRun) {
    await dv(ctx, "PATCH", `savedqueries(${view.savedqueryid})`, payload);
    await addSolutionComponent(ctx, COMPONENT_TYPES.savedQuery, view.savedqueryid);
  }
  return true;
}

async function updateForms(ctx, entityMeta, config, viewsByEntity, objectTypeCodes) {
  const forms = await getForms(ctx, entityMeta.logicalName);
  const formxml = buildFormXml(entityMeta, config, viewsByEntity, objectTypeCodes);
  for (const form of forms) {
    if (!dryRun) {
      await dv(ctx, "PATCH", `systemforms(${form.formid})`, { formxml });
      await addSolutionComponent(ctx, COMPONENT_TYPES.systemForm, form.formid);
    }
  }
  return forms.length;
}

async function publish(ctx) {
  if (!dryRun) {
    await dv(ctx, "POST", "PublishAllXml", {});
  }
}

async function main() {
  loadEnv(envPath);
  const ctx = await dataverseToken();
  console.log(`${dryRun ? "DRY RUN" : "APPLY"} schema forms in ${ctx.environmentUrl}`);

  const entityNames = Object.keys(ENTITIES);
  const metaByEntity = {};
  const viewsByEntity = {};
  const objectTypeCodes = {};

  for (const entityName of entityNames) {
    const meta = await getEntityMeta(ctx, entityName);
    metaByEntity[entityName] = meta;
    objectTypeCodes[entityName] = meta.objectTypeCode;
    viewsByEntity[entityName] = await getViews(ctx, entityName);
  }

  const summary = [];
  for (const entityName of entityNames) {
    const config = ENTITIES[entityName];
    const meta = metaByEntity[entityName];
    const views = viewsByEntity[entityName];
    const columns = (config.viewColumns || ["cs_name", "statuscode", "modifiedon"]).filter(
      (field) => isFieldPresent(meta, field),
    );
    const activeViewUpdated = await updateView(
      ctx,
      entityName,
      views.active,
      columns,
      meta.objectTypeCode,
      true,
    );
    const associatedViewUpdated = await updateView(
      ctx,
      entityName,
      views.associated,
      columns,
      meta.objectTypeCode,
      false,
    );
    const formsUpdated = await updateForms(
      ctx,
      meta,
      config,
      viewsByEntity,
      objectTypeCodes,
    );
    summary.push({
      entityName,
      formsUpdated,
      activeViewUpdated,
      associatedViewUpdated,
    });
    console.log(
      `${entityName}: forms=${formsUpdated}, activeView=${activeViewUpdated}, associatedView=${associatedViewUpdated}`,
    );
  }

  await publish(ctx);
  console.log(`summary ${JSON.stringify(summary)}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
