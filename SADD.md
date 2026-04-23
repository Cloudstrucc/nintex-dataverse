# E-Signature Elections Canada

## Solution Architecture & Design Document

### Broker Service, Power Pages Portal, & Client Integration

---

|                    |                           |
| ------------------ | ------------------------- |
| **Version**        | 2.0                       |
| **Last Updated**   | April 2026                |
| **Document Owner** | Platform Engineering Team |
| **Author**         | Frederick Pearson         |
| **Status**         | Draft for Review          |

---

*Elections Canada -- Platform Engineering Team*

---

## Document Control

| Version | Date          | Author            | Changes                                                                                                                                                           |
| ------- | ------------- | ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1.0     | February 2026 | Frederick Pearson | Initial release -- Core broker service architecture                                                                                                               |
| 2.0     | April 2026    | Frederick Pearson | Major update: Power Pages Portal architecture; three-solution design; updated data model with actual statuscode values; Canadian-region Nintex API; deployment tooling |

---

## Table of Contents

**Part 1 -- Executive Summary & Architecture Overview**

1. Executive Summary
2. Architecture Overview
3. Access Control & Identity Management

**Part 2 -- Data & Integration Architecture**

4. Data Architecture
5. Integration Architecture
6. Power Pages Portal Architecture

**Part 3 -- Security & Monitoring**

7. Security Architecture
8. Monitoring, Logging & Audit

**Part 4 -- Operations & Compliance**

9. Data Retention & Disposition
10. Client Onboarding Process
11. Environment Strategy
12. Network Architecture
13. Disaster Recovery & Business Continuity
14. Compliance & Governance (ITSG-33)

**Part 5 -- Annexes**

- Annex A: Environment Configuration
- Annex B: Security Controls Mapping (ITSG-33)
- Annex C: API Specifications
- Annex D: Troubleshooting Guide

---

<!-- ============================================================ -->
<!-- PART 1 -->
<!-- ============================================================ -->

# Part 1: Executive Summary & Architecture Overview

---

## 1. Executive Summary

### 1.1 Purpose

This document describes the solution architecture for the **ESign Elections Canada Broker Service**, a digital signature platform that provides Elections Canada (EC) with secure, compliant, and auditable electronic signature capabilities via Nintex AssureSign.

Version 2.0 is a major update that incorporates the **Power Pages Portal** as a full component of the architecture. The portal provides EC staff with a self-service web interface for creating signature templates, composing envelopes, and tracking signing status -- all within a Government of Canada-compliant (GCWeb/WET) responsive interface.

### 1.2 Scope

The architecture encompasses the following functional domains:

**Broker Service Layer** -- Microsoft Power Platform (Dataverse + Power Automate) acting as API gateway and middleware between all clients and Nintex AssureSign. Implemented as three Dataverse solutions: Nintex Schema, E-Signature Config, and E-Signature Broker.

**Power Pages Portal Layer** *(major addition in v2.0)* -- A GCWeb-themed web portal allowing authenticated EC staff to create and manage signature templates with visual PDF field placement, compose and send envelopes, and monitor signing progress through a dashboard interface.

**Client Integration Layer** -- The E-Signature Client solution provides reference Power Automate flows for programmatic client consumption from separate Dataverse environments.

**External Integration** -- Nintex AssureSign API v3.7 integration (Canadian region) for digital signature delivery and lifecycle management.

**Security & Compliance** -- Protected B controls, ITSG-33 alignment, audit logging, PII management, and Privacy Impact Assessment coverage.

**Operations** -- Monitoring, logging, backup, disaster recovery, deployment tooling, and client onboarding procedures.

### 1.3 Key Architectural Principles

| Principle                           | Description                                                | Implementation                                                                                     |
| ----------------------------------- | ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Support for Multiple Business Units | Logical isolation between client applications and services | Row-level security (RLS) in Dataverse; business units and security roles for API access governance |
| API-First                           | OData/REST endpoints as primary integration method         | Dataverse Web API and Custom Connectors                                                            |
| Zero Trust                          | Never trust, always verify                                 | OAuth 2.0, service principals, conditional access                                                  |
| Defense in Depth                    | Layered security controls                                  | Network, identity, application, and data encryption layers                                         |
| Audit Everything                    | Complete audit trail                                       | Dataverse audit logs and Azure Monitor                                                             |
| Least Privilege                     | Minimal necessary permissions                              | Custom security roles and Entra ID RBAC                                                            |
| Self-Service                        | Reduced IT dependency for routine signature workflows      | Power Pages portal with guided envelope creation and template management                           |
| Solution Modularity                 | Independent deployment of schema, config, and logic        | Three-solution design with explicit import ordering                                                |

### 1.4 High-Level Architecture

The platform architecture consists of four primary interaction layers:

```text
+---------------------------------------------------------------------+
|                        CLIENT LAYER                                  |
|  +----------------+  +------------------+  +---------------------+  |
|  | Power Automate |  | Custom Apps      |  | Power Pages Portal  |  |
|  | Client Flows   |  | (.NET / Python)  |  | (GCWeb/WET Theme)   |  |
|  +-------+--------+  +--------+---------+  +----------+----------+  |
|          |                     |                       |             |
+---------------------------------------------------------------------+
           |                     |                       |
           v                     v                       v
+---------------------------------------------------------------------+
|                    AUTHENTICATION LAYER                               |
|                    Microsoft Entra ID                                 |
|              OAuth 2.0 / OpenID Connect / MFA                        |
+---------------------------------------------------------------------+
           |                     |                       |
           v                     v                       v
+---------------------------------------------------------------------+
|                   BROKER SERVICE LAYER                                |
|  +--------------------------------------------------------------+   |
|  |                     Dataverse (Canada Central)                |   |
|  |  +------------------+  +---------------+  +----------------+ |   |
|  |  | Nintex Schema     |  | ESign Config  |  | ESign Broker   | |   |
|  |  | (16 tables)       |  | (5 env vars)  |  | (10+ flows)   | |   |
|  |  +------------------+  +---------------+  +----------------+ |   |
|  +--------------------------------------------------------------+   |
|                              |                                       |
+---------------------------------------------------------------------+
                               |
                               v
+---------------------------------------------------------------------+
|                    EXTERNAL SAAS LAYER                                |
|               Nintex AssureSign API v3.7                              |
|            (ca1.assuresign.net -- Canada Region)                     |
+---------------------------------------------------------------------+
```

**Client Layer** -- Internal applications and services interact with the broker through the Dataverse Web API (OData) or the Custom Connector. Authenticated EC staff interact through the Power Pages portal.

**Authentication Layer** -- Entra ID provides OAuth 2.0 tokens for programmatic clients (service principals) and OpenID Connect SSO for portal users. Conditional Access policies enforce MFA and device compliance.

**Broker Service Layer** -- Dataverse serves as the central orchestration hub, managing envelope lifecycle, row-level security, Power Automate workflow execution, and all integration with Nintex. The three solutions (Schema, Config, Broker) are deployed in dependency order.

**External SaaS** -- Nintex AssureSign (Canadian region at `ca1.assuresign.net`) is the underlying digital signature platform, accessed exclusively via the broker's Power Automate orchestration flows.

### 1.5 Technology Stack

| Layer         | Technology                 | Version | Purpose                                            |
| ------------- | -------------------------- | ------- | -------------------------------------------------- |
| Platform      | Microsoft Power Platform   | Latest  | Broker service host                                |
| Database      | Dataverse                  | 9.2+    | Data store and API                                 |
| Orchestration | Power Automate             | N/A     | Workflow automation (10 cloud flows)               |
| Portal        | Power Pages                | Latest  | Self-service web portal (GCWeb/WET theme)          |
| Identity      | Microsoft Entra ID         | Latest  | Authentication and authorization                   |
| Secrets       | Azure Key Vault            | Latest  | Credential management                              |
| Monitoring    | Azure Monitor              | Latest  | Logging and alerting                               |
| API Gateway   | Dataverse Web API          | 9.2+    | OData endpoints                                    |
| External SaaS | Nintex AssureSign           | 3.7     | Digital signature platform (Canadian region)       |
| PDF Rendering | PDF.js                     | 3.11    | Client-side PDF rendering in portal                |
| Field Editing | interact.js                | 1.10    | Drag-and-drop field placement in portal            |

### 1.6 Three-Solution Design

The broker is split into three Dataverse solutions, all using publisher prefix **`cs`** (CustomizationOptionValuePrefix: `71764`):

| Solution            | Unique Name        | Version  | Purpose                | Contents                                |
| ------------------- | ------------------ | -------- | ---------------------- | --------------------------------------- |
| **Nintex Schema**    | `nintex`           | Latest   | Entity definitions     | 16 custom tables, columns, relationships, statuscode values |
| **E-Signature Config** | `ESignatureConfig` | Latest | Environment variables  | 5 environment variables for Nintex API  |
| **E-Signature Broker** | `ESignatureBroker` | 1.0.0.73 | Automation            | 10+ Power Automate cloud flows          |

**Import order matters:** Schema --> Config --> Broker (each depends on the previous).

The **E-Signature Client** solution (`ESignatureClient`) is distributed separately to client environments. It contains reference Power Automate flows that connect to the broker environment's Dataverse tables via a cross-environment connection reference. The client solution contains no tables.

---

## 2. Architecture Overview

### 2.1 Architectural Patterns

#### 2.1.1 Broker Pattern

The solution implements a broker architectural pattern in which:

1. Client services and the Power Pages portal interact with the broker via the standard OData API (Dataverse Web API).
2. The broker manages complexity, envelope lifecycle, integration layer governance, and all Nintex API interactions.
3. Nintex AssureSign provides the underlying digital signature capabilities.

The key purposes served by this pattern are centralized Nintex license management, consistent security controls across all client types, simplified client integration, and a unified audit and compliance trail.

#### 2.1.2 Broker Pattern Sequence Flow

```text
  Client / Portal              Broker (Dataverse)            Nintex AssureSign
       |                              |                              |
       |  1. Create Envelope (Draft)  |                              |
       |----------------------------->|                              |
       |                              |                              |
       |  2. Add Signers + Documents  |                              |
       |----------------------------->|                              |
       |                              |                              |
       |  3. Set status = Preparing   |                              |
       |----------------------------->|                              |
       |                              |  4. Prepare envelope         |
       |                              |----------------------------->|
       |                              |  5. Return prepared ID       |
       |                              |<-----------------------------|
       |                              |                              |
       |                              |  (status = Ready to Send)    |
       |                              |                              |
       |                              |  6. Submit to Nintex         |
       |                              |----------------------------->|
       |                              |  7. Nintex envelope ID       |
       |                              |<-----------------------------|
       |                              |                              |
       |                              |  (status = In Process)       |
       |                              |                              |
       |                              |  8. Get signing links        |
       |                              |----------------------------->|
       |                              |  9. Per-signer URLs          |
       |                              |<-----------------------------|
       |                              |                              |
       |                              |  10. Status sync (30 min)    |
       |                              |----------------------------->|
       |                              |  11. Updated signer status   |
       |                              |<-----------------------------|
       |                              |                              |
       |  12. Query status            |  (status = Completed)        |
       |<-----------------------------|                              |
       |                              |                              |
```

