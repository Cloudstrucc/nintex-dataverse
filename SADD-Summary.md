# ESign Elections Canada — Architecture Summary

|                    |                           |
| ------------------ | ------------------------- |
| **Version**        | 2.0                       |
| **Date**           | April 2026                |
| **Author**         | Frederick Pearson         |

*Quick-reference companion to the full SADD (Solution Architecture & Design Document)*

---

## 1. Solution Overview

The ESign Elections Canada Broker Service provides a centralized e-signature capability for Elections Canada, built entirely on the Microsoft Power Platform (Dataverse, Power Automate, Power Pages). It integrates with **Nintex AssureSign**, a SaaS e-signature platform hosted in the Canadian region, to manage the full lifecycle of electronic signature transactions.

The architecture is composed of three major components:

- **Portal** — A Power Pages web application that provides Elections Canada staff with a self-service interface for creating templates, composing envelopes, adding signers and documents, and monitoring signature status.

- **Broker** — A set of 10 Power Automate cloud flows backed by 16 Dataverse tables. The broker orchestrates all interactions with the Nintex AssureSign API, ensuring that no other component communicates with Nintex directly.

- **Client** — A lightweight Dataverse solution and integration pattern that allows external EC business units to programmatically create and manage e-signature requests through Dataverse Web API calls, without requiring direct access to the Nintex API.

All three components share a single Dataverse environment as the system of record. The broker acts as the sole integration point with Nintex, enforcing consistent security, audit, and lifecycle management across all consumers.

---

## 2. Portal Component

The Power Pages portal is the user-facing web application for Elections Canada staff. It follows Government of Canada web standards (GCWeb/WET theme) and provides full template and envelope management through a browser-based interface.

```
Browser (EC Staff)
    |
    v
Power Pages (GCWeb/WET Theme)
    |
    ├── CS-Home-WET ──────── Dashboard (stats, recent envelopes)
    ├── CS-Templates ─────── Template list (sortable, searchable)
    ├── CS-Template-Editor ── PDF field placement editor
    ├── CS-Envelopes ─────── Envelope list (sortable, filterable)
    └── CS-Envelope-Editor ── Envelope creation & send
    |
    v
Dataverse Web API (/_api/)
    |
    ├── cs_templates ──── Template CRUD
    ├── cs_envelopes ──── Envelope CRUD
    ├── cs_signers ────── Signer management
    ├── cs_documents ──── Document management
    └── annotations ───── PDF file storage (up to 128MB)
```

### Key Technologies

| Technology | Purpose |
|---|---|
| **Enhanced Data Model** | Portal pages stored as `powerpagecomponent` records in Dataverse |
| **PDF.js** | Client-side PDF rendering in the template editor |
| **interact.js** | Drag-and-drop field placement on PDF pages |
| **GCWeb / WET** | Government of Canada UI framework for accessibility and bilingual compliance |
| **Dataverse annotations** | Binary PDF storage via the Notes entity (supports files up to 128 MB) |

### Design Principle

The portal does **not** call the Nintex API directly. All portal interactions write to Dataverse tables (envelopes, signers, documents, templates). The Broker flows detect these changes via Dataverse triggers and handle all Nintex API communication automatically. This separation ensures a clean boundary between the user interface and the integration layer.

---

## 3. Broker Component

The broker is the integration core: 10 Power Automate cloud flows and 16 Dataverse tables that orchestrate all Nintex AssureSign API interactions. It is packaged as three Dataverse solutions that must be imported in order.

### Solution Import Order

```
1. Nintex Schema       (nintex)            — 16 tables, columns, relationships
2. ESignatureConfig    (ESignatureConfig)  — 5 environment variables (API credentials, URLs)
3. ESignatureBroker    (ESignatureBroker)  — 10 cloud flows
```

### Flow Architecture

```
Dataverse Triggers
    |
    ├── Status Change ──→ Prepare Envelope ──→ Nintex POST /submit (prepare)
    ├── Status Change ──→ Send Envelope ────→ Nintex POST /submit (send)
    ├── Status Change ──→ Get Signing Links ─→ Nintex GET /signingLinks
    ├── Status Change ──→ Get Access Links ──→ Nintex GET /accessLinks
    ├── Field Change ───→ Cancel Envelope ───→ Nintex POST /cancel
    ├── Field Change ───→ Get Envelope History → Nintex GET /history
    ├── Field Change ───→ Get Document Content → Nintex GET /document
    ├── Field Change ───→ Send Signer Reminder → Nintex POST /remind
    ├── Recurrence ─────→ Status Sync ────────→ Nintex GET /envelope status
    └── Recurrence ─────→ Sync Templates ─────→ Nintex GET /templates
```

