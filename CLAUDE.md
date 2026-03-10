# CLAUDE.md — Project Instructions for Nintex AssureSign Broker Service

## Overview

This project involves a **Nintex AssureSign e-signature broker service** built on the **Power Platform** (Power Automate, Power Pages, Dataverse). All development, solution management, and CLI operations must follow Microsoft's official documentation and patterns described below.

---

## Authoritative Documentation Sources

Always prefer and reference the following **official Microsoft documentation** sources. Do not infer or guess API shapes, connector schemas, or CLI flags — look them up from these sources first:

### Power Platform

* Overview: https://learn.microsoft.com/en-us/power-platform/
* Admin & governance: https://learn.microsoft.com/en-us/power-platform/admin/

### Power Automate

* Cloud flows: https://learn.microsoft.com/en-us/power-automate/
* HTTP connector / custom connectors: https://learn.microsoft.com/en-us/connectors/custom-connectors/
* Flow expressions (fx): https://learn.microsoft.com/en-us/azure/logic-apps/workflow-definition-language-functions-reference

### Dataverse

* Web API reference: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/webapi/overview
* Table/column schema: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/entity-metadata
* SDK for .NET: https://learn.microsoft.com/en-us/power-apps/developer/data-platform/org-service/overview

### Power Pages

* Developer docs: https://learn.microsoft.com/en-us/power-pages/
* Web API (Power Pages): https://learn.microsoft.com/en-us/power-pages/configure/web-api-overview

### Solution Management

* Solution concepts: https://learn.microsoft.com/en-us/power-platform/alm/solution-concepts-alm
* Solution layers & ALM: https://learn.microsoft.com/en-us/power-platform/alm/
* Managed vs unmanaged: https://learn.microsoft.com/en-us/power-platform/alm/managed-unmanaged-solutions
* Solution patches & clones: https://learn.microsoft.com/en-us/power-platform/alm/update-solutions-alm

### PAC CLI (Power Platform CLI)

* Full CLI reference: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/
* Install & auth: https://learn.microsoft.com/en-us/power-platform/developer/cli/introduction
* `pac solution` commands: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/solution
* `pac auth` commands: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/auth
* `pac connector` commands: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/connector
* `pac power-fx`: https://learn.microsoft.com/en-us/power-platform/developer/cli/reference/power-fx

---

## PAC CLI — Standard Workflow

Always use the following PAC CLI patterns for this project.

### Authentication

```bash
# Add a service principal auth profile (preferred for CI/CD)
pac auth create --environment <env-url> --applicationId <app-id> --clientSecret <secret> --tenant <tenant-id>

# Or interactive (dev only)
pac auth create --environment <env-url>

# List profiles
pac auth list

# Select profile
pac auth select --index <n>
```

### Solution Management

```bash
# Export managed solution
pac solution export --name NintexBrokerService --path ./solutions/NintexBrokerService --managed

# Export unmanaged (dev)
pac solution export --name NintexBrokerService --path ./solutions/NintexBrokerService --managed false

# Import solution
pac solution import --path ./solutions/NintexBrokerService.zip --activate-plugins

# Publish all customizations
pac solution publish

# Check solution for issues (Solution Checker)
pac solution check --path ./solutions/NintexBrokerService.zip --outputDirectory ./checker-results

# Clone a solution for patching
pac solution clone --name NintexBrokerService --outputDirectory ./solutions/clone

# Create a patch
pac solution create-patch --solution-name NintexBrokerService --patch-name NintexBrokerService_Patch_v1

# Pack local solution folder into zip
pac solution pack --zipFile ./solutions/NintexBrokerService.zip --folder ./solutions/NintexBrokerService

# Unpack solution zip to source files
pac solution unpack --zipFile ./solutions/NintexBrokerService.zip --folder ./solutions/NintexBrokerService
```

### Custom Connector (Nintex / AssureSign API)

```bash
# Download connector definition
pac connector download --connector-id <connector-id> --outputDirectory ./connectors/nintex-assuresign

# Create/update connector from local definition
pac connector create --settings-file ./connectors/nintex-assuresign/settings.json

# List connectors in environment
pac connector list
```

---

## Project Architecture Notes

### Nintex AssureSign Broker Pattern

This broker service sits between Power Automate flows and the Nintex AssureSign API. Key design constraints:

* The **broker is a Dataverse-backed API layer** — all signature transaction state is persisted in Dataverse tables
* Power Automate calls the broker via **HTTP with Azure AD / Entra ID auth** (not direct Nintex credentials in flows)
* The broker translates Power Automate-friendly request schemas into Nintex AssureSign REST API calls
* Webhook callbacks from Nintex are received by a **Power Pages Web API endpoint** or an  **Azure Function** , then written back to Dataverse
* All Nintex API credentials are stored as **Power Platform Environment Variables** (type: `Secret` or `String`) within the solution — never hardcoded

### Solution Structure

* Solution name: `NintexBrokerService`
* Publisher prefix: `cloudstrucc` (or as configured)
* Solution type: **Managed** for all non-dev environments
* All environment-specific values (URLs, credentials, endpoints) use **Environment Variables** — never literal values inside flows or connectors

### Environment Promotion Order

```
Dev (unmanaged) → Test (managed import) → UAT (managed import) → Prod (managed import)
```

---

## Coding & Configuration Standards

### Power Automate Flows

* Use **child flows** for reusable logic (e.g., token refresh, error handling, Nintex API call wrappers)
* All HTTP actions calling external APIs must include:
  * Retry policy (exponential, 4 retries)
  * Error handling scope with `Configure run after` set to failed/timed out
  * Structured logging to a Dataverse `BrokerLog` table
* Use `Parse JSON` with full schema — never use dynamic content from unparsed HTTP responses directly

### Dataverse Tables

* Follow Dataverse naming conventions: `cr_` prefix for custom columns, solution publisher prefix for tables
* All broker transaction tables must include:
  * `StatusCode` (choice column, not plain text)
  * `CreatedOn`, `ModifiedOn` (system — do not duplicate)
  * `CorrelationId` (text, for end-to-end tracing)

### Environment Variables

* All secrets/URLs must be Environment Variables of type `Secret` or `String` — no Key Vault integration at this stage
* Reference pattern in flows: `@parameters('environmentVariableName')`
* Never use string literals for environment URLs, API keys, or tenant IDs in any flow or connector definition

---

## What NOT to Do

* Do not use the **legacy XRM tooling** or SOAP endpoint — use Dataverse Web API or SDK only
* Do not hardcode credentials anywhere — use Power Platform Environment Variables (`Secret` type)
* Do not deploy unmanaged solutions to Test/UAT/Prod
* Do not manually edit solution zip files — always unpack → edit source → repack via `pac solution`
* Do not create flows outside the solution — all assets must be solution-aware
* Do not use deprecated `Common Data Service` connector in flows — use **Microsoft Dataverse** connector only