#### 2.1.3 Client Service to Broker Service Architecture

Each client application or service is assigned a unique Service Principal in Entra ID. This principal is mapped to a Dataverse Application User, which is assigned the **E-Signature Broker User** security role. Dataverse enforces Row-Level Security via the `ownerid` field, ensuring that each client can only read and write their own records.

The portal introduces a parallel authentication model: authenticated EC staff users (human identities) interact with the broker through Power Pages, with their Dataverse Contact record serving as the owner of envelopes created through that channel.

**Isolation Mechanisms Summary:**

| Mechanism                       | Implementation                               | Security Level        |
| ------------------------------- | -------------------------------------------- | --------------------- |
| Identity (programmatic clients) | Unique service principal per client          | Entra ID tenant-level |
| Identity (portal users)         | Entra ID SSO mapped to Dataverse Contact     | Entra ID tenant-level |
| Data                            | Owner-based RLS in Dataverse                 | Row-level             |
| Network                         | Shared PaaS with optional IP restrictions    | Tenant-level          |
| Logging                         | Separate Log Analytics workspaces per client | Subscription-level    |

### 2.2 Dataverse as Integration Platform

Dataverse is the core integration hub for the broker service:

**OData Protocol Support** -- Industry-standard REST API supporting `$filter`, `$select`, `$expand`, standardized OAuth 2.0 authentication, native pagination, and batch operations.

**Web API Capabilities** -- Full RESTful CRUD operations, webhooks for real-time integration, and SDK support across C#, JavaScript, and Python.

**Built-in Security** -- Row-level security, column-level security, native audit logging, and AES-256 data encryption at rest and in transit via TLS 1.2+.

**Power Platform Integration** -- Native Power Automate triggers, Power Apps data source support, custom connector compatibility, and Power Pages portal data access via the Portal Web API (`/_api/`).

---

## 3. Access Control & Identity Management

### 3.1 Authentication Architecture

The broker employs a multi-step token-based authentication model:

1. The client application or portal requests a token from the Entra ID token endpoint.
2. Entra ID authenticates the requestor (service principal credentials for programmatic clients; user credentials plus MFA for portal users) and generates an OAuth 2.0 access token.
3. The client presents the token with every API call to Dataverse.
4. Dataverse validates the token, maps the caller to the corresponding Application User or Contact record, checks security role permissions, and applies Row-Level Security filters automatically.

### 3.2 Authentication Methods

#### 3.2.1 Service Principal (Recommended for Programmatic Clients)

This method is used for Power Automate flows, custom applications, and scheduled jobs. Each onboarded client receives a dedicated App Registration in Entra ID, a corresponding Service Principal, a client secret stored in Azure Key Vault, and Dataverse API permissions granted with admin consent. Tokens are acquired using the OAuth 2.0 client credentials grant and must target the broker Dataverse environment as the resource scope.

#### 3.2.2 Managed Identity (For Azure-Hosted Applications)

Azure Functions, Logic Apps, and Virtual Machines can authenticate using system-assigned managed identities, eliminating the need to manage client secrets in code. The managed identity principal is granted the Dynamics 365 User role and acquires tokens via the Azure Instance Metadata Service endpoint.

#### 3.2.3 Power Pages Portal SSO (For Human Users)

EC staff accessing the portal authenticate via OpenID Connect against the Elections Canada Entra ID tenant. If a valid browser session already exists (the user is already signed in to their EC account), authentication is silent with no re-prompt. Upon first authentication, a Dataverse Contact record is automatically created or looked up and linked to the portal session. All envelopes created via the portal are owned by the authenticated Contact, and RLS is enforced identically to programmatic clients.

### 3.3 Authorization Model

Entra ID permissions are mapped to Dataverse Application Users, who are assigned security roles. Security roles grant specific privileges on each Dataverse table. Owner-based Row-Level Security then filters data access so each caller sees only records they own.

### 3.4 Security Roles Configuration

**E-Signature Broker User** -- Grants CRUD on broker tables only. Assigned to app users or Entra users in the broker environment.

| Privilege | cs_envelope  | cs_signer    | cs_document  | cs_field     | cs_template  | cs_apirequest |
| --------- | ------------ | ------------ | ------------ | ------------ | ------------ | ------------- |
| Create    | Organization | Organization | Organization | Organization | None         | Organization  |
| Read      | Organization | Organization | Organization | Organization | Organization | Organization  |
| Write     | Organization | Organization | Organization | Organization | None         | None          |
| Delete    | Organization | Organization | Organization | Organization | None         | None          |

*Organization-level privileges are required due to Dataverse API behavior; RLS via `ownerid` restricts actual data visibility to the caller's own records.*

**Broker Administrator Role** -- Grants full access across all tables for platform administration and support purposes.

**Portal Template User Role** -- Assigned to Power Pages Contact records. Grants the ability to create and manage envelopes, documents, signers, and fields owned by the Contact, and read-only access to public templates from the template library.

### 3.5 Conditional Access Policies

| Policy Name               | Conditions                   | Controls                    |
| ------------------------- | ---------------------------- | --------------------------- |
| Require MFA for Admins    | User role = Admin            | Require MFA                 |
| Block Legacy Auth         | Client apps = Legacy         | Block access                |
| Require Compliant Device  | Device state = Not compliant | Block access                |
| IP Restriction (Optional) | IP address not in GC range   | Block access                |
| Session Controls          | All users                    | Sign-in frequency = 8 hours |

---

<!-- ============================================================ -->
<!-- PART 2 -->
<!-- ============================================================ -->

# Part 2: Data & Integration Architecture

---

## 4. Data Architecture

### 4.1 Entity Relationship Diagram

The data model is built around the `cs_envelope` entity as the hub record, with related entities for signers, documents, templates, access links, envelope histories, and API audit logs.

```text
                          +------------------+
                          |   cs_template    |
                          |------------------|
                          | cs_templateid PK |
                          | cs_name          |
                          | cs_description   |
                          | cs_isactive      |
                          | cs_templatejson  |
                          | cs_category      |
                          | statuscode       |
                          +--------+---------+
                                   |
                                   | (optional reference)
                                   |
+------------------+     +---------+----------+     +--------------------+
|   cs_signer      |     |    cs_envelope     |     |   cs_document      |
|------------------|     |--------------------|     |--------------------|
| cs_signerid PK   |     | cs_envelopeid PK   |     | cs_documentid PK   |
| cs_fullname      |<----| cs_name            |---->| cs_filename        |
| cs_email         |  1:N| cs_subject         | 1:N | cs_filecontent     |
| cs_signerorder   |     | cs_message         |     | cs_signedcontent   |
| cs_authtype      |     | cs_templateid      |     | cs_documentorder   |
| cs_language      |     | cs_preparedenvelid |     | cs_requestsignedcopy|
| cs_signerstatus  |     | cs_processingmode  |     | cs_envelopelookup  |
| cs_signeddate    |     | cs_daystoexpire    |     +--------------------+
| cs_signinglink   |     | cs_reminderfreq    |
| cs_sendreminder  |     | cs_responsebody    |     +--------------------+
| cs_envelopelookup|     | cs_requestbody     |     |  cs_accesslink     |
+------------------+     | cs_requesthistory  |     |--------------------|
                          | cs_iscancelled     |---->| cs_accesslinkid PK |
+------------------+     | cs_sentdate        | 1:N | cs_linkurl         |
| cs_envelopehistory|     | cs_completeddate   |     | cs_linktype        |
|------------------|     | cs_cancelleddate   |     | cs_signerid        |
| cs_historyid PK  |<----| cs_expirationdate  |     | cs_expiresat       |
| cs_eventtype     |  1:N| cs_callbackurl     |     | cs_envelopelookup  |
| cs_eventdate     |     | cs_redirecturl     |     +--------------------+
| cs_description   |     | statuscode         |
| cs_username      |     +--------------------+     +--------------------+
| cs_ipaddress     |              |                  |  cs_apirequest     |
| cs_envelopelookup|              |                  |--------------------|
+------------------+              +----------------->| cs_apirequestid PK |
                                                1:N  | cs_requestbody     |
                                                     | cs_responsebody    |
                                                     | cs_statuscode      |
                                                     | cs_timestamp       |
                                                     +--------------------+
```

**PDF Document Storage:** Documents uploaded via the portal are stored as Dataverse **annotations** (Notes table) attached to `cs_document` records, rather than in text/memo fields. This approach supports files up to 128 MB (vs the 1 MB limit of Dataverse text columns) and leverages Dataverse's native file handling infrastructure.

### 4.2 Data Model Details

#### 4.2.1 cs_envelope (Envelopes) -- Hub Entity

**Purpose:** Central entity representing a single e-signature request, from draft through completion. All other entities relate back to this.

**Key Columns:**

| Column                   | Type     | Purpose                            |
| ------------------------ | -------- | ---------------------------------- |
| cs_envelopeid            | GUID PK  | Primary key                        |
| cs_name                  | String   | Envelope display name              |
| cs_subject               | String   | Email subject for signer notices   |
| cs_message               | Memo     | Message body for signer notices    |
| cs_templateid            | String   | Nintex template reference          |
| cs_preparedenvelopeid    | String   | Nintex prepared envelope ID        |
| cs_processingmode        | Choice   | Sequential or parallel signing     |
| cs_daystoexpire          | Integer  | Days until envelope expires        |
| cs_reminderfrequency     | Integer  | Days between signer reminders      |
| cs_responsebody          | Memo     | Full API response (audit)          |
| cs_requestbody           | Memo     | Full API request payload (audit)   |
| cs_requesthistory        | Boolean  | Trigger to fetch history from Nintex|
| cs_iscancelled           | Boolean  | Trigger to cancel via Nintex       |
| cs_sentdate              | DateTime | When sent to Nintex                |
| cs_completeddate         | DateTime | When all signatures obtained       |
| cs_cancelleddate         | DateTime | When cancelled                     |
| cs_expirationdate        | DateTime | When envelope expires              |
| cs_callbackurl           | String   | Webhook callback URL               |
| cs_redirecturl           | String   | Post-signing redirect URL          |
| statuscode               | Integer  | Workflow state (see table below)   |

**Envelope statuscode values (statecode=0 Active):**