### Nintex API Configuration

| Setting | Value |
|---|---|
| API Version | v3.7 |
| Region | Canadian (ca1.assuresign.net) |
| Auth Endpoint | https://account.assuresign.net/api/v3.7 |
| API Base URL | https://ca1.assuresign.net/api/documentnow/v3.7 |
| Authentication | OAuth token (username + API key) |

### Envelope Lifecycle

```
Draft → Preparing → Ready to Send → In Process → Completed
                                         |
                                         ├──→ Cancelled
                                         └──→ Error
```

Each status transition is an integer statuscode value in Dataverse (e.g., `717640003` = In Process). Broker flows react to these transitions automatically, advancing the envelope through its lifecycle without manual intervention.

---

## 4. Client Component

The client solution (`ESignatureClient`) enables external EC business units to integrate e-signature capabilities into their own environments using Power Automate flows, Power Apps, or custom applications.

```
Client Environment (Business Unit A, B, C...)
    |
    ├── Power Automate Flows (ESignatureClient solution)
    ├── Power Apps (custom connector)
    └── Custom Applications (C#/.NET, Python)
    |
    v
Dataverse Web API (OData REST)
    |  OAuth 2.0 (Service Principal per client)
    v
Broker Environment (Dataverse)
    |
    ├── Row-Level Security (ownerid isolation)
    ├── Security Role: E-Signature Broker User
    └── Envelope / Signer / Document CRUD
    |
    v  (Broker Flows — automatic)
Nintex AssureSign API
```

### Key Design Points

- **Service principal per client** — Each integrating business unit receives a unique Entra ID app registration with client credentials. This provides identity isolation and enables per-client audit trails.

- **Row-level security** — The Dataverse `ownerid` field isolates data between clients. Each client can only read and modify records they own. The `E-Signature Broker User` security role grants CRUD access to broker tables only.

- **Dataverse-only interface** — Clients interact exclusively with the Dataverse Web API (OData REST). They create envelopes, add signers and documents, and read status. The broker flows handle all Nintex API calls transparently.

- **Cross-environment connection reference** — For Power Automate-based clients, the `ESignatureClient` solution includes a connection reference (`cs_sharecommondataserviceforapps`) that points to the broker environment's Dataverse instance.

- **No client-side Nintex access** — Clients never need Nintex credentials or API knowledge. The broker abstracts the entire e-signature integration behind standard Dataverse operations.

---

## 5. Integration Summary

The following diagram shows how all three components connect end-to-end:

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│   Portal    │     │   Broker Service     │     │  Nintex API     │
│  (Power     │────→│  (Dataverse +        │────→│  (AssureSign    │
│   Pages)    │     │   Power Automate)    │     │   v3.7 SaaS)   │
└─────────────┘     └──────────────────────┘     └─────────────────┘
                           ↑
                    ┌──────┴──────┐
                    │   Client    │
                    │  (External  │
                    │   Apps)     │
                    └─────────────┘
```

### Communication Paths

| Path | Protocol | Authentication |
|---|---|---|
| Portal to Broker | Dataverse Web API (`/_api/`) | Power Pages session (Entra ID) |
| Client to Broker | Dataverse Web API (OData REST) | OAuth 2.0 client credentials (service principal) |
| Broker to Nintex | HTTP REST (Power Automate actions) | Bearer token (Nintex API key + username) |

### Architectural Constraints

- No component communicates with Nintex directly except the Broker flows.
- All e-signature state is persisted in Dataverse as the single source of truth.
- The Portal and Client components are decoupled from the Nintex API version and endpoint configuration.
- Environment variables in the `ESignatureConfig` solution control all Nintex connectivity, enabling environment-specific configuration without code changes.

---

*This document is a summary companion to the full [SADD](SADD.md). Refer to the complete document for detailed security controls, data retention policies, ITSG-33 compliance mapping, and operational procedures.*
