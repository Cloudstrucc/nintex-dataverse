/* global Word, Office */

// ─── State ───
let signers = [];
let placedFields = [];
let editingSignerIndex = -1;
let nextSignerId = 1;

const FIELD_TYPES = {
  signature:  { label: "Signature",   icon: "\u270D",  placeholder: "[SIGNATURE]",  tag: "jignature" },
  initial:    { label: "Initials",    icon: "\u2710",  placeholder: "[INITIALS]",   tag: "jignatureInitial" },
  dateSigned: { label: "Date Signed", icon: "\uD83D\uDCC5", placeholder: "[DATE]",  tag: "signingDate" },
  fullName:   { label: "Full Name",   icon: "\uD83D\uDC64", placeholder: "[NAME]",  tag: "signerName" },
  email:      { label: "Email",       icon: "\u2709",  placeholder: "[EMAIL]",      tag: "signerEmail" },
  checkbox:   { label: "Checkbox",    icon: "\u2611",  placeholder: "[CHECK]",      tag: "checkBox" },
  text:       { label: "Text Input",  icon: "\uD83D\uDCDD", placeholder: "[TEXT]",  tag: "textField" },
  company:    { label: "Company",     icon: "\uD83C\uDFE2", placeholder: "[COMPANY]", tag: "signerCompany" },
  title:      { label: "Title",       icon: "\uD83D\uDCBC", placeholder: "[TITLE]", tag: "signerTitle" }
};

// ─── Office Init ───
Office.onReady((info) => {
  if (info.host === Office.HostType.Word) {
    initUI();
  }
});

function initUI() {
  // Tab switching
  document.querySelectorAll(".tab").forEach((tab) => {
    tab.addEventListener("click", () => {
      document.querySelectorAll(".tab").forEach((t) => t.classList.remove("active"));
      document.querySelectorAll(".tab-content").forEach((c) => c.classList.remove("active"));
      tab.classList.add("active");
      document.getElementById("tab-" + tab.dataset.tab).classList.add("active");
    });
  });

  // Signer form
  document.getElementById("btn-add-signer").addEventListener("click", showSignerForm);
  document.getElementById("btn-save-signer").addEventListener("click", saveSigner);
  document.getElementById("btn-cancel-signer").addEventListener("click", hideSignerForm);

  // Field palette clicks
  document.querySelectorAll(".field-card").forEach((card) => {
    card.addEventListener("click", () => insertField(card.dataset.field));
  });

  // Clear all
  document.getElementById("btn-clear-all").addEventListener("click", clearAllFields);

  // Enter key in signer form
  document.getElementById("signer-form").addEventListener("keydown", (e) => {
    if (e.key === "Enter") saveSigner();
  });

  updateFieldPaletteState();
}

// ─── Signer Management ───

function showSignerForm(editIndex) {
  const form = document.getElementById("signer-form");
  form.style.display = "block";

  if (typeof editIndex === "number" && editIndex >= 0) {
    editingSignerIndex = editIndex;
    const s = signers[editIndex];
    document.getElementById("signer-name").value = s.name;
    document.getElementById("signer-email").value = s.email;
    document.getElementById("signer-order").value = s.order;
  } else {
    editingSignerIndex = -1;
    document.getElementById("signer-name").value = "";
    document.getElementById("signer-email").value = "";
    document.getElementById("signer-order").value = signers.length + 1;
  }

  document.getElementById("signer-name").focus();
}

function hideSignerForm() {
  document.getElementById("signer-form").style.display = "none";
  editingSignerIndex = -1;
}

function saveSigner() {
  const name = document.getElementById("signer-name").value.trim();
  const email = document.getElementById("signer-email").value.trim();
  const order = parseInt(document.getElementById("signer-order").value) || 1;

  if (!name) {
    document.getElementById("signer-name").focus();
    return;
  }
  if (!email) {
    document.getElementById("signer-email").focus();
    return;
  }

  if (editingSignerIndex >= 0) {
    signers[editingSignerIndex].name = name;
    signers[editingSignerIndex].email = email;
    signers[editingSignerIndex].order = order;
  } else {
    signers.push({ id: nextSignerId++, name, email, order });
  }

  signers.sort((a, b) => a.order - b.order);
  hideSignerForm();
  renderSigners();
  updateSignerDropdown();
  updateFieldPaletteState();
}