| Value      | Label (EN)     | Label (FR)        | Description                              |
| ---------- | -------------- | ----------------- | ---------------------------------------- |
| 1          | Draft          | Brouillon         | Being assembled by client or portal user |
| 717640001  | Preparing      | En preparation    | Preparing via Nintex API                 |
| 717640002  | Ready to Send  | Pret a envoyer    | Prepared, awaiting submission            |
| 717640003  | In Process     | En cours          | Sent to signers via Nintex              |
| 717640004  | Completed      | Termine           | All signatures obtained (terminal)       |
| 717640005  | Error          | Erreur            | Technical error (retriable)              |
| 717640006  | Cancelled      | Annule            | Cancelled by requestor (terminal)        |
| 717640007  | Cancel Error   | Erreur d'annulation| Error during cancellation attempt       |

| Value | Label (statecode=1) |
| ----- | ------------------- |
| 2     | Inactive            |

**Envelope Lifecycle:**

```text
  Draft ---> Preparing ---> Ready to Send ---> In Process ---> Completed
    |                                             |
    |                                             +----------> Cancelled
    |                                             |
    |                                             +----------> Error
    |
    +---> Error (validation failure)

  Cancel attempt from In Process:
    In Process ---> Cancelled
    In Process ---> Cancel Error (if Nintex API fails)
```

#### 4.2.2 cs_signer (Signers)

**Purpose:** Individual signers associated with an envelope.

**Key Columns:**

| Column              | Type     | PII  | Purpose                              |
| ------------------- | -------- | ---- | ------------------------------------ |
| cs_signerid         | GUID PK  | No   | Primary key                          |
| cs_fullname         | String   | Yes  | Signer display name                  |
| cs_email            | String   | Yes  | Signer email address                 |
| cs_signerorder      | Integer  | No   | Signing sequence position            |
| cs_authenticationtype| Choice  | No   | Authentication method for signing    |
| cs_language         | String   | No   | Preferred language (EN/FR)           |
| cs_signerstatus     | Choice   | No   | Current signing status               |
| cs_signeddate       | DateTime | No   | When signer completed signing        |
| cs_signinglink      | String   | Yes  | Unique signing URL (sensitive)       |
| cs_sendreminder     | Boolean  | No   | Trigger to send reminder via Nintex  |
| cs_envelopelookup   | Lookup   | No   | Parent envelope reference            |

**Signer statuscode values:**

| Value     | Label     |
| --------- | --------- |
| 1         | Pending   |
| 717640001 | Signed    |
| 717640002 | Declined  |
| 717640003 | Delegated |
| 2         | Inactive  |

#### 4.2.3 cs_document (Documents)

**Purpose:** Files attached to an envelope for signing.

**Key Columns:**

| Column               | Type     | Purpose                                |
| -------------------- | -------- | -------------------------------------- |
| cs_documentid        | GUID PK  | Primary key                            |
| cs_filename          | String   | Original filename                      |
| cs_filecontent       | Memo     | Base64-encoded source document         |
| cs_signedcontent     | Memo     | Base64-encoded signed document         |
| cs_documentorder     | Integer  | Display/signing order                  |
| cs_requestsignedcopy | Boolean  | Trigger to download signed copy        |
| cs_envelopelookup    | Lookup   | Parent envelope reference              |

Documents are stored as Base64-encoded content. Base64 encoding increases file size by approximately 33%. For portal-uploaded PDFs, the document content is stored as an annotation (Note) on the document record, supporting files up to 128 MB.

#### 4.2.4 cs_template (Templates)

**Purpose:** Stores signature templates with configuration, synced from or to Nintex.

**Key Columns:**

| Column          | Type     | Purpose                              |
| --------------- | -------- | ------------------------------------ |
| cs_templateid   | GUID PK  | Primary key                          |
| cs_name         | String   | Template display name                |
| cs_description  | Memo     | Template description                 |
| cs_isactive     | Boolean  | Whether template is active           |
| cs_templatejson | Memo     | Full template configuration as JSON  |
| cs_category     | String   | Template category                    |
| statuscode      | Integer  | Active (1) or Inactive (2)           |

#### 4.2.5 cs_accesslink (Access Links)

**Purpose:** Stores access links for completed envelopes (download links for signed documents).

| Column            | Type     | Purpose                        |
| ----------------- | -------- | ------------------------------ |
| cs_accesslinkid   | GUID PK  | Primary key                    |
| cs_linkurl        | String   | Access URL                     |
| cs_linktype       | String   | Type of link                   |
| cs_signerid       | String   | Associated signer              |
| cs_expiresat      | DateTime | Link expiration                |
| cs_envelopelookup | Lookup   | Parent envelope reference      |

#### 4.2.6 cs_envelopehistory (Envelope Histories)

**Purpose:** Audit history events for an envelope, fetched from Nintex.

| Column              | Type     | Purpose                      |
| ------------------- | -------- | ---------------------------- |
| cs_envelopehistoryid| GUID PK  | Primary key                  |
| cs_eventtype        | String   | Type of event                |
| cs_eventdate        | DateTime | When the event occurred      |
| cs_description      | String   | Event description            |
| cs_username         | String   | User who triggered event     |
| cs_ipaddress        | String   | IP address of actor          |
| cs_envelopelookup   | Lookup   | Parent envelope reference    |

#### 4.2.7 Supporting Tables

| Table                  | Purpose                                  |
| ---------------------- | ---------------------------------------- |
| cs_authtoken           | Cached Nintex API auth tokens            |
| cs_webhook             | Inbound webhook event payloads           |
| cs_apirequest          | API call audit log (all Nintex interactions) |
| cs_useraccount         | Nintex user account references           |
| cs_field               | Signature/form field definitions         |
| cs_senderinput         | Template sender input parameters         |
| cs_emailnotification   | Email notification configuration         |
| cs_digitalsignature    | Standalone digital signature requests    |
| cs_assuresign          | Legacy AssureSign integration entity     |
| cs_item                | Utility/test entity                      |

#### 4.2.8 cs_apirequest (API Request Log)

**Purpose:** Complete audit log of all Nintex API interactions. All fields are retained for 7 years per Protected B requirements.

| Field           | Type     | Retention |
| --------------- | -------- | --------- |
| cs_requestbody  | Memo     | 7 years   |
| cs_responsebody | Memo     | 7 years   |
| cs_statuscode   | Integer  | 7 years   |
| cs_timestamp    | DateTime | 7 years   |

### 4.3 Row-Level Security Implementation

Each client has a unique Service Principal (or, for portal users, a unique Contact record) that is mapped to a Dataverse user identity. Security roles grant Organization-level privileges, but the `ownerid` field filter is automatically applied by the Dataverse Web API to every query, ensuring each caller retrieves only their own records.

**Validation Test Cases:**

| Test Scenario                                   | Expected Result                           |
| ----------------------------------------------- | ----------------------------------------- |
| Client A queries all envelopes                  | Returns only Client A's envelopes         |
| Client A queries Client B's envelope by ID      | 404 Not Found                             |
| Client A attempts to update Client B's envelope | 403 Forbidden                             |
| Admin queries all envelopes                     | Returns all envelopes (no filter applied) |

### 4.4 Column-Level Security

Certain fields contain sensitive data and are restricted to Broker Administrator role only:

| Field           | Table       | Access Level         | Reason                      |
| --------------- | ----------- | -------------------- | --------------------------- |
| cs_requestbody  | cs_envelope | Admin read only      | Contains PII in API payload |
| cs_responsebody | cs_envelope | Admin read only      | Contains Nintex tokens      |
| cs_signinglink  | cs_signer   | Owner and Admin read | Unique signing access URL   |
| cs_ipaddress    | cs_signer   | Admin read only      | PII -- tracking data        |

### 4.5 Data Encryption

| Layer       | Encryption Method                | Key Management      |
| ----------- | -------------------------------- | -------------------- |
| At Rest     | AES-256 (Dataverse TDE)          | Microsoft-managed    |
| In Transit  | TLS 1.2+                         | Certificate pinning  |
| Application | Base64 encoding (not encryption) | N/A                  |
| Backup      | AES-256                          | Microsoft-managed    |

> **Note:** Base64 encoding of documents is used for API transport compatibility only. Documents remain readable to authorized users in Dataverse.

---

## 5. Integration Architecture

### 5.1 Integration Layers

The platform follows a layered integration architecture:

```text
+-----------------------------------------------------------------+
|                     CLIENT LAYER                                 |
|  Power Automate | Power Apps | Custom Apps | Power Pages Portal  |
+-----------------------------------------------------------------+
         |               |            |               |
         v               v            v               v
+-----------------------------------------------------------------+
|                  API GATEWAY LAYER                               |
|          Dataverse Web API (OData v4)                            |
|          Custom Connector (Power Platform)                       |
|          Portal Web API (/_api/)                                 |
+-----------------------------------------------------------------+
         |                                            |
         v                                            v
+-----------------------------------------------------------------+
|                AUTHENTICATION LAYER                              |
|         Entra ID (OAuth 2.0 + OIDC + Conditional Access)        |
+-----------------------------------------------------------------+
         |
         v
+-----------------------------------------------------------------+
|              BROKER SERVICE LAYER                                |
|         Power Automate Orchestration Flows (10+)                 |
|         Environment Variables (cs_NintexApi*)                    |
+-----------------------------------------------------------------+
         |
         v
+-----------------------------------------------------------------+
|              SECRETS MANAGEMENT                                  |
|         Azure Key Vault (API credentials)                        |
+-----------------------------------------------------------------+
         |
         v
+-----------------------------------------------------------------+
|              EXTERNAL SAAS                                       |
|         Nintex AssureSign v3.7 (ca1.assuresign.net)              |
+-----------------------------------------------------------------+
```

### 5.2 Custom Connector Architecture

The Custom Connector provides a Power Platform-native interface to the broker's Dataverse OData endpoints, enabling Power Apps and Power Automate clients to interact with the broker without writing raw HTTP calls.

**Authentication:** OAuth 2.0 Authorization Code flow (for user-delegated access) or Client Credentials flow (for service principal access).

**Operations Exposed:**

| Operation      | HTTP Method | Dataverse Endpoint                     | Description               |
| -------------- | ----------- | -------------------------------------- | ------------------------- |
| CreateEnvelope | POST        | /cs_envelopes                          | Create draft envelope     |
| GetEnvelope    | GET         | /cs_envelopes({id})                    | Retrieve envelope details |
| ListEnvelopes  | GET         | /cs_envelopes                          | Query envelopes           |
| UpdateEnvelope | PATCH       | /cs_envelopes({id})                    | Modify or cancel envelope |
| DeleteEnvelope | DELETE      | /cs_envelopes({id})                    | Delete envelope           |
| AddSigner      | POST        | /cs_signers                            | Add signer to envelope    |
| UpdateSigner   | PATCH       | /cs_signers({id})                      | Modify signer             |
| RemoveSigner   | DELETE      | /cs_signers({id})                      | Delete signer             |
| AddDocument    | POST        | /cs_documents                          | Attach document           |
| RemoveDocument | DELETE      | /cs_documents({id})                    | Remove document           |
| GetSigners     | GET         | /cs_envelopes({id})/cs_envelope_signer | Get envelope signers      |
| ListTemplates  | GET         | /cs_templates                          | Available templates       |

