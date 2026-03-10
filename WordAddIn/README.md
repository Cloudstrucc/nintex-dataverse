# Nintex eSign Word Add-in

A Word taskpane add-in for placing Nintex eSign signature fields onto documents.

## Features

- **Signer Management** — Add signers with name, email, and signing order
- **Field Palette** — 9 field types: Signature, Initials, Date Signed, Full Name, Email, Checkbox, Text Input, Company, Title
- **Click to Insert** — Select a signer, click a field, and it inserts a color-coded content control at the cursor
- **Placed Fields Tracking** — View all placed fields, click to navigate, or remove individually
- **Content Control Tags** — Each field gets a tag like `{{signer1_jignature}}` for downstream processing

## Quick Start

```bash
cd WordAddIn
npm install
npm run start
```

Then sideload in Word:

### macOS (Word for Mac)
1. Open Word
2. Go to **Insert > Add-ins > My Add-ins**
3. Click **Upload My Add-in** and select `manifest.xml`

### Windows (Word Desktop)
```bash
npm run sideload
```

### Word Online
1. Go to **Insert > Office Add-ins > Upload My Add-in**
2. Upload `manifest.xml`

## Field Tag Format

Fields are inserted as Word content controls with tags in this format:

```
{{signer1_jignature}}      — Signature block
{{signer1_jignatureInitial}} — Initials
{{signer1_signingDate}}     — Date signed
{{signer1_signerName}}      — Full name
{{signer1_signerEmail}}     — Email address
{{signer1_checkBox}}        — Checkbox
{{signer1_textField}}       — Free text
{{signer1_signerCompany}}   — Company name
{{signer1_signerTitle}}     — Job title
```

The `signer1`, `signer2`, etc. corresponds to the signing order.