function deleteSigner(index) {
  const signer = signers[index];
  // Remove placed fields for this signer
  placedFields = placedFields.filter((f) => f.signerId !== signer.id);
  signers.splice(index, 1);
  renderSigners();
  updateSignerDropdown();
  updateFieldPaletteState();
  renderPlacedFields();
}

function renderSigners() {
  const container = document.getElementById("signers-list");
  if (signers.length === 0) {
    container.innerHTML = '<div class="empty-state">No signers added yet.</div>';
    return;
  }

  container.innerHTML = signers
    .map((s, i) => {
      const initials = s.name.split(" ").map((w) => w[0]).join("").toUpperCase().slice(0, 2);
      const colorClass = "signer-color-" + (i % 6);
      const fieldCount = placedFields.filter((f) => f.signerId === s.id).length;
      return `
        <div class="card">
          <div class="signer-card">
            <div class="signer-avatar ${colorClass}">${initials}</div>
            <div class="signer-info">
              <div class="signer-name">${escapeHtml(s.name)}</div>
              <div class="signer-email">${escapeHtml(s.email)}</div>
              <div class="signer-order">Order: ${s.order} &middot; ${fieldCount} field${fieldCount !== 1 ? "s" : ""}</div>
            </div>
            <div class="signer-actions">
              <button onclick="showSignerForm(${i})" title="Edit">&#9998;</button>
              <button class="delete" onclick="deleteSigner(${i})" title="Remove">&times;</button>
            </div>
          </div>
        </div>`;
    })
    .join("");
}

function updateSignerDropdown() {
  const select = document.getElementById("field-signer-select");
  const currentVal = select.value;
  select.innerHTML =
    signers.length === 0
      ? '<option value="">-- Add a signer first --</option>'
      : signers
          .map((s) => `<option value="${s.id}">${escapeHtml(s.name)} (${escapeHtml(s.email)})</option>`)
          .join("");

  // Restore selection if still valid
  if (signers.some((s) => String(s.id) === currentVal)) {
    select.value = currentVal;
  }
}

function updateFieldPaletteState() {
  const hasSigners = signers.length > 0;
  document.querySelectorAll(".field-card").forEach((card) => {
    card.classList.toggle("disabled", !hasSigners);
  });
}

// ─── Field Insertion ───

async function insertField(fieldType) {
  const select = document.getElementById("field-signer-select");
  const signerId = parseInt(select.value);
  const signer = signers.find((s) => s.id === signerId);

  if (!signer) {
    showStatus("Select a signer first.", "error");
    return;
  }

  const fieldDef = FIELD_TYPES[fieldType];
  if (!fieldDef) return;

  // Build the Nintex-compatible tag: signerIndex_fieldTag
  const signerIndex = signers.indexOf(signer);
  const tagValue = `{{signer${signerIndex + 1}_${fieldDef.tag}}}`;
  const displayText = `${fieldDef.placeholder.replace("[", "[" + signer.name.split(" ")[0] + ": ")}`;

  try {
    await Word.run(async (context) => {
      const range = context.document.getSelection();
      const cc = range.insertContentControl();
      cc.tag = tagValue;
      cc.title = `${fieldDef.label} - ${signer.name}`;
      cc.appearance = "BoundingBox";
      cc.color = getSignerColor(signerIndex);
      cc.insertText(displayText, "Replace");

      // Style the content control text
      const ccRange = cc.getRange();
      ccRange.font.bold = true;
      ccRange.font.size = 10;
      ccRange.font.color = getSignerColor(signerIndex);

      await context.sync();
    });

    // Track the placed field
    placedFields.push({
      signerId: signer.id,
      signerName: signer.name,
      fieldType,
      tag: tagValue,
      label: fieldDef.label,
      icon: fieldDef.icon
    });

    renderPlacedFields();
    renderSigners(); // update field counts
    showStatus(`${fieldDef.label} inserted for ${signer.name}`, "success");
  } catch (error) {
    showStatus("Failed to insert: " + error.message, "error");
  }
}