### 5.3 OData Endpoint Integration

All Dataverse entities are accessible via the standard OData API at `https://{environment}.crm3.dynamics.com/api/data/v9.2/`. The API supports the full range of OData query options:

| Option   | Purpose                  | Example                       |
| -------- | ------------------------ | ----------------------------- |
| $filter  | Filter results           | statuscode eq 717640004       |
| $select  | Specify returned columns | cs_name,statuscode            |
| $expand  | Include related entities | cs_envelope_signer            |
| $orderby | Sort results             | createdon desc                |
| $top     | Limit result count       | 50                            |
| $skip    | Pagination offset        | 100                           |
| $count   | Include total count      | true                          |

### 5.4 Nintex AssureSign API Integration

**API Version:** 3.7
**Auth URL:** `https://account.assuresign.net/api/v3.7/authentication/apiUser`
**API Base URL:** `https://ca1.assuresign.net/api/documentnow/v3.7`
**Region:** Canadian (ca1)

Authentication to Nintex requires posting API credentials (username, key, and context username) to the authentication endpoint to obtain a bearer token valid for 60 minutes. The broker caches this token and automatically refreshes it before expiry. All Nintex credentials are stored as Dataverse environment variables in the ESignatureConfig solution.

**Environment Variables (ESignatureConfig solution):**

| Schema Name            | Purpose                                                    |
| ---------------------- | ---------------------------------------------------------- |
| cs_NintexApiUsername   | Nintex API username                                        |
| cs_NintexApiKey        | Nintex API key                                             |
| cs_NintexContextUsername| Nintex context username (user impersonation)               |
| cs_NintexAuthUrl       | Auth endpoint (default: `https://account.assuresign.net/api/v3.7`) |
| cs_NintexApiBaseUrl    | API base URL (default: `https://ca1.assuresign.net/api/documentnow/v3.7`) |

Environment variable values are read in flows via `ListRecords` on `environmentvariabledefinitions` with `$expand=environmentvariabledefinition_environmentvariablevalue`.

**Key Nintex API Endpoints:**

| Endpoint                                    | Method | Purpose                          |
| ------------------------------------------- | ------ | -------------------------------- |
| /authentication/apiUser                     | POST   | Obtain access token              |
| /submit                                     | POST   | Create and send envelope         |
| /templates                                  | GET    | List available templates         |
| /envelopes/{id}                             | GET    | Get envelope status              |
| /envelopes/{id}/signingLinks                | GET    | Retrieve per-signer signing URLs |
| /envelopes/{id}/history                     | GET    | Get envelope event history       |
| /envelopes/{id}/cancel                      | POST   | Cancel an active envelope        |

**Payload Mapping (Dataverse to Nintex):**

| Nintex Payload Property | Source                               |
| ----------------------- | ------------------------------------ |
| Subject                 | cs_envelope.cs_subject               |
| Message                 | cs_envelope.cs_message               |
| DaysToExpire            | cs_envelope.cs_daystoexpire          |
| ReminderFrequency       | cs_envelope.cs_reminderfrequency     |
| ProcessingMode          | cs_envelope.cs_processingmode        |
| Signers[].Email         | cs_signer.cs_email                   |
| Signers[].FullName      | cs_signer.cs_fullname                |
| Signers[].SignerOrder   | cs_signer.cs_signerorder             |
| Signers[].Language      | cs_signer.cs_language                |
| Documents[].FileName    | cs_document.cs_filename              |
| Documents[].FileContent | cs_document.cs_filecontent (Base64)  |

### 5.5 Broker Orchestration Flows

All flows use the **Microsoft Dataverse** connector (`shared_commondataserviceforapps`) with connection reference `cs_sharecommondataserviceforapps`.

**Technical Notes:**
- Entity names in triggers use singular logical name: `cs_envelope`, `cs_signer`, `cs_document`
- Entity names in actions use plural entity set name: `cs_envelopes`, `cs_signers`, `cs_documents`, `cs_templates`, `cs_accesslinks`, `cs_envelopehistories`
- `subscriptionRequest/filteringattributes` must be set on all webhook triggers that update the same entity to prevent infinite trigger loops
- Statuscode values are integers (not strings) -- use `717640001` not `"Preparing"`

| # | Flow Name                   | Trigger                          | Action                                                    |
| - | --------------------------- | -------------------------------- | --------------------------------------------------------- |
| 1 | **Prepare Envelope**        | Envelope statuscode = 717640001  | Calls Nintex API to prepare, sets statuscode = 717640002  |
| 2 | **Send Envelope**           | Envelope statuscode = 717640002  | Submits to Nintex API, sets statuscode = 717640003        |
| 3 | **Cancel Envelope**         | cs_iscancelled = true            | Cancels via Nintex API, sets statuscode = 717640006       |
| 4 | **Status Sync**             | Recurrence (30 min)              | Polls Nintex for In Process envelopes, updates statuses   |
| 5 | **Get Signing Links**       | Envelope statuscode = 717640003  | Retrieves signing URLs, updates signer records            |
| 6 | **Get Access Links**        | Envelope statuscode = 717640004  | Creates access link records for completed envelopes       |
| 7 | **Get Envelope History**    | cs_requesthistory = true         | Fetches history from Nintex, creates history records      |
| 8 | **Get Document Content**    | cs_requestsignedcopy = true      | Downloads signed document content from Nintex             |
| 9 | **Send Signer Reminder**    | cs_sendreminder = true           | Sends reminder via Nintex API                             |
| 10| **Sync Templates**          | Recurrence (daily)               | Syncs template list from Nintex API                       |
| 11| **Upsert Template**         | cs_template.cs_name change       | Upserts individual template to Nintex                     |

### 5.6 Error Handling Strategy

| Error Type           | Handling                          | Retry Logic                        | Notification                   |
| -------------------- | --------------------------------- | ---------------------------------- | ------------------------------ |
| Nintex API 5xx       | Log error, mark envelope Error    | 3 retries with exponential backoff | Admin alert after 3 failures   |
| Nintex API 4xx       | Log error, mark envelope Error    | No retry                           | Requestor notification         |
| Token Expired        | Refresh token automatically       | Automatic                          | None                           |
| Validation Error     | Return structured error to client | No retry                           | Client receives error response |
| Dataverse Throttling | Retry with backoff                | 5 retries                          | Admin alert if persistent      |
| Network Timeout      | Retry                             | 3 retries                          | Log incident                   |

---

## 6. Power Pages Portal Architecture

### 6.1 Overview

The Power Pages portal provides EC staff with a self-service web interface for managing e-signature workflows. The portal uses the Government of Canada **GCWeb (WET)** theme for compliance with federal web standards, is fully responsive for mobile and desktop use, and is built using the Power Pages **Enhanced Data Model** (using the `powerpagecomponent` table rather than legacy `adx_` prefixed tables).

```text
+-----------------------------------------------------------------------+
|                     BROWSER (EC Staff)                                  |
|  +------------------------------------------------------------------+ |
|  |                GCWeb/WET Responsive UI                            | |
|  |  PDF.js (rendering) + interact.js (drag-and-drop)                | |
|  +-----------------------------+------------------------------------+ |
+-----------------------------------------------------------------------+
                                 |
                                 | HTTPS (TLS 1.2+)
                                 v
+-----------------------------------------------------------------------+
|                    POWER PAGES (Canada Central)                        |
|  +------------------------------------------------------------------+ |
|  | Web Templates (Liquid + HTML + CSS + JS)                         | |
|  |   CS-Home-WET         -- Dashboard with stats and recent items   | |
|  |   CS-Templates        -- Template list with search/filter        | |
|  |   CS-Template-Editor  -- PDF field placement editor              | |
|  |   CS-Envelope-Editor  -- Envelope creation and signer config     | |
|  |   CS-Envelopes        -- Envelope list with status tracking      | |
|  +------------------------------------------------------------------+ |
|  | Portal Web API (/_api/)                                          | |
|  | Entra ID SSO (OpenID Connect)                                    | |
|  | Table Permissions (owner-based RLS)                              | |
+-----------------------------------------------------------------------+
                                 |
                                 | Dataverse Web API
                                 v
+-----------------------------------------------------------------------+
|                    DATAVERSE (Broker Environment)                      |
|  cs_envelope | cs_signer | cs_document | cs_template | annotation     |
+-----------------------------------------------------------------------+
                                 |
                                 | Power Automate Flows
                                 v
+-----------------------------------------------------------------------+
|                    NINTEX ASSURESIGN (ca1.assuresign.net)              |
+-----------------------------------------------------------------------+
```

### 6.2 Enhanced Data Model

The portal uses the Power Pages **Enhanced Data Model**, which stores all portal configuration in the `powerpagecomponent` table. This replaces the legacy model that used separate `adx_webpage`, `adx_webtemplate`, `adx_sitesetting`, and similar tables.

**Component types in `powerpagecomponent`:**

| Type Value | Component Type         | Purpose                                    |
| ---------- | ---------------------- | ------------------------------------------ |
| 2          | Web Page               | Portal page definition                     |
| 6          | Web Template Metadata  | Template metadata and configuration        |
| 7          | Content Snippet        | Reusable localized text fragments          |
| 8          | Web Template Source    | Liquid/HTML/CSS/JS template source code    |
| 9          | Site Setting           | Key-value portal configuration             |
| 18         | Table Permission       | Data access rules for portal users         |

This model enables targeted deployments via the Dataverse Web API, where individual components can be created, updated, or deleted by GUID without requiring full solution exports.

### 6.3 Web Templates

#### CS-Home-WET (Dashboard)

The home page displays a personalized dashboard for authenticated EC staff. It includes:

- Welcome message with the user's first name
- Overview stat tiles showing counts of available templates, completed envelopes, in-progress envelopes, and errors -- loaded asynchronously via the Portal Web API
- Recent envelopes table with status badges
- Quick-action links to create new envelopes or manage templates

The dashboard uses WET panel components and GCWeb colour tokens (`#26374A` for GC blue, `#AF3C43` for GC red, `#1B6C2A` for GC green).

#### CS-Templates (Template List)

Displays all available signature templates in a searchable, filterable list. Templates show their name, description, category, field count, and status. Users can create new templates or edit existing ones they own.

#### CS-Template-Editor (PDF Field Placement)

A full-screen editor for placing signature fields on PDF documents. The editor provides:

