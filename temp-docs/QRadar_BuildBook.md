# Power Platform IBM QRadar Security Monitoring Build Book

**Audience:** IT Security / SOC / QRadar Administrators / Global Administrators
**Author:** Frederick Pearson, Platform Engineering
**Document type:** Standalone IM/IT ticket build book
**Status:** Draft for implementation
**Date:** 2026-04-21

## Table of contents

- [1 Document control](#document-control)
- [2 Implementation objective](#implementation-objective)
- [3 Execution rules for the
  administrator](#execution-rules-for-the-administrator)
- [4 Placeholder convention](#placeholder-convention)
- [5 Required evidence capture
  standard](#required-evidence-capture-standard)
- [6 Prerequisites](#prerequisites)
  - [6.1 Administrator access](#administrator-access)
  - [6.2 Platform prerequisites](#platform-prerequisites)
- [7 Implementation artifact
  placeholders](#implementation-artifact-placeholders)
- [8 Build steps](#build-steps)
  - [Create Event Hubs namespace for QRadar ingestion](#create-event-hubs-namespace-for-qradar-ingestion)
  - [Create Event Hubs, consumer group, and QRadar listen policy](#create-event-hubs-consumer-group-and-qradar-listen-policy)
  - [Create QRadar checkpoint storage account](#create-qradar-checkpoint-storage-account)
  - [Route Entra External ID logs to Event Hubs](#route-entra-external-id-logs-to-event-hubs)
  - [Create Microsoft Entra app registration for QRadar Office 365 REST
    API collection](#create-microsoft-entra-app-registration-for-qradar-office-365-rest-api-collection)
  - [Validate
    QRadar DSMs and protocols](#validate-qradar-dsms-and-protocols)
  - [Add QRadar Microsoft Office 365 / Purview audit log source](#add-qradar-microsoft-office-365-purview-audit-log-source)
  - [Add QRadar Microsoft Entra ID Event Hubs log source](#add-qradar-microsoft-entra-id-event-hubs-log-source)
  - [Create QRadar custom event properties for Power Platform audit
    payloads](#create-qradar-custom-event-properties-for-power-platform-audit-payloads)
  - [Create QRadar
    reference sets](#create-qradar-reference-sets)
  - [Create
    QRadar rules and offenses](#create-qradar-rules-and-offenses)
  - [Create QRadar saved searches and dashboard](#create-qradar-saved-searches-and-dashboard)
- [9 Support runbooks for
  QRadar offenses](#support-runbooks-for-qradar-offenses)
- [10 Final validation checklist](#final-validation-checklist)
- [11 Official references](#official-references)

## Document control

| Field                       | Value                                                                                                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Organization                | Elections Canada                                                                                                                                                                                       |
| Author                      | Frederick Pearson, Platform Engineering                                                                                                                                                                |
| Primary implementation team | IT Security / SOC / QRadar administrators / Global administrators                                                                                                                                      |
| Implementer role            | Global Administrator or delegated administrator with the specified Azure, Power Platform, Entra, Sentinel, or QRadar permissions                                                                       |
| Environment scope           | Production Power Platform environments, production Dataverse environments, external-facing Power Pages sites, and Entra External ID tenants or applications used for external registration and sign-in |
| Evidence requirement        | Every implementation step that changes configuration must be captured with a screenshot and saved to the evidence folder named in this build book                                                      |

## Implementation objective

Elections Canada will implement IBM QRadar as the SIEM layer for Power Platform and Entra External ID monitoring. The implementation will route Microsoft Entra logs through Azure Event Hubs, collect Microsoft 365/Purview audit events through the QRadar Microsoft Office 365 DSM, configure QRadar log sources, custom event properties, reference sets, offense rules, saved searches, dashboards, and evidence-ready SOC runbooks.

## Execution rules for the administrator

- Use the placeholders exactly as written when reading the procedure; replace them with approved Elections Canada values in the RFC/ticket before implementation.
- Use the Azure portal, Power Platform admin center, Microsoft Defender portal, Microsoft Entra admin center, Microsoft Purview portal, or QRadar Console as specified for each step.
- Run optional Azure PowerShell commands only from an administrative workstation approved for tenant administration.
- Save command output and screenshots in the evidence folder for the ticket.
- Do not close the ticket until every validation query, alert test, and evidence screenshot in the final checklist has been completed.

## Placeholder convention

| Placeholder                   | Meaning                                                             | Suggested Elections Canada value pattern                                 |
| ----------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `<EC-TENANT-ID>`            | Microsoft Entra tenant ID                                           | `<tenant-guid>`                                                        |
| `<EC-SUBSCRIPTION-ID>`      | Azure subscription ID used for monitoring resources                 | `<subscription-guid>`                                                  |
| `<EC-LOCATION>`             | Azure region for monitoring resources                               | `canadacentral`                                                        |
| `<EC-RG-MONITORING>`        | Resource group for monitoring resources                             | `rg-ec-pp-monitoring-prod-cca-001`                                     |
| `<EC-LAW-NAME>`             | Log Analytics workspace name                                        | `law-ec-pp-monitoring-prod-cca-001`                                    |
| `<EC-APPINSIGHTS-NAME>`     | Application Insights resource name                                  | `appi-ec-pp-operational-prod-cca-001`                                  |
| `<EC-ENVIRONMENT-NAME>`     | Power Platform environment display name                             | `EC-PowerPlatform-Prod`                                                |
| `<EC-ENVIRONMENT-ID>`       | Power Platform environment GUID                                     | `<environment-guid>`                                                   |
| `<EC-POWERPAGES-URL>`       | Production Power Pages URL                                          | `https://<portal-name>.powerappsportals.com` or approved custom domain |
| `<EC-EXTERNALID-TENANT-ID>` | Entra External ID tenant ID                                         | `<external-tenant-guid>`                                               |
| `<EC-EXTERNALID-APP-ID>`    | App registration/client ID used by Power Pages sign-in/registration | `<application-client-id>`                                              |
| `<EC-EVIDENCE-FOLDER>`      | Evidence folder for implementation screenshots                      | `EC-PP-Monitoring-RFC-<ticket-number>`                                 |

## Required evidence capture standard

- Capture the full browser page or the relevant configuration pane after every configuration save.
- Ensure the screenshot shows the artifact name, tenant/subscription context, and final state.
- Name screenshots using the pattern `<step-number>-<short-description>-<yyyy-mm-dd>.png`.
- Capture command output by saving the PowerShell transcript to `<EC-EVIDENCE-FOLDER>/powershell-transcript.txt`.
- Store exported CSV/JSON results from validation queries in `<EC-EVIDENCE-FOLDER>/validation-results/`.

## Prerequisites

### Administrator access

| Requirement            | Required value                                                                                                                                                    |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Microsoft Entra role   | Global Administrator or Security Administrator for app registrations and diagnostic settings                                                                      |
| Azure RBAC             | Owner or Contributor on `<EC-SUBSCRIPTION-ID>` for Event Hubs, storage account, and diagnostic routing                                                          |
| Microsoft Purview role | Audit Logs or View-Only Audit Logs for validation; appropriate role to enable audit evidence access                                                               |
| QRadar role            | QRadar administrator with permissions to install DSM/protocol updates, add log sources, create custom event properties, rules, offenses, searches, and dashboards |
| Network/firewall       | QRadar Event Collector can reach Azure Event Hubs over port 5671 and Azure Storage over port 443                                                                  |
| Evidence access        | Write access to `<EC-EVIDENCE-FOLDER>`                                                                                                                          |

### Platform prerequisites

- IBM QRadar Console and Event Collectors are operational and licensed for the required ingestion volume.
- QRadar DSM/protocol components for Microsoft Office 365, Microsoft Entra ID, and Microsoft Azure Event Hubs are installed or approved for installation.
- Microsoft Purview audit is enabled for Power Platform activity evidence.
- Production Power Platform environments and Entra External ID applications in scope are documented.
- Event Hubs and a storage account are required for QRadar collection of Entra and Azure logs.

## Implementation artifact placeholders

| Placeholder                            | Suggested value                         |
| -------------------------------------- | --------------------------------------- |
| `<EC-EH-NAMESPACE>`                  | `evhns-ec-ppsec-prod-cca-001`         |
| `<EC-EH-ENTRA-NAME>`                 | `evh-ec-entra-extid-prod-001`         |
| `<EC-EH-POWERPLATFORM-NAME>`         | `evh-ec-pp-audit-prod-001`            |
| `<EC-EH-CG-QRADAR>`                  | `cg-qradar`                           |
| `<EC-EH-SAS-LISTEN>`                 | `qradar-listen`                       |
| `<EC-SA-QRADAR-CHECKPOINT>`          | `stecqradarppprod001`                 |
| `<EC-QRADAR-O365-LOGSOURCE>`         | `EC-M365-Purview-PowerPlatform-Audit` |
| `<EC-QRADAR-ENTRA-LOGSOURCE>`        | `EC-Entra-ExternalID-EventHub`        |
| `<EC-QRADAR-REFERENCESET-ADMINS>`    | `EC_PP_Approved_Admins`               |
| `<EC-QRADAR-REFERENCESET-COUNTRIES>` | `EC_Approved_Countries`               |

## Build steps

### Create Event Hubs namespace for QRadar ingestion

::: {.step}

**Portal procedure**

- In the Azure portal, search for **Event Hubs**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Select resource group `<EC-RG-MONITORING>`.
- Enter namespace name `<EC-EH-NAMESPACE>`.
- Select location `<EC-LOCATION>`.
- Select pricing tier approved by the RFC.
- Select **Review + create**.
- Select **Create**.
- Open the namespace overview after deployment.

**Optional Azure PowerShell**

```powershell
New-AzEventHubNamespace `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -NamespaceName "<EC-EH-NAMESPACE>" `
  -Location "<EC-LOCATION>" `
  -SkuName "Standard"
```

:::

::: {.evidence}
Capture `02-event-hubs-namespace-overview.png`.
:::

### Create Event Hubs, consumer group, and QRadar listen policy

::: {.step}

**Portal procedure**

- Open Event Hubs namespace `<EC-EH-NAMESPACE>`.
- Select **Entities** > **Event Hubs**.
- Select **+ Event Hub**.
- Create event hub `<EC-EH-ENTRA-NAME>` for Entra External ID logs.
- Set partition count to `<EC-EH-PARTITION-COUNT>`.
- Set message retention to `<EC-EH-RETENTION-DAYS>`.
- Select **Review + create** and **Create**.
- Open `<EC-EH-ENTRA-NAME>`.
- Select **Consumer groups**.
- Select **+ Consumer group**.
- Enter `<EC-EH-CG-QRADAR>`.
- Select **Create**.
- Select **Shared access policies**.
- Select **+ Add**.
- Enter policy name `<EC-EH-SAS-LISTEN>`.
- Select **Listen**.
- Select **Create**.
- Open the policy and securely store the primary connection string in the approved secret repository for QRadar configuration.

**Optional Azure PowerShell**

```powershell
New-AzEventHub `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -NamespaceName "<EC-EH-NAMESPACE>" `
  -Name "<EC-EH-ENTRA-NAME>" `
  -PartitionCount <EC-EH-PARTITION-COUNT> `
  -MessageRetentionInDays <EC-EH-RETENTION-DAYS>

New-AzEventHubConsumerGroup `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -NamespaceName "<EC-EH-NAMESPACE>" `
  -EventHubName "<EC-EH-ENTRA-NAME>" `
  -Name "<EC-EH-CG-QRADAR>"

New-AzEventHubAuthorizationRule `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -NamespaceName "<EC-EH-NAMESPACE>" `
  -EventHubName "<EC-EH-ENTRA-NAME>" `
  -Name "<EC-EH-SAS-LISTEN>" `
  -Rights @("Listen")
```

:::

::: {.evidence}
Capture `03-event-hub-consumer-group-and-listen-policy.png`. Do not include full secrets in screenshots.
:::

### Create QRadar checkpoint storage account

::: {.step}

**Portal procedure**

- In the Azure portal, search for **Storage accounts**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>` and resource group `<EC-RG-MONITORING>`.
- Enter storage account name `<EC-SA-QRADAR-CHECKPOINT>`.
- Select region `<EC-LOCATION>`.
- Select performance **Standard** and redundancy approved by the RFC.
- Select **Review + create**.
- Select **Create**.
- Open the storage account.
- Select **Access keys**.
- Securely store the required connection string for QRadar checkpointing in the approved secret repository.

**Optional Azure PowerShell**

```powershell
New-AzStorageAccount `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -Name "<EC-SA-QRADAR-CHECKPOINT>" `
  -Location "<EC-LOCATION>" `
  -SkuName "Standard_LRS" `
  -Kind "StorageV2" `
  -AllowBlobPublicAccess $false
```

:::

::: {.evidence}
Capture `04-qradar-checkpoint-storage-overview.png`. Do not capture full access keys.
:::

### Route Entra External ID logs to Event Hubs

::: {.step}

**Portal procedure**

- Sign in to the Microsoft Entra admin center.
- Browse to **Entra ID** > **Monitoring & health** > **Diagnostic settings**.
- Select **Add diagnostic setting**.
- Enter name `<EC-DIAG-EXTID-EVENTHUB-NAME>`.
- Select log categories required for QRadar monitoring:
  - **AuditLogs**.
  - **SignInLogs**.
  - **NonInteractiveUserSignInLogs** when available.
  - **ServicePrincipalSignInLogs** when available.
  - **ProvisioningLogs** when required by the RFC.
- Select **Stream to an event hub**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Select Event Hubs namespace `<EC-EH-NAMESPACE>`.
- Select event hub `<EC-EH-ENTRA-NAME>`.
- Select shared access policy with send permissions if the portal requests it.
- Select **Save**.

**Optional Azure PowerShell note**

- Use portal configuration for tenant-level Entra diagnostic settings when the administrative Az module does not expose the Microsoft Entra diagnostic scope. Export the diagnostic setting configuration as screenshot evidence.

:::

::: {.evidence}
Capture `05-entra-diagnostic-to-event-hub.png` showing the log categories and destination Event Hub.
:::

### Create Microsoft Entra app registration for QRadar Office 365 REST API collection

::: {.step}

**Portal procedure**

- Open the Microsoft Entra admin center.
- Select **Applications** > **App registrations**.
- Select **New registration**.
- Enter name `<EC-APPREG-QRADAR-O365-AUDIT>`.
- Select **Accounts in this organizational directory only**.
- Select **Register**.
- Copy the **Application (client) ID** and **Directory (tenant) ID** to the approved secret repository.
- Select **Certificates & secrets**.
- Select **New client secret**.
- Enter description `<EC-APPREG-QRADAR-O365-SECRET-DESC>`.
- Select an approved expiry period based on Elections Canada secret rotation policy.
- Select **Add**.
- Copy the secret **Value** to the approved secret repository.
- Select **API permissions**.
- Select **Add a permission**.
- Select **Office 365 Management APIs**.
- Select **Application permissions**.
- Add the approved activity feed permissions required for audit collection, including the activity feed read permission required by QRadar.
- Select **Grant admin consent**.

**Optional Azure PowerShell**

```powershell
# Microsoft Graph PowerShell can be used when approved by the identity team.
# The portal method is retained as the evidence source for this ticket.
```

:::

::: {.evidence}
Capture `06-qradar-app-registration-overview.png`, `06-qradar-api-permissions.png`, and `06-qradar-admin-consent.png`. Do not capture secret values.
:::

### Validate QRadar DSMs and protocols

::: {.step}

**QRadar Console procedure**

- Sign in to the QRadar Console with QRadar administrator credentials.
- Open **Admin**.
- Open **Extensions Management** or the DSM/protocol management location used by the Elections Canada QRadar version.
- Confirm current components are installed:
  - Microsoft Office 365 DSM.
  - Office 365 REST API Protocol.
  - Microsoft Entra ID DSM.
  - Microsoft Azure Event Hubs Protocol.
- Install or update the DSM/protocol RPMs if the QRadar platform owner has approved the update.
- Deploy changes if QRadar prompts for deployment.

:::

::: {.evidence}
Capture `07-qradar-dsm-protocols-installed.png` showing component versions.
:::

### Add QRadar Microsoft Office 365 / Purview audit log source

::: {.step}

**QRadar Console procedure**

- Open **Admin**.
- Select **Data Sources** > **Events** > **Log Sources**.
- Select **Add**.
- Enter log source name `<EC-QRADAR-O365-LOGSOURCE>`.
- Set **Log Source Type** to **Microsoft Office 365**.
- Set **Protocol Configuration** to **Office 365 REST API**.
- Enter **Log Source Identifier** `<EC-QRADAR-O365-LOGSOURCE>`.
- Enter **Tenant ID** `<EC-TENANT-ID>`.
- Enter **Client ID** from `<EC-APPREG-QRADAR-O365-AUDIT>`.
- Enter **Client Secret** from the approved secret repository.
- Set **Event Filter** to include the approved audit event categories required for Power Platform and compliance evidence, including **General**, **Azure Active Directory**, and **DLP** where available.
- Save the log source.
- Deploy changes when prompted.
- Use **Test** if available.

:::

::: {.evidence}
Capture `08-qradar-o365-logsource-configured.png` and `08-qradar-o365-logsource-test.png`. Mask secrets.
:::

### Add QRadar Microsoft Entra ID Event Hubs log source

::: {.step}

**QRadar Console procedure**

- Open **Admin**.
- Select **Data Sources** > **Events** > **Log Sources**.
- Select **Add**.
- Enter log source name `<EC-QRADAR-ENTRA-LOGSOURCE>`.
- Set **Log Source Type** to **Microsoft Entra ID**.
- Set **Protocol Configuration** to **Microsoft Azure Event Hubs**.
- Set authentication method to **SAS** or approved **Entra ID** authentication.
- Enter Event Hub connection string or approved tenant/client/secret values.
- Enter Event Hub name `<EC-EH-ENTRA-NAME>`.
- Enter consumer group `<EC-EH-CG-QRADAR>`.
- Enter storage account connection string for `<EC-SA-QRADAR-CHECKPOINT>` when requested by the protocol.
- Save the log source.
- Deploy changes when prompted.
- Use the QRadar protocol test tool and confirm successful connection.

:::

::: {.evidence}
Capture `09-qradar-entra-eventhub-logsource.png` and `09-qradar-entra-eventhub-test-success.png`. Mask secrets.
:::

### Create QRadar custom event properties for Power Platform audit payloads

::: {.step}

**QRadar Console procedure**

- Open **Admin**.
- Select **Custom Event Properties**.
- Create or validate these properties for Microsoft 365/Purview audit payloads that contain Power Platform records:
  - `EC_PP_Workload` - extracts workload or service name from payload.
  - `EC_PP_Operation` - extracts operation/activity name.
  - `EC_PP_Actor` - extracts user principal name or actor.
  - `EC_PP_EnvironmentId` - extracts Power Platform environment ID.
  - `EC_PP_ObjectId` - extracts app, flow, connector, DLP policy, or portal object identifier.
  - `EC_PP_ClientIP` - extracts client IP if present.
  - `EC_PP_ResultStatus` - extracts result or status if present.
- Use JSON property extraction where supported by QRadar for JSON events.
- Test each property against recent Microsoft Office 365 audit events.
- Save each property.
- Deploy changes if QRadar prompts for deployment.

:::

::: {.evidence}
Capture `10-qradar-custom-event-properties.png` and `10-custom-property-test-results.png`.
:::

### Create QRadar reference sets

::: {.step}

**QRadar Console procedure**

- Open **Admin**.
- Select **Reference Set Management**.
- Create reference set `<EC-QRADAR-REFERENCESET-ADMINS>` with type **Alphanumeric**.
- Populate it with approved Power Platform administrators.
- Create reference set `<EC-QRADAR-REFERENCESET-COUNTRIES>` with type **Alphanumeric**.
- Populate it with approved country or region codes for Power Pages / external sign-in activity.
- Create reference set `<EC-QRADAR-REFERENCESET-APPIDS>` with approved Power Pages and Entra External ID application IDs.
- Save all reference sets.

:::

::: {.evidence}
Capture `11-qradar-reference-sets.png`.
:::

### Create QRadar rules and offenses

Create each rule in QRadar using **Offenses** > **Rules** or the rule wizard location used by the Elections Canada QRadar version. Enable offense creation for each security rule.

#### Rule Q-01 - Power Platform environment changed outside approved change window

| Field       | Configuration                                                                                                                       |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-PP-ENV-CHANGE-OUTSIDE-WINDOW>`                                                                                   |
| Rule type   | Event rule                                                                                                                          |
| Severity    | 8                                                                                                                                   |
| Credibility | 7                                                                                                                                   |
| Relevance   | 8                                                                                                                                   |
| Log source  | `<EC-QRADAR-O365-LOGSOURCE>`                                                                                                      |
| Purpose     | Generate an offense when Power Platform environment create, delete, or update activity is observed outside the approved RFC window. |

**Rule logic**

- Apply to events from `<EC-QRADAR-O365-LOGSOURCE>`.
- Match when `EC_PP_Operation` contains `Environment` and contains one of `Create`, `Delete`, `Remove`, `Update`.
- Exclude events whose actor is approved and whose timestamp is inside an approved change window.
- Dispatch a new offense indexed by `EC_PP_Actor` and `EC_PP_EnvironmentId`.

::: {.evidence}
Capture `12-q01-env-change-rule.png`.
:::

#### Rule Q-02 - Power Platform DLP policy modified

| Field       | Configuration                                                                   |
| ----------- | ------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-PP-DLP-MODIFIED>`                                            |
| Severity    | 8                                                                               |
| Credibility | 7                                                                               |
| Relevance   | 8                                                                               |
| Log source  | `<EC-QRADAR-O365-LOGSOURCE>`                                                  |
| Purpose     | Generate an offense when Power Platform DLP configuration changes are observed. |

**Rule logic**

- Match events where `EC_PP_Operation` or raw payload contains `DLP`, `Dlp`, or `Policy`.
- Match operations containing `Create`, `Update`, `Delete`, `Set`, or `Remove`.
- Exclude only approved change-window events documented in the ticket.

::: {.evidence}
Capture `12-q02-dlp-modified-rule.png`.
:::

#### Rule Q-03 - Custom connector changed

| Field       | Configuration                                                                                                             |
| ----------- | ------------------------------------------------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-PP-CUSTOM-CONNECTOR-CHANGE>`                                                                           |
| Severity    | 6                                                                                                                         |
| Credibility | 6                                                                                                                         |
| Relevance   | 7                                                                                                                         |
| Log source  | `<EC-QRADAR-O365-LOGSOURCE>`                                                                                            |
| Purpose     | Generate an offense or notable event when a custom connector is created, updated, deleted, or connection settings change. |

**Rule logic**

- Match `EC_PP_Operation` or payload fields containing `Connector`, `CustomConnector`, or `Connection`.
- Match change verbs `Create`, `Update`, `Delete`, `Remove`, `Set`.
- Group by actor and object ID.

::: {.evidence}
Capture `12-q03-custom-connector-rule.png`.
:::

#### Rule Q-04 - Power Pages site configuration changed

| Field       | Configuration                                                                                                 |
| ----------- | ------------------------------------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-POWERPAGES-CONFIG-CHANGE>`                                                                 |
| Severity    | 7                                                                                                             |
| Credibility | 6                                                                                                             |
| Relevance   | 8                                                                                                             |
| Log source  | `<EC-QRADAR-O365-LOGSOURCE>`                                                                                |
| Purpose     | Generate an offense when external-facing Power Pages configuration or authentication-related settings change. |

**Rule logic**

- Match payload values containing `Power Pages`, `PowerPages`, `Portal`, `Website`, or the approved Power Pages site identifier.
- Match change verbs `Create`, `Update`, `Delete`, `Set`, `Change`.
- Index offense by actor and site/object ID.

::: {.evidence}
Capture `12-q04-power-pages-config-rule.png`.
:::

#### Rule Q-05 - Dataverse high-volume destructive activity

| Field       | Configuration                                                                      |
| ----------- | ---------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-DATAVERSE-MASS-DELETE>`                                         |
| Severity    | 9                                                                                  |
| Credibility | 7                                                                                  |
| Relevance   | 8                                                                                  |
| Log source  | `<EC-QRADAR-O365-LOGSOURCE>`                                                     |
| Purpose     | Generate an offense when Dataverse delete activity exceeds the approved threshold. |

**Rule logic**

- Match Dataverse or Dynamics audit events where operation includes `Delete`.
- Trigger when more than `<EC-DATAVERSE-DELETE-THRESHOLD>` matching events are seen from the same actor in `<EC-DATAVERSE-DELETE-WINDOW-MINUTES>` minutes.
- Group by actor, environment ID, and entity/object ID where available.

::: {.evidence}
Capture `12-q05-dataverse-mass-delete-rule.png`.
:::

#### Rule Q-06 - Entra External ID sign-in failure spike

| Field       | Configuration                                                                                                            |
| ----------- | ------------------------------------------------------------------------------------------------------------------------ |
| Rule name   | `<EC-QRADAR-RULE-EXTID-SIGNIN-FAILURE-SPIKE>`                                                                          |
| Severity    | 6                                                                                                                        |
| Credibility | 6                                                                                                                        |
| Relevance   | 8                                                                                                                        |
| Log source  | `<EC-QRADAR-ENTRA-LOGSOURCE>`                                                                                          |
| Purpose     | Generate an offense when sign-in failures against the Power Pages External ID application exceed the approved threshold. |

**Rule logic**

- Match Entra sign-in events for application ID `<EC-EXTERNALID-APP-ID>`.
- Match failed result codes or failure status.
- Trigger when failures are greater than `<EC-EXTID-FAILURE-THRESHOLD>` in `<EC-EXTID-FAILURE-WINDOW-MINUTES>` minutes.
- Index by source IP and application ID.

::: {.evidence}
Capture `12-q06-external-id-failure-rule.png`.
:::

#### Rule Q-07 - Entra External ID risky sign-in or unusual geography

| Field       | Configuration                                                                                   |
| ----------- | ----------------------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-EXTID-RISKY-OR-GEO-SIGNIN>`                                                  |
| Severity    | 8                                                                                               |
| Credibility | 7                                                                                               |
| Relevance   | 8                                                                                               |
| Log source  | `<EC-QRADAR-ENTRA-LOGSOURCE>`                                                                 |
| Purpose     | Generate an offense when External ID sign-in activity is risky or from an unapproved geography. |

**Rule logic**

- Match app ID `<EC-EXTERNALID-APP-ID>`.
- Match risk fields indicating medium/high risk when those fields are available.
- Match source country/region not present in `<EC-QRADAR-REFERENCESET-COUNTRIES>`.
- Index by user and source IP.

::: {.evidence}
Capture `12-q07-external-id-risk-geo-rule.png`.
:::

#### Rule Q-08 - Application credential added to Power Pages / External ID application

| Field       | Configuration                                                                                                                           |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Rule name   | `<EC-QRADAR-RULE-APP-CREDENTIAL-ADDED-POWERPAGES>`                                                                                    |
| Severity    | 9                                                                                                                                       |
| Credibility | 8                                                                                                                                       |
| Relevance   | 8                                                                                                                                       |
| Log source  | `<EC-QRADAR-ENTRA-LOGSOURCE>`                                                                                                         |
| Purpose     | Generate an offense when a credential, secret, or certificate is added to the identity application used by external-facing Power Pages. |

**Rule logic**

- Match audit activity containing credential or secret addition/update.
- Match target app ID `<EC-EXTERNALID-APP-ID>` or display name `<EC-POWERPAGES-APP-DISPLAY-NAME>`.
- Exclude only approved rotation windows.

::: {.evidence}
Capture `12-q08-app-credential-added-rule.png`.
:::

### Create QRadar saved searches and dashboard

::: {.step}

**QRadar Console procedure**

- Open **Log Activity**.
- Create and save searches for:
  - Power Platform administrative activity by actor.
  - DLP policy changes.
  - Custom connector changes.
  - Power Pages configuration changes.
  - Entra External ID sign-in failures by source IP.
  - External ID risky or unapproved geography sign-ins.
- Create a QRadar dashboard named `<EC-QRADAR-DASHBOARD-PP-SECURITY>`.
- Add widgets based on the saved searches.
- Save the dashboard.

**Example AQL searches**

```sql
SELECT QIDNAME(qid) AS EventName, "EC_PP_Actor", "EC_PP_Operation", "EC_PP_EnvironmentId", COUNT(*) AS EventCount
FROM events
WHERE LOGSOURCENAME(logsourceid) = '<EC-QRADAR-O365-LOGSOURCE>'
GROUP BY "EC_PP_Actor", "EC_PP_Operation", "EC_PP_EnvironmentId"
LAST 24 HOURS
```

```sql
SELECT sourceip, username, COUNT(*) AS FailedSignIns
FROM events
WHERE LOGSOURCENAME(logsourceid) = '<EC-QRADAR-ENTRA-LOGSOURCE>'
AND UTF8(payload) ILIKE '%<EC-EXTERNALID-APP-ID>%'
AND (UTF8(payload) ILIKE '%failure%' OR UTF8(payload) ILIKE '%ResultType%')
GROUP BY sourceip, username
LAST 1 HOURS
```

:::

::: {.evidence}
Capture `13-qradar-dashboard-created.png` and export saved-search screenshots.
:::

## Support runbooks for QRadar offenses

| QRadar rule                                          | First response                                                | Initial triage                                                                                | Escalation owner                                                              | Closure criteria                                                                               | Tuning notes                                                                      |
| ---------------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------- |
| `<EC-QRADAR-RULE-PP-ENV-CHANGE-OUTSIDE-WINDOW>`    | SOC acknowledges offense and checks associated RFC.           | Review actor, source IP, environment ID, raw event payload, and change ticket.                | SOC to Power Platform administrator.                                          | Approved change is linked or unauthorized action is contained and incident record is complete. | Maintain change-window reference set.                                             |
| `<EC-QRADAR-RULE-PP-DLP-MODIFIED>`                 | SOC treats as high-priority governance event.                 | Validate DLP policy, actor, affected connectors, and before/after change where available.     | SOC to Power Platform governance owner.                                       | Change is approved or reverted and impact documented.                                          | Use approved admin reference set to reduce noise, not suppress all admin changes. |
| `<EC-QRADAR-RULE-PP-CUSTOM-CONNECTOR-CHANGE>`      | SOC validates connector endpoint and authentication settings. | Review connector owner, target endpoint, data classifications, and approval record.           | SOC to Power Platform administrator/API owner.                                | Connector is approved or disabled/removed.                                                     | Whitelist approved deployment service principals only through reference set.      |
| `<EC-QRADAR-RULE-POWERPAGES-CONFIG-CHANGE>`        | SOC checks whether public-facing site exposure changed.       | Review site setting, authentication setting, actor, and deployment history.                   | SOC to Power Pages owner and Identity team.                                   | Change is approved or rolled back.                                                             | Tune non-production separately from production.                                   |
| `<EC-QRADAR-RULE-DATAVERSE-MASS-DELETE>`           | SOC treats as potential destructive activity.                 | Validate user, entity, delete count, source IP, and whether bulk delete job was approved.     | SOC to Dataverse owner; escalate to IR for unauthorized destructive activity. | Activity is approved or contained; recovery requirement assessed.                              | Thresholds must be table-specific for high-value data.                            |
| `<EC-QRADAR-RULE-EXTID-SIGNIN-FAILURE-SPIKE>`      | SOC checks for outage, brute force, or misconfiguration.      | Review source IP, countries, result codes, app ID, and recent identity configuration changes. | SOC to Identity team; escalate to IT Ops for service failure.                 | Failure rate returns to baseline or attack/misconfiguration is contained.                      | Tune by baseline and public campaign periods.                                     |
| `<EC-QRADAR-RULE-EXTID-RISKY-OR-GEO-SIGNIN>`       | SOC assesses identity risk.                                   | Review risk fields, source geography, MFA/CA status, and account history.                     | SOC to Identity team.                                                         | Risk is remediated, dismissed with justification, or access is blocked.                        | Approved geography reference set must be maintained.                              |
| `<EC-QRADAR-RULE-APP-CREDENTIAL-ADDED-POWERPAGES>` | SOC treats as high-priority persistence event.                | Verify app ID, credential type, actor, and secret rotation change record.                     | SOC to Identity/application owner.                                            | Credential is approved or removed; secret rotation documented.                                 | Exclude approved rotation windows only.                                           |

## Final validation checklist

- Event Hubs namespace `<EC-EH-NAMESPACE>` exists.
- Event Hub `<EC-EH-ENTRA-NAME>` exists with consumer group `<EC-EH-CG-QRADAR>` and listen policy `<EC-EH-SAS-LISTEN>`.
- Storage account `<EC-SA-QRADAR-CHECKPOINT>` exists for QRadar checkpointing.
- Entra External ID diagnostic setting streams logs to Event Hubs.
- App registration `<EC-APPREG-QRADAR-O365-AUDIT>` exists with approved API permissions and admin consent.
- QRadar DSM/protocol components are installed.
- QRadar Office 365 log source `<EC-QRADAR-O365-LOGSOURCE>` is created and receiving events.
- QRadar Entra ID Event Hubs log source `<EC-QRADAR-ENTRA-LOGSOURCE>` is created and receiving events.
- Custom event properties for Power Platform payload extraction are created and tested.
- Reference sets are created and populated.
- Rules Q-01 through Q-08 are created and enabled.
- Dashboard `<EC-QRADAR-DASHBOARD-PP-SECURITY>` is created.
- Screenshots and QRadar exports are saved to `<EC-EVIDENCE-FOLDER>`.

```powershell
Stop-Transcript
```

## Official references

- IBM Docs - Microsoft Office 365 DSM for QRadar: https://www.ibm.com/docs/en/dsm?topic=microsoft-office-365
- IBM Docs - Microsoft Entra ID DSM for QRadar: https://www.ibm.com/docs/en/dsm?topic=microsoft-entra-id
- IBM Docs - Microsoft Azure Event Hubs protocol for QRadar: https://www.ibm.com/docs/en/dsm?topic=options-microsoft-azure-event-hubs-protocol-configuration
- IBM Docs - Configure Microsoft Azure Event Hubs to communicate with QRadar: https://www.ibm.com/docs/en/dsm?topic=options-configuring-microsoft-azure-event-hubs-communicate-qradar
- Microsoft Learn - Configure Microsoft Entra diagnostic settings: https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-configure-diagnostic-settings
- Microsoft Learn - Stream Microsoft Entra logs to an Event Hub: https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-stream-logs-to-event-hub
- Microsoft Learn - Prepare Azure resources for exporting security alerts to QRadar: https://learn.microsoft.com/en-us/azure/defender-for-cloud/export-to-splunk-or-qradar
- Microsoft Learn - Power Platform activity logs and auditing in Microsoft Purview: https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-overview