async function removeField(index) {
  const field = placedFields[index];

  try {
    await Word.run(async (context) => {
      const ccs = context.document.contentControls;
      ccs.load("items/tag");
      await context.sync();

      // Find and delete the content control with matching tag
      let removed = false;
      for (const cc of ccs.items) {
        if (cc.tag === field.tag && !removed) {
          cc.delete(false); // false = keep content? No, we want to remove it
          removed = true;
        }
      }

      if (!removed) {
        // Try harder — delete by searching all with this tag
        const tagged = context.document.contentControls.getByTag(field.tag);
        tagged.load("items");
        await context.sync();
        if (tagged.items.length > 0) {
          tagged.items[0].delete(true);
        }
      }

      await context.sync();
    });
  } catch (e) {
    // Content control may already be manually deleted
  }

  placedFields.splice(index, 1);
  renderPlacedFields();
  renderSigners();
}

async function clearAllFields() {
  try {
    await Word.run(async (context) => {
      const ccs = context.document.contentControls;
      ccs.load("items/tag");
      await context.sync();

      for (const cc of ccs.items) {
        if (cc.tag && cc.tag.startsWith("{{signer")) {
          cc.delete(true);
        }
      }
      await context.sync();
    });
  } catch (e) {
    // Ignore
  }

  placedFields = [];
  renderPlacedFields();
  renderSigners();
  showStatus("All fields removed.", "success");
}

async function selectFieldInDoc(index) {
  const field = placedFields[index];
  try {
    await Word.run(async (context) => {
      const tagged = context.document.contentControls.getByTag(field.tag);
      tagged.load("items");
      await context.sync();
      if (tagged.items.length > 0) {
        tagged.items[0].select();
      }
      await context.sync();
    });
  } catch (e) {
    // Ignore
  }
}

// ─── Placed Fields Rendering ───

function renderPlacedFields() {
  const container = document.getElementById("placed-fields-list");
  const clearBtn = document.getElementById("btn-clear-all");

  if (placedFields.length === 0) {
    container.innerHTML = '<div class="empty-state">No fields placed yet.</div>';
    clearBtn.style.display = "none";
    return;
  }

  clearBtn.style.display = "block";
  container.innerHTML = placedFields
    .map((f, i) => {
      return `
        <div class="placed-item" onclick="selectFieldInDoc(${i})">
          <div class="placed-type">${f.icon}</div>
          <div class="placed-info">
            <div class="placed-field-name">${escapeHtml(f.label)}</div>
            <div class="placed-signer-name">${escapeHtml(f.signerName)} &middot; ${escapeHtml(f.tag)}</div>
          </div>
          <button class="placed-remove" onclick="event.stopPropagation(); removeField(${i})" title="Remove">&times;</button>
        </div>`;
    })
    .join("");
}

// ─── Utilities ───

function showStatus(msg, type) {
  const el = document.getElementById("insert-status");
  el.textContent = msg;
  el.className = "status-msg " + type;
  el.style.display = "block";
  setTimeout(() => {
    el.style.display = "none";
  }, 3000);
}

function getSignerColor(index) {
  const colors = ["#b71c1c", "#1565c0", "#2e7d32", "#e65100", "#6a1b9a", "#00838f"];
  return colors[index % colors.length];
}

function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

// Make functions available globally for inline onclick handlers
window.showSignerForm = showSignerForm;
window.deleteSigner = deleteSigner;
window.removeField = removeField;
window.selectFieldInDoc = selectFieldInDoc;