- **PDF rendering** via PDF.js 3.11 -- client-side rendering without server round-trips
- **Drag-and-drop field placement** via interact.js 1.10 -- users drag field types (Signature, Initial, Date, Text, Checkbox) onto the PDF canvas
- **Responsive layout** with a collapsible tools panel that moves to a bottom sheet on mobile devices
- **Top bar** with template name input, save/discard actions, and a hamburger menu for navigation
- **CSP compliance** -- no inline `on*` event handlers; Bootstrap Icons loaded via JS to avoid CSP hash issues
- **GC visual tokens** -- uses CSS custom properties (`--gc-blue`, `--gc-red`, `--gc-green`) for consistent branding

PDF documents are stored as Dataverse **annotations** (Notes) on the template record, supporting files up to 128 MB. This replaces the previous approach of storing base64 content in text columns (limited to ~1 MB).

#### CS-Envelope-Editor (Envelope Creation)

A guided envelope creation interface that supports two modes:

- **Create mode:** `?templateId=GUID&name=EnvelopeName` -- creates a new envelope from a template
- **Edit mode:** `?id=GUID` -- edits an existing draft envelope
- **Read-only mode:** automatically engaged when the envelope status is Preparing, In Process, or Completed

The editor includes signer configuration (name, email, language, order), envelope properties (subject, message, expiry), and a PDF preview panel showing the document with placed fields.

#### CS-Envelopes (Envelope List)

Displays the user's envelopes with status badges, filtering by status, and sorting options. Envelope status values are rendered with colour-coded badges matching the GCWeb palette.

### 6.4 PDF Storage via Annotations

Portal-uploaded PDF documents are stored as Dataverse **annotations** (the `annotation` / Notes table) rather than in text/memo columns on `cs_document` or `cs_template`. This design decision was made because:

| Approach          | Max File Size | Base64 Overhead | Native File Handling |
| ----------------- | ------------- | --------------- | -------------------- |
| Memo/Text column  | ~1 MB         | Yes (+33%)      | No                   |
| Annotation (Note) | 128 MB        | Yes (+33%)      | Yes                  |

Annotations are linked to their parent record via the `objectid` polymorphic lookup. The portal reads and writes annotations using the Portal Web API at `/_api/annotations`.

### 6.5 Responsive Design

The portal implements responsive design with the following breakpoints:

- **Desktop (>992px):** Side-by-side layout with tools panel on the left and PDF canvas on the right
- **Tablet (768-992px):** Stacked layout with collapsible tools panel
- **Mobile (<768px):** Full-width PDF canvas with a **bottom tools panel** that slides up from the bottom of the screen, providing touch-friendly field placement controls

The mobile bottom tools panel is a key UX feature that enables field placement on touch devices without obscuring the PDF canvas.

### 6.6 Portal Authentication Configuration

| Configuration Item | Value                                                    |
| ------------------ | -------------------------------------------------------- |
| Provider Type      | OpenID Connect (Entra ID)                                |
| Authority          | `https://login.microsoftonline.com/{tenant-id}/v2.0`    |
| Client ID          | Power Pages App Registration                             |
| Client Secret      | Stored in Azure Key Vault                                |
| Redirect URI       | `https://{portal-subdomain}.powerappsportals.com/signin-oidc` |
| Scopes             | openid, profile, email                                   |
| Session Timeout    | 8 hours (matches Conditional Access policy)              |
| Idle Timeout       | 2 hours                                                  |
| Claims Mapping     | email -> emailaddress1; name -> fullname; oid -> externalidentityid |
| Auto-Registration  | Enabled (creates Contact on first login)                 |

### 6.7 Portal Table Permissions

| Table                    | Access Type                         | Privileges                  |
| ------------------------ | ----------------------------------- | --------------------------- |
| cs_template (read)       | Global (all records)                | Read                        |
| cs_template (manage own) | Contact (ownerid = current Contact) | Create, Read, Write, Delete |
| cs_envelope              | Contact (ownerid = current Contact) | Create, Read, Write         |
| cs_document              | Parental (via cs_envelope)          | Create, Read, Append To     |
| cs_field                 | Parental (via cs_envelope)          | Create, Read, Append To     |
| cs_signer                | Parental (via cs_envelope)          | Create, Read, Append To     |

### 6.8 Portal Deployment

Portal components are deployed using targeted Dataverse Web API scripts rather than full solution exports:

- **`deploy-records.sh`** -- Generic tool for copying specific `powerpagecomponent` records (by GUID) or entire tables between environments
- **`deploy-web-template.sh`** -- Deploys individual web template source code to a target environment, supporting iterative development without full site redeployments
- **Deployment profiles** -- Environment-specific site settings stored in `deployment-profiles/` for each target environment (e.g., different portal URLs, authentication endpoints)

The portal site structure in source control follows the PAC CLI site format:

```text
power-pages/
  site/
    e-sign-dev---e-sign-dev/
      content-snippets/
      deployment-profiles/
      page-templates/
      sitesetting.yml
      table-permissions/
      web-pages/
      web-templates/
        cs-home-wet/
        cs-template-editor/
        cs-envelope-editor/
        cs-envelopes/
        cs-templates/
        ...
      webrole.yml
      website.yml
  templates/
    CS-Home-WET.liquid
    CS-Templates.liquid
    CS-Template-Editor.liquid
    CS-Envelope-Editor.liquid
    CS-Envelopes.liquid
```

---

<!-- ============================================================ -->
<!-- PART 3 -->
<!-- ============================================================ -->

# Part 3: Security & Monitoring

---

## 7. Security Architecture

### 7.1 Defence in Depth

The platform applies security controls across seven layers:

**Layer 1 -- Compliance:** Audit logging for all actions; ITSG-33 control alignment; PII management.

**Layer 2 -- Secrets:** Azure Key Vault for all credential storage; Managed Identities to eliminate secrets in code; quarterly secret rotation.

**Layer 3 -- Identity:** Entra ID authentication; Conditional Access policy enforcement; MFA for administrator accounts.

**Layer 4 -- Network:** TLS 1.2+ encryption in transit; optional IP restrictions; Azure Front Door DDoS protection.

**Layer 5 -- API Gateway:** OAuth 2.0 token validation; per-client API throttling; full request logging.

**Layer 6 -- Application:** Input validation (XSS and injection prevention); DLP policies; portal-specific file type whitelist and size controls; CSP headers on portal pages.

**Layer 7 -- Data:** AES-256 encryption at rest; Column-Level Security on sensitive fields; Row-Level Security for per-client and per-user data isolation.

### 7.2 Threat Model -- STRIDE Analysis

| Threat                 | Attack Vector                             | Mitigation                                            | Residual Risk |
| ---------------------- | ----------------------------------------- | ----------------------------------------------------- | ------------- |
| Spoofing               | Impersonate client application or service | OAuth 2.0, service principals, Entra ID SSO           | Low           |
| Tampering              | Modify envelope data                      | RLS, audit logging, immutable logs                    | Low           |
| Repudiation            | Deny sending an envelope                  | Complete audit trail in cs_apirequest                 | Low           |
| Information Disclosure | Access another application's data         | RLS, CLS, encryption                                  | Low           |
| Denial of Service      | Flood API or portal with requests         | API throttling, DLP policies, portal file size limits | Medium        |
| Elevation of Privilege | Gain admin access                         | Least privilege, MFA, PIM                             | Low           |

### 7.3 Data Classification

| Data Element                      | Classification | Encryption             | Access Control | Retention        |
| --------------------------------- | -------------- | ---------------------- | -------------- | ---------------- |
| Envelope metadata (name, subject) | Protected B    | At rest and in transit | RLS            | 7 years          |
| Signer PII (email, name, phone)   | Protected B    | At rest and in transit | RLS + CLS      | 7 years          |
| Document content (Base64)         | Protected B    | At rest and in transit | RLS            | 7 years          |
| Signing links                     | Protected B    | At rest and in transit | RLS + CLS      | Until expiry     |
| API request/response logs         | Protected B    | At rest and in transit | Admin only     | 7 years          |
| Nintex API credentials            | Secret         | Azure Key Vault        | MSI only       | Rotate quarterly |
| Client secrets                    | Secret         | Azure Key Vault        | Admin only     | 2-year maximum   |

### 7.4 PII Management

**PII Elements Stored:**

| Element       | Table     | Purpose                 | Legal Basis                            |
| ------------- | --------- | ----------------------- | -------------------------------------- |
| Email address | cs_signer | Contact signer          | Consent via envelope submission        |
| Full name     | cs_signer | Display on document     | Consent via envelope submission        |
| Phone number  | cs_signer | Optional contact method | Consent via envelope submission        |
| IP address    | cs_signer | Audit trail             | Legitimate interest (fraud prevention) |

**Data Subject Rights:**

| Right         | Implementation            | Response Time |
| ------------- | ------------------------- | ------------- |
| Access        | Export via Dataverse API  | 30 days       |
| Rectification | Update signer record      | Immediate     |
| Erasure       | Delete envelope (cascade) | 30 days       |
| Portability   | Export as JSON/CSV        | 30 days       |
| Objection     | Opt-out via configuration | Immediate     |

### 7.5 Portal Security Controls

| Control               | Implementation                     | Purpose                       |
| --------------------- | ---------------------------------- | ----------------------------- |
| Authentication        | Entra ID SSO (OIDC)                | Identity verification         |
| Authorization         | Table permissions (owner-based)    | Access control                |
| Row-Level Security    | ownerid field filtering            | Multi-user data isolation     |
| Encryption at Rest    | Dataverse TDE (AES-256)            | Data protection               |
| Encryption in Transit | TLS 1.2+ (HTTPS)                   | Network security              |
| Input Validation      | Client-side and server-side        | Prevent injection attacks     |
| File Type Validation  | Whitelist (.pdf only for portal)   | Malware surface reduction     |
| CSP Headers           | Restrict script sources            | Prevent XSS                   |
| Anti-CSRF             | Power Pages built-in tokens        | Prevent cross-site request forgery |
| Rate Limiting         | Power Pages throttling             | Abuse prevention              |
| Audit Logging         | Portal logs and Dataverse audit    | Compliance and forensic trail |

### 7.6 Portal Threat Mitigation

| Threat                            | Mitigation                                                     | Residual Risk |
| --------------------------------- | -------------------------------------------------------------- | ------------- |
| Unauthorized Access               | Entra ID MFA, Conditional Access                               | Low           |
| Cross-Site Scripting              | Input sanitization, CSP headers, no inline handlers            | Low           |
| CSRF                              | Anti-forgery tokens (Power Pages built-in)                     | Low           |
| OData Injection                   | Dataverse Web API parameterized queries                        | Low           |
| Session Hijacking                 | Secure cookies, HTTPS only, session timeout                    | Low           |
| Data Exfiltration                 | RLS, table permissions, audit logging                          | Low           |
| Denial of Service via Large Files | File size limits, rate limiting                                | Low           |

---

## 8. Monitoring, Logging & Audit

### 8.1 Monitoring Architecture

All logging sources flow into a central Log Analytics workspace (2-year retention). The primary data sources are:

- Dataverse Audit Logs
- Power Automate Run History
- Azure Monitor Metrics
- Application Insights (portal and API monitoring)
- Key Vault Logs
- Entra ID Sign-in Logs

Azure Monitor Dashboards provide three operational views: Operational Health (API success rates, latency, envelope volume), Security Monitoring (failed authentications, unusual IP addresses, privileged access events), and Client Usage (top clients by volume, completion rates, failed envelopes by client).

### 8.2 Logging Strategy

All Nintex API calls are logged to `cs_apirequest` records with the full request body, response body, HTTP status code, success flag, timestamp, and duration. This provides a complete Protected B-compliant audit trail for all Nintex interactions.

Portal activity is additionally logged to Application Insights via custom events and metrics, capturing page views, API call outcomes, and any client-side errors.

Retention: 7 years for Dataverse audit data and cs_apirequest records (Protected B requirement).

### 8.3 Alerting Rules

**Critical Alerts (Immediate Response):**

| Alert                  | Condition                   | Threshold        | Action                     |
| ---------------------- | --------------------------- | ---------------- | -------------------------- |
| Nintex API Failure     | HTTP 5xx errors             | >5 in 5 minutes  | Page on-call engineer      |
| Authentication Failure | 401/403 errors              | >10 in 5 minutes | Security team notification |
| Data Breach Attempt    | Cross-tenant access attempt | Any              | Immediate investigation    |
| Service Degradation    | API latency > 5 seconds     | 95th percentile  | Incident response          |

**Warning Alerts (Business Hours):**

| Alert                   | Condition                   | Threshold      | Action                 |
| ----------------------- | --------------------------- | -------------- | ---------------------- |
| Token Expiry            | Secret expires in <60 days  | N/A            | Rotation reminder      |
| High Error Rate         | Failed flows                | >10% in 1 hour | Investigate root cause |
| Storage Capacity        | Dataverse usage             | >80%           | Capacity planning      |
| Client Quota Exceeded   | Monthly envelope volume     | >Limit         | Billing notification   |

### 8.4 Audit Trail Requirements (ITSG-33)

All CRUD operations on Protected B data entities (`cs_envelope`, `cs_signer`, `cs_document`, `cs_field`, `cs_apirequest`) generate Dataverse audit log entries capturing the timestamp, user ID, operation type, entity name, and record ID. Service principal creation and deletion events are captured in Entra ID logs and can be queried via Log Analytics.

### 8.5 Log Retention

| Log Type                   | Retention Period | Archive Location          | Legal Hold |
| -------------------------- | ---------------- | ------------------------- | ---------- |
| Dataverse Audit Logs       | 7 years          | Azure Storage (Cool tier) | Available  |
| cs_apirequest              | 7 years          | In-place (Dataverse)      | Available  |
| Azure Monitor Logs         | 2 years          | Log Analytics             | Available  |
| Power Automate Run History | 28 days          | Power Platform            | N/A        |
| Entra ID Sign-in Logs      | 1 year           | Azure AD Premium          | Available  |
| Key Vault Access Logs      | 2 years          | Storage Account           | Available  |
| Application Insights       | 90 days          | Application Insights      | N/A        |

---

<!-- ============================================================ -->
<!-- PART 4 -->
<!-- ============================================================ -->

# Part 4: Operations & Compliance

---

## 9. Data Retention & Disposition

### 9.1 Retention Requirements (Protected B)

All Protected B data must be retained for a minimum of 7 years in accordance with Government of Canada standards.

### 9.2 Retention Policies

**Dataverse Data:**

| Entity        | Retention Period        | Disposition Method       | Trigger                  |
| ------------- | ----------------------- | ------------------------ | ------------------------ |
| cs_envelope   | 7 years from completion | Hard delete              | Automated daily job      |
| cs_signer     | 7 years from completion | Hard delete (cascade)    | Parent envelope deletion |
| cs_document   | 7 years from completion | Hard delete (cascade)    | Parent envelope deletion |
| cs_apirequest | 7 years from creation   | Hard delete              | Automated daily job      |
| cs_template   | Active templates only   | Soft delete (deactivate) | Manual                   |

The automated retention job runs daily at 2:00 AM. It exports envelopes past their 7-year mark to Azure Blob Storage (immutable, Cool tier) before deletion, then hard-deletes the Dataverse records in cascade order. API request records older than 7 years are deleted in batches of 1,000 to avoid throttling.

**Nintex AssureSign Data:**

| Data Type        | Nintex Retention | Disposition           | Notes                        |
| ---------------- | ---------------- | --------------------- | ---------------------------- |
| Envelopes        | 7 years          | Auto-delete by Nintex | Configurable in Nintex admin |
| Signed Documents | 7 years          | Auto-delete by Nintex | Downloadable before deletion |
| Audit Trails     | 7 years          | Auto-delete by Nintex | Export available             |

Before Nintex auto-deletion, the broker downloads signed documents via the `/getCompletedDocument` endpoint and stores them in Azure Blob Storage (immutable) as the authoritative archive copy.

### 9.3 Backup Strategy

| Component                 | Backup Frequency | Retention             | RPO       |
| ------------------------- | ---------------- | --------------------- | --------- |
| Dataverse (continuous)    | Continuous       | 28 days               | <1 hour   |
| Dataverse (manual weekly) | Weekly           | 90 days               | <24 hours |
| Key Vault                 | Continuous       | 90 days (soft-delete) | <1 hour   |

**RTO: 4 hours | RPO: 24 hours**

### 9.4 Legal Hold Process

When a legal hold is requested, the scope is defined in collaboration with Legal, affected records are identified and tagged with a legal hold flag, automated deletion is suspended for those records, and an export to immutable Azure Blob Storage is made. Chain of custody is documented. Upon hold release (following quarterly review), the legal hold flag is removed and normal retention resumes.

---

## 10. Client Onboarding Process

### 10.1 Onboarding Workflow

Client onboarding follows a structured lifecycle: intake and requirements gathering, service principal creation and Dataverse configuration, credential packaging and secure delivery, training and integration support, testing, production go-live, and ongoing monitoring with quarterly review.

### 10.2 Onboarding Timeline

Total typical timeline: **14-21 business days.**

| Phase        | Activities                                                                       | Duration    |
| ------------ | -------------------------------------------------------------------------------- | ----------- |
| Intake       | Requirements gathering, intake form completion                                   | Day 1       |
| Provisioning | Create service principal, configure Dataverse application user and security role | Days 1-2    |
| Delivery     | Package credentials, deliver via secure channel, provide integration guide       | Days 2-3    |
| Training     | Schedule and conduct training session                                            | Days 3-5    |
| Testing      | Client tests integration; issue resolution                                       | Days 7-14   |
| Go-Live      | Production approval, cutover, enhanced monitoring                                | Days 14-21  |
| Review       | Week 1 post-go-live review, Week 4 review                                        | Ongoing     |

### 10.3 Onboarding Checklist

**Phase 1: Intake (Day 1)**

| Field                     | Value        |
| ------------------------- | ------------ |
| App/Service Name          | [FILL]       |
| Primary Contact           | [FILL]       |
| Email                     | [FILL]       |
| Phone                     | [FILL]       |
| Dataverse Environment URL | [FILL]       |
| Expected Monthly Volume   | [FILL]       |
| Use Cases                 | [FILL]       |
| Security Clearance Level  | [FILL]       |

**Phase 2: Service Principal Creation (Day 1-2)**

Steps performed by the Security Lead:

1. Create App Registration in Entra ID (`ESign-{ServiceName}-Prod`)
2. Create Service Principal from App Registration
3. Generate client secret with 2-year expiry
4. Grant Dataverse API permissions and obtain admin consent
5. Store client secret in Azure Key Vault

**Phase 3: Dataverse Configuration (Day 2)**

| Setting                     | Value                    |
| --------------------------- | ------------------------ |
| Application User ID         | [FILL]                   |
| Service Principal Object ID | [FILL]                   |
| Security Role               | E-Signature Broker User  |
| Business Unit               | Root                     |

**Phase 4: Testing (Days 7-14)**

| Test Case | Description             | Expected Result                        |
| --------- | ----------------------- | -------------------------------------- |
| TC-001    | Create draft envelope   | Envelope created, status = Draft       |
| TC-002    | Add signer              | Signer added with cs_envelopelookup    |
| TC-003    | Add document            | Document attached                      |
| TC-004    | Set status = Preparing  | Prepare Envelope flow triggers         |
| TC-005    | Envelope reaches In Process | Status = 717640003, signing links populated |
| TC-006    | Get envelope details    | Data returned via OData                |
| TC-007    | List envelopes          | Only client's envelopes returned (RLS) |
| TC-008    | Per-client isolation    | Cannot access other client data        |
| TC-009    | Error handling          | Graceful error on invalid operations   |

### 10.4 Onboarding Roles & Responsibilities

| Role                   | Responsibilities                           |
| ---------------------- | ------------------------------------------ |
| Platform Lead          | Overall ownership and approvals            |
| Security Lead          | Service principal creation and permissions |
| Technical Lead         | Dataverse configuration and training       |
| Support Lead           | Documentation and ongoing support          |
| Client Project Manager | Client-side coordination                   |
| Client Technical Lead  | Integration development                    |

---

## 11. Environment Strategy

### 11.1 Environment Architecture

The platform currently maintains three Dataverse environments:

| Environment    | Unique Name        | Region          | Purpose                           | Nintex Account |
| -------------- | ------------------ | --------------- | --------------------------------- | -------------- |
| **DEV**        | goc-wetv14         | Canada Central  | Feature development, portal work  | Sandbox        |
| **EC DEV**     | dev-ec-esign-01    | Canada Central  | Elections Canada development      | Sandbox        |
| **EC TEST**    | test-ec-esign-01   | Canada Central  | Elections Canada testing/UAT      | Sandbox        |

Additional environments (Production, Disaster Recovery) will be provisioned during the production deployment phase.

### 11.2 Solution Deployment Workflow

Solutions are deployed using the PAC CLI and targeted Dataverse Web API scripts:

```text
  Source Control (Git)
        |
        v
  pac solution pack --zipFile <output.zip> --folder <source-folder>
        |
        v
  pac solution import --path <solution.zip> --publish-changes
        |
        v
  deploy-records.sh (targeted record deployments: powerpagecomponents, etc.)
        |
        v
  deploy-web-template.sh (individual web template updates)
```

**Solution Versioning Convention:**
- Source folder retains the original name (e.g., `ESignatureBroker_1_0_0_73/`)
- Version is bumped in `Other/Solution.xml` before each repack
- Zip filename includes the version number (e.g., `ESignatureBroker_1_0_0_73_unmanaged.zip`)

### 11.3 DLP Policies

The global DLP policy applies to all environments except Development:

**Allowed Connectors:** Dataverse (broker environment only), Azure Key Vault, Office 365 Outlook, Approvals, Custom Connector "ESign Elections Canada".

**Blocked Connectors:** All other connectors by default.

**Rules:** No data exfiltration to consumer services; no cross-environment data flows; all API calls must be audited.

---

## 12. Network Architecture

### 12.1 Network Topology

All inbound traffic from client applications and portal users passes through Azure Front Door (WAF and DDoS protection) before reaching the Power Platform endpoints over TLS 1.2+. The broker's Power Automate flows communicate outbound to Nintex AssureSign (`ca1.assuresign.net`) over HTTPS.

Azure services in Canada Central (Key Vault via Private Endpoint, Azure Monitor via Service Endpoint, Azure Storage via Private Endpoint) are accessible to Power Automate flows through managed connectors.

```text
                    Internet
                       |
                       v
              +------------------+
              | Azure Front Door |
              |   (WAF + DDoS)   |
              +--------+---------+
                       |
          +------------+-------------+
          |                          |
          v                          v
  +---------------+        +------------------+
  | Power Pages   |        | Dataverse        |
  | Portal        |        | Web API (OData)  |
  | (Portal Users)|        | (API Clients)    |
  +-------+-------+        +--------+---------+
          |                          |
          +------------+-------------+
                       |
                       v
              +------------------+
              | Dataverse        |
              | (Canada Central) |
              +--------+---------+
                       |
          +------------+-------------+
          |                          |
          v                          v
  +---------------+        +------------------+
  | Azure Key     |        | Nintex AssureSign |
  | Vault         |        | (ca1.assuresign  |
  | (Private EP)  |        |  .net)           |
  +---------------+        +------------------+
```

### 12.2 Latency Targets

| Endpoint                      | Target      | Measurement Method   |
| ----------------------------- | ----------- | -------------------- |
| Client/Portal to Dataverse    | <200 ms     | Azure Monitor        |
| Dataverse to Nintex API       | <500 ms     | Application Insights |
| End-to-End (Submit Envelope)  | <3 seconds  | Flow analytics       |
| Portal Page Load              | <2 seconds  | Application Insights |

---

## 13. Disaster Recovery & Business Continuity

### 13.1 Recovery Objectives

| Metric                            | Target              | Maximum Tolerable |
| --------------------------------- | ------------------- | ----------------- |
| RTO (Recovery Time Objective)     | 4 hours             | 8 hours           |
| RPO (Recovery Point Objective)    | 24 hours            | 48 hours          |
| MTTR (Mean Time To Repair)        | 2 hours             | 4 hours           |
| MTBF (Mean Time Between Failures) | 720 hours (30 days) | N/A               |

### 13.2 Disaster Scenarios

| Scenario                         | Type                | Response                                        |
| -------------------------------- | ------------------- | ----------------------------------------------- |
| Regional Outage (Canada Central) | Infrastructure      | Activate DR environment in Canada East          |
| Dataverse Corruption / Data Loss | Data                | Point-in-time restore from continuous backup    |
| Security Breach                  | Security            | Incident response and containment procedure     |
| Nintex Outage                    | External dependency | Wait for Nintex recovery; queue submissions     |
| Portal Outage                   | Infrastructure      | Restart portal; clients continue via API        |

### 13.3 Regional Outage Recovery Procedure (Hour-by-Hour)

**Hour 0-1: Assessment**
Verify outage scope via Azure Status page. Test broker API endpoint. Notify stakeholders with ETA of 4 hours.

**Hour 1-2: Activation**
Restore latest Dataverse backup to DR environment (Canada East). Monitor restore progress.

**Hour 2-3: Configuration**
Import Power Automate solutions from Git repository. Reconfigure Managed Identity access to Key Vault. Update DLP policies to include DR environment. Test Nintex integration from DR environment.

**Hour 3-4: Validation and Communication**
Submit 3 test envelopes end-to-end. Verify status sync. Send notification to all clients with the new temporary endpoint URL.

### 13.4 Security Breach Response

Upon breach detection: immediately revoke all client secrets and disable compromised accounts; enable IP restrictions to known GC IP ranges. Conduct forensic analysis to identify scope. If PII data was exfiltrated, invoke the Privacy Breach Protocol and notify the Privacy Commissioner. Remediate the vulnerability, issue new credentials, and apply enhanced monitoring for 30 days. Conclude with a post-incident review and security control updates.

**Incident Response Contacts:**

| Role                | Name   | Phone  | Email  |
| ------------------- | ------ | ------ | ------ |
| Incident Commander  | [FILL] | [FILL] | [FILL] |
| Security Lead       | [FILL] | [FILL] | [FILL] |
| Privacy Officer     | [FILL] | [FILL] | [FILL] |
| Communications Lead | [FILL] | [FILL] | [FILL] |

### 13.5 Critical Business Functions

| Function              | RTO | RPO | Dependencies                           |
| --------------------- | --- | --- | -------------------------------------- |
| Create Envelope       | 4h  | 24h | Dataverse, Entra ID                    |
| Send Envelope         | 4h  | 24h | Dataverse, Nintex, Key Vault           |
| Status Sync           | 8h  | 48h | Nintex API                             |
| Portal Access         | 4h  | 24h | Dataverse, Entra ID, Power Pages       |
| Client Onboarding     | 24h | N/A | Entra ID (manual process fallback)     |

---

## 14. Compliance & Governance (ITSG-33)

### 14.1 ITSG-33 Control Mapping

**Access Control (AC):**

| Control | Requirement                  | Implementation                                           |
| ------- | ---------------------------- | -------------------------------------------------------- |
| AC-1    | Access control policy        | Security roles, RLS, OAuth 2.0                           |
| AC-2    | Account management           | Service principals per client; quarterly review          |
| AC-3    | Access enforcement           | Dataverse RLS, security roles                            |
| AC-4    | Information flow enforcement | DLP policies, network isolation                          |
| AC-6    | Least privilege              | Minimal permissions per role                             |
| AC-7    | Unsuccessful logon attempts  | Entra ID lockout after 5 failures                        |
| AC-17   | Remote access                | VPN/Conditional Access required                          |
| AC-20   | Use of external systems      | Nintex via API only; portal via authenticated HTTPS only |

**Audit and Accountability (AU):**

| Control | Requirement                     | Implementation                     |
| ------- | ------------------------------- | ---------------------------------- |
| AU-2    | Audit events                    | All CRUD on Protected B data       |
| AU-3    | Content of audit records        | Timestamp, user, action, result    |
| AU-6    | Audit review                    | Weekly security team review        |
| AU-9    | Protection of audit information | Immutable storage, RBAC            |
| AU-11   | Audit record retention          | 7 years for Protected B            |
| AU-12   | Audit generation                | Dataverse, Azure Monitor, Entra ID |

**System and Communications Protection (SC):**

| Control | Requirement                       | Implementation                       |
| ------- | --------------------------------- | ------------------------------------ |
| SC-7    | Boundary protection               | DLP policies, TLS 1.2+               |
| SC-8    | Transmission confidentiality      | TLS 1.2+ for all communications      |
| SC-12   | Cryptographic key management      | Azure Key Vault, quarterly rotation  |
| SC-13   | Cryptographic protection          | AES-256 at rest, TLS 1.2+ in transit |
| SC-28   | Protection of information at rest | Dataverse TDE, Storage encryption    |

### 14.2 Privacy Impact Assessment (PIA)

**PII Collected:**

| PII Element  | Purpose                        | Legal Authority                 | Retention |
| ------------ | ------------------------------ | ------------------------------- | --------- |
| Signer email | Contact for signature request  | Consent via envelope submission | 7 years   |
| Signer name  | Display on document            | Consent via envelope submission | 7 years   |
| Signer phone | Optional contact method        | Consent via envelope submission | 7 years   |
| IP address   | Audit trail (fraud prevention) | Legitimate interest             | 7 years   |

**Privacy Controls Applied:** Collection limitation; data quality; purpose specification; use limitation; security safeguards; openness (privacy policy published); individual participation (data subject rights supported); accountability (Privacy Officer designated).

### 14.3 Compliance Summary

| Control Family                           | Total Controls | Implemented | Not Applicable |
| ---------------------------------------- | -------------- | ----------- | -------------- |
| AC: Access Control                       | 25             | 20          | 5              |
| AU: Audit and Accountability             | 16             | 16          | 0              |
| CM: Configuration Management             | 11             | 11          | 0              |
| CP: Contingency Planning                 | 13             | 13          | 0              |
| IA: Identification and Authentication    | 11             | 10          | 1              |
| SC: System and Communications Protection | 44             | 38          | 6              |
| SI: System and Information Integrity     | 23             | 20          | 3              |
| **TOTAL**                                | **143**        | **128**     | **15**         |

**Overall Compliance Rate: 90% (128/143 controls implemented)**

---

<!-- ============================================================ -->
<!-- PART 5 -- ANNEXES -->
<!-- ============================================================ -->

# Part 5: Annexes

---

## Annex A: Environment Configuration

### A.1 Environment URLs

| Environment | Unique Name      | URL                                     | Purpose                      |
| ----------- | ---------------- | --------------------------------------- | ---------------------------- |
| DEV         | goc-wetv14       | https://goc-wetv14.crm3.dynamics.com    | Feature development          |
| EC DEV      | dev-ec-esign-01  | https://dev-ec-esign-01.crm3.dynamics.com | Elections Canada development |
| EC TEST     | test-ec-esign-01 | https://test-ec-esign-01.crm3.dynamics.com | Elections Canada testing    |
| Production  | [FILL]           | https://[FILL].crm3.dynamics.com        | Live workloads               |
| DR          | [FILL]           | https://[FILL].crm4.dynamics.com        | Disaster recovery            |

### A.2 Azure Resources

| Resource Type          | Name               | Purpose                  | Resource Group |
| ---------------------- | ------------------ | ------------------------ | -------------- |
| Key Vault (Dev)        | [FILL]-dev-kv      | Dev secrets              | [FILL]         |
| Key Vault (Prod)       | [FILL]-prod-kv     | Production secrets       | [FILL]         |
| Storage Account        | [FILL]auditarchive | Audit log archive        | [FILL]         |
| Log Analytics          | broker-prod-logs   | Monitoring               | [FILL]         |
| Application Insights   | [FILL]-appi        | Portal monitoring        | [FILL]         |

### A.3 Nintex Configuration

| Environment | Account Type | Auth URL                                           | API Base URL                                                   |
| ----------- | ------------ | -------------------------------------------------- | -------------------------------------------------------------- |
| DEV         | Sandbox      | https://account.assuresign.net/api/v3.7            | https://ca1.assuresign.net/api/documentnow/v3.7               |
| EC DEV      | Sandbox      | https://account.assuresign.net/api/v3.7            | https://ca1.assuresign.net/api/documentnow/v3.7               |
| EC TEST     | Sandbox      | https://account.assuresign.net/api/v3.7            | https://ca1.assuresign.net/api/documentnow/v3.7               |
| Production  | Production   | https://account.assuresign.net/api/v3.7            | https://ca1.assuresign.net/api/documentnow/v3.7               |

### A.4 Solution Inventory

| Solution             | Unique Name        | Current Version | Environment(s)            |
| -------------------- | ------------------ | --------------- | ------------------------- |
| Nintex Schema        | nintex              | Latest          | All                       |
| E-Signature Config   | ESignatureConfig   | Latest          | All                       |
| E-Signature Broker   | ESignatureBroker   | 1.0.0.73        | All                       |
| E-Signature Client   | ESignatureClient   | Latest          | Client environments only  |

### A.5 Production Client Inventory

| App/Service | Service Principal | Onboarding Date | Monthly Volume |
| ----------- | ----------------- | --------------- | -------------- |
| [FILL]      | [FILL]            | [FILL]          | [FILL]         |

---

## Annex B: Security Controls Mapping (ITSG-33)

See Section 14.1 for detailed ITSG-33 control mapping tables. For the full security controls workbook including evidence references, test results, and remediation status for all 143 controls, refer to the separate Security Controls Workbook maintained by the Security Lead.

---

## Annex C: API Specifications

### C.1 Nintex AssureSign API Endpoints

**Base URL:** `https://ca1.assuresign.net/api/documentnow/v3.7`
**Auth URL:** `https://account.assuresign.net/api/v3.7/authentication/apiUser`

| Endpoint                         | Method | Purpose                          | Request Body / Params                   |
| -------------------------------- | ------ | -------------------------------- | --------------------------------------- |
| /authentication/apiUser          | POST   | Obtain access token              | {apiUsername, key, contextUsername}      |
| /submit                          | POST   | Create and send envelope         | Full envelope payload                   |
| /templates                       | GET    | List available templates         | None                                    |
| /envelopes/{id}                  | GET    | Get envelope details and status  | Path: envelope ID                       |
| /envelopes/{id}/signingLinks     | GET    | Retrieve per-signer signing URLs | Path: envelope ID                       |
| /envelopes/{id}/history          | GET    | Get envelope event history       | Path: envelope ID                       |
| /envelopes/{id}/cancel           | POST   | Cancel an active envelope        | Path: envelope ID                       |

### C.2 Dataverse OData Query Examples

**Get envelopes with status "In Process" (717640003):**
```
GET /api/data/v9.2/cs_envelopes?$filter=statuscode eq 717640003&$select=cs_name,statuscode
```

**Get envelope with signers expanded:**
```
GET /api/data/v9.2/cs_envelopes({guid})?$expand=cs_envelope_signer($select=cs_email,cs_fullname,statuscode)
```

**Get environment variable values (pattern used by all broker flows):**
```
GET /api/data/v9.2/environmentvariabledefinitions?$filter=startswith(schemaname,'cs_Nintex')&$expand=environmentvariabledefinition_environmentvariablevalue($select=value)&$select=schemaname
```

### C.3 Portal Web API Examples

**Create envelope via portal:**
```
POST /_api/cs_envelopes
Content-Type: application/json
{
  "cs_name": "Contract - John Smith",
  "cs_subject": "Please sign this contract",
  "statuscode": 1
}
```

**Create signer linked to envelope:**
```
POST /_api/cs_signers
Content-Type: application/json
{
  "cs_fullname": "John Smith",
  "cs_email": "john.smith@example.com",
  "cs_signerorder": 1,
  "cs_envelopelookup@odata.bind": "cs_envelopes({envelope-guid})"
}
```

**Upload PDF as annotation:**
```
POST /_api/annotations
Content-Type: application/json
{
  "subject": "Template PDF",
  "filename": "contract.pdf",
  "documentbody": "<base64-encoded-pdf>",
  "mimetype": "application/pdf",
  "objectid_cs_template@odata.bind": "cs_templates({template-guid})"
}
```

---

## Annex D: Troubleshooting Guide

### D.1 Common Issues (Broker Service)

**Issue: "Unauthorized" when calling the API**
Cause: Token is invalid or has expired.
Resolution: Verify the token's expiry and audience claim (the `aud` claim must match the broker Dataverse environment URL). Request a new token if expired.

**Issue: "Cannot access cs_envelopes"**
Cause: Missing security role assignment or incorrect environment URL.
Resolution: Verify the Application User exists in Dataverse and is assigned the E-Signature Broker User security role. Test the identity using a WhoAmI call to the Dataverse API.

**Issue: "Envelope stuck in Draft, won't progress"**
Cause: Missing signers or documents, or statuscode not set to Preparing (717640001).
Resolution: Retrieve the envelope with `$expand=cs_envelope_signer,cs_envelope_document` and verify at least one signer and one document exist. Set `statuscode` to `717640001` to trigger the Prepare Envelope flow.

**Issue: "Signer not receiving email"**
Cause: Email in spam, or envelope has not yet been sent to Nintex.
Resolution: Check the envelope status and `cs_preparedenvelopeid`. If status is In Process (717640003), the email was dispatched by Nintex -- check the signer's spam folder. Retrieve the signing link from `cs_signinglink` and deliver it via an alternative channel.

**Issue: "Envelope stuck in Preparing"**
Cause: Prepare Envelope flow failed or is not running.
Resolution: Check Power Automate flow run history for the Prepare Envelope flow. Verify the flow is turned on. Check `cs_responsebody` for Nintex API error details. Common causes include invalid template IDs or malformed document content.

**Issue: High API latency**
Cause: Large document payloads or Dataverse throttling.
Resolution: Use `$select` to limit returned fields; monitor the `x-ms-ratelimit-burst-remaining-xrm-requests` response header and implement exponential backoff if throttled.

### D.2 Common Issues (Portal)

**Issue: Portal login fails or loops**
Cause: Entra ID OpenID Connect misconfiguration or incorrect redirect URI.
Resolution: Verify the portal's authentication provider settings match the App Registration in Entra ID. Confirm the redirect URI matches exactly. Check for cookie-blocking browser extensions.

**Issue: PDF not rendering in template editor**
Cause: PDF.js library not loaded, or CORS/CSP blocking.
Resolution: Check browser developer console for errors. Verify the PDF.js CDN is allowed in the portal's Content Security Policy headers. Ensure the annotation record contains valid base64 document content.

**Issue: Fields not appearing after drag-and-drop**
Cause: interact.js library not loaded, or JavaScript error.
Resolution: Check browser console for errors. Clear browser cache and retry. Verify the web template source code is the latest version.

**Issue: Connection reference errors in deployed environment**
Cause: The Dataverse connection reference (`cs_sharecommondataserviceforapps`) is not configured in the target environment.
Resolution: After importing the ESignatureBroker solution, navigate to the solution's connection references and create or update the connection with valid credentials for the target environment.

### D.3 Support Escalation Matrix

| Severity       | Response Time | Escalation Path                                 |
| -------------- | ------------- | ----------------------------------------------- |
| P1 -- Critical | 15 minutes    | L1 -> L2 -> Platform Lead -> Incident Commander |
| P2 -- High     | 2 hours       | L1 -> L2 -> Technical Lead                      |
| P3 -- Medium   | 8 hours       | L1 -> L2                                        |
| P4 -- Low      | 24 hours      | L1                                              |

**Severity Definitions:**

- P1: Complete service outage or confirmed security breach
- P2: Significant degradation affecting multiple clients or portal users
- P3: Single client or user impacted; workaround available
- P4: Minor issue or enhancement request

### D.4 Vendor Support Contacts

| Vendor    | Service        | Support Number | Account ID |
| --------- | -------------- | -------------- | ---------- |
| Microsoft | Power Platform | 1-800-XXX-XXXX | [FILL]     |
| Microsoft | Azure Support  | 1-800-XXX-XXXX | [FILL]     |
| Nintex    | AssureSign     | 1-866-XXX-XXXX | [FILL]     |

---

## Glossary

| Term               | Definition                                                                                                   |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| Application User   | Dataverse user identity mapped to a service principal for API access                                         |
| Broker             | Intermediary service between client applications and Nintex AssureSign                                       |
| CLS                | Column-Level Security -- restricts access to specific fields in Dataverse                                    |
| Dataverse          | Microsoft's PaaS database platform within the Power Platform ecosystem                                       |
| DLP                | Data Loss Prevention -- policies to prevent data exfiltration between connectors                             |
| Enhanced Data Model| Power Pages architecture using `powerpagecomponent` table instead of legacy `adx_` tables                    |
| Envelope           | A signature request containing one or more documents and signers                                             |
| GCWeb              | Government of Canada web standards framework (Web Experience Toolkit)                                        |
| MSI                | Managed Service Identity -- Azure mechanism for service-to-service authentication without secrets            |
| OData              | Open Data Protocol -- REST-based data access standard used by Dataverse                                      |
| Power Pages        | Microsoft Power Platform product for building low-code external-facing web portals                           |
| RLS                | Row-Level Security -- restricts access to specific records based on the ownerid field                        |
| RPO                | Recovery Point Objective -- maximum acceptable data loss window                                              |
| RTO                | Recovery Time Objective -- maximum acceptable downtime window                                                |
| Service Principal  | Non-human Entra ID identity used for programmatic API access                                                 |
| TDE                | Transparent Data Encryption -- automatic Dataverse database encryption                                       |
| WET                | Web Experience Toolkit -- Government of Canada front-end framework                                           |

---

## Acronyms

| Acronym | Full Form                           |
| ------- | ----------------------------------- |
| API     | Application Programming Interface   |
| CAB     | Change Advisory Board               |
| CRUD    | Create, Read, Update, Delete        |
| CSP     | Content Security Policy             |
| DR      | Disaster Recovery                   |
| EC      | Elections Canada                    |
| ERD     | Entity Relationship Diagram         |
| ITSG    | IT Security Guidance                |
| MFA     | Multi-Factor Authentication         |
| MTBF    | Mean Time Between Failures          |
| MTTR    | Mean Time To Repair                 |
| OIDC    | OpenID Connect                      |
| PaaS    | Platform as a Service               |
| PAC     | Power Platform CLI                  |
| PIA     | Privacy Impact Assessment           |
| PII     | Personally Identifiable Information |
| RBAC    | Role-Based Access Control           |
| REST    | Representational State Transfer     |
| RLS     | Row-Level Security                  |
| SaaS    | Software as a Service               |
| SLA     | Service Level Agreement             |
| TLS     | Transport Layer Security            |
| TRA     | Threat and Risk Assessment          |
| UAT     | User Acceptance Testing             |
| WAF     | Web Application Firewall            |

---

*End of Document -- ESign Elections Canada SADD v2.0 -- April 2026*
