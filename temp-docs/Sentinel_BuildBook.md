# Power Platform Microsoft Sentinel Security Monitoring Build Book

**Audience:** IT Security / SOC / Sentinel Administrators / Global Administrators
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
  - [Enable Microsoft Sentinel on the Log Analytics workspace](#enable-microsoft-sentinel-on-the-log-analytics-workspace)
  - [Validate Purview and Power Platform audit prerequisites](#validate-purview-and-power-platform-audit-prerequisites)
  - [Install the Microsoft Business Applications solution](#install-the-microsoft-business-applications-solution)
  - [Configure Power Platform data connectors](#configure-power-platform-data-connectors)
  - [Connect Entra ID and Entra External ID logs to Sentinel](#connect-entra-id-and-entra-external-id-logs-to-sentinel)
  - [Create Sentinel
    watchlists](#create-sentinel-watchlists)
  - [Enable built-in Microsoft Business Applications analytics rules](#enable-built-in-microsoft-business-applications-analytics-rules)
  - [Create Elections Canada custom Sentinel analytics rules](#create-elections-canada-custom-sentinel-analytics-rules)
  - [Configure automation and notification routing](#configure-automation-and-notification-routing)
  - [Create
    the Sentinel workbook view](#create-the-sentinel-workbook-view)
- [9 Support runbooks for
  Sentinel incidents](#support-runbooks-for-sentinel-incidents)
- [10 Final validation checklist](#final-validation-checklist)
- [11 Official references](#official-references)

## Document control

| Field                       | Value                                                                                                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Organization                | Elections Canada                                                                                                                                                                                       |
| Author                      | Frederick Pearson, Platform Engineering                                                                                                                                                                |
| Primary implementation team | IT Security / SOC / Sentinel administrators / Global administrators                                                                                                                                    |
| Implementer role            | Global Administrator or delegated administrator with the specified Azure, Power Platform, Entra, Sentinel, or QRadar permissions                                                                       |
| Environment scope           | Production Power Platform environments, production Dataverse environments, external-facing Power Pages sites, and Entra External ID tenants or applications used for external registration and sign-in |
| Evidence requirement        | Every implementation step that changes configuration must be captured with a screenshot and saved to the evidence folder named in this build book                                                      |

## Implementation objective

Elections Canada will implement Microsoft Sentinel as the security monitoring and SIEM layer for Power Platform, Dataverse, Power Automate, Power Pages, and Entra External ID. The implementation will enable Sentinel on the approved Log Analytics workspace, install Microsoft Business Applications security content, connect Power Platform and Entra logs, create watchlists, enable analytics rules, create custom detections, and document SOC runbooks.

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

| Requirement             | Required value                                                                                                                                            |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Microsoft Entra role    | Global Administrator or Security Administrator for identity and connector configuration                                                                   |
| Azure RBAC              | Contributor or Microsoft Sentinel Contributor on `<EC-LAW-NAME>` and `<EC-RG-MONITORING>`                                                             |
| Microsoft Sentinel role | Microsoft Sentinel Contributor for setup; Microsoft Sentinel Reader for SOC read-only validation                                                          |
| Power Platform role     | Power Platform Administrator or Dynamics 365 Administrator, plus Environment Administrator/System Administrator for each production Dataverse environment |
| Microsoft Purview role  | Audit Logs or View-Only Audit Logs for validation; appropriate Purview admin role for audit configuration                                                 |
| Evidence access         | Write access to `<EC-EVIDENCE-FOLDER>`                                                                                                                  |

### Platform prerequisites

- Log Analytics workspace `<EC-LAW-NAME>` is required and must be enabled for Microsoft Sentinel.
- Microsoft Purview audit logging is required for Power Platform audit and activity log collection.
- Production Dataverse environments must have auditing enabled where Dataverse audit monitoring is in scope.
- Power Platform environments in scope must be identified by approved environment names and IDs.
- Entra External ID logs must be routed to the workforce tenant Log Analytics workspace when the external tenant is separate.

## Implementation artifact placeholders

| Placeholder                           | Suggested value                     |
| ------------------------------------- | ----------------------------------- |
| `<EC-SENTINEL-WORKSPACE>`           | `<EC-LAW-NAME>`                   |
| `<EC-SENTINEL-SOLUTION-NAME>`       | `Microsoft Business Applications` |
| `<EC-SENTINEL-INCIDENT-RG>`         | `<EC-RG-MONITORING>`              |
| `<EC-WATCHLIST-APPROVED-ADMINS>`    | `wl-ec-pp-approved-admins`        |
| `<EC-WATCHLIST-APPROVED-COUNTRIES>` | `wl-ec-pp-approved-countries`     |
| `<EC-WATCHLIST-CHANGE-WINDOWS>`     | `wl-ec-pp-change-windows`         |
| `<EC-SOC-ACTION-GROUP>`             | `ag-ec-soc-sentinel-prod-001`     |

## Build steps

### Enable Microsoft Sentinel on the Log Analytics workspace

::: {.step}

**Portal procedure**

- Sign in to the Azure portal or Microsoft Defender portal using the approved admin account.
- Open **Microsoft Sentinel**.
- Select **Create** or **Add**.
- Select workspace `<EC-LAW-NAME>`.
- Select **Add**.
- Wait for the workspace to finish onboarding.
- Open Microsoft Sentinel and select workspace `<EC-LAW-NAME>`.

**Optional Azure PowerShell / ARM deployment pattern**

```powershell
# Deploy Microsoft Sentinel enablement through ARM when approved by the tenant administration team.
# This pattern enables the SecurityInsights solution for the workspace.
$Template = @'
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "resources": [
    {
      "type": "Microsoft.OperationsManagement/solutions",
      "apiVersion": "2015-11-01-preview",
      "name": "SecurityInsights(<EC-LAW-NAME>)",
      "location": "<EC-LOCATION>",
      "properties": {
        "workspaceResourceId": "<EC-LAW-RESOURCE-ID>"
      },
      "plan": {
        "name": "SecurityInsights(<EC-LAW-NAME>)",
        "publisher": "Microsoft",
        "product": "OMSGallery/SecurityInsights",
        "promotionCode": ""
      }
    }
  ]
}
'@
$Template | Out-File "$EvidenceRoot/powershell-output/enable-sentinel-template.json" -Encoding utf8
New-AzResourceGroupDeployment -ResourceGroupName "<EC-RG-MONITORING>" -TemplateFile "$EvidenceRoot/powershell-output/enable-sentinel-template.json"
```

:::

::: {.evidence}
Capture `02-sentinel-workspace-enabled.png` showing `<EC-LAW-NAME>` in Microsoft Sentinel.
:::

### Validate Purview and Power Platform audit prerequisites

::: {.step}

**Portal procedure**

- Open the Microsoft Purview portal.
- Open **Audit** and verify audit search is available to the administrator.
- Open the Power Platform admin center.
- Select **Manage** > **Environments**.
- Select production environment `<EC-ENVIRONMENT-NAME>`.
- Select **Settings**.
- Expand **Product**.
- Select **Privacy + Security**.
- Verify organization auditing is enabled.
- Enable **Auditing** if not already enabled.
- Enable the setting that allows Microsoft Purview audit access to the environment activity logs, when shown in the environment settings.
- Save the configuration.

**Optional PowerShell note**

- This prerequisite is validated in the Power Platform admin center and Microsoft Purview portal. Capture portal evidence because the GUI state is the implementation evidence for the ticket.

:::

::: {.evidence}
Capture `03-purview-audit-access.png` and `03-power-platform-environment-auditing.png`.
:::

### Install the Microsoft Business Applications solution

::: {.step}

**Portal procedure**

- Open Microsoft Sentinel for workspace `<EC-LAW-NAME>`.
- Select **Content hub**.
- Search for **Microsoft Business Applications**.
- Select the solution.
- Select **Install**.
- Wait for installation to complete.
- Open the solution details and confirm installed content includes data connectors, analytics rules, workbooks, hunting queries, playbooks, and parsers where available.

**Optional Azure PowerShell note**

- Microsoft Sentinel content hub installation is performed through the Microsoft Sentinel portal/Defender portal. Export the installed solution details after installation for evidence.

:::

::: {.evidence}
Capture `04-content-hub-business-applications-installed.png`.
:::

### Configure Power Platform data connectors

::: {.step}

**Portal procedure**

- In Microsoft Sentinel workspace `<EC-LAW-NAME>`, select **Configuration** > **Data connectors**.
- Search for **Microsoft Power Platform Admin Activity**.
- Open the connector page.
- Select **Open connector page**.
- Follow the connector instructions and connect the data source.
- Repeat for **Microsoft Dataverse**.
- Repeat for **Microsoft Power Automate** when available in the installed solution.
- Confirm the connector status changes to **Connected** or shows data received.

**Post-connection validation queries**

```kusto
PowerPlatformAdminActivity
| where TimeGenerated > ago(24h)
| summarize Records=count() by EventOriginalType, EnvironmentId
| order by Records desc
```

```kusto
DataverseActivity
| where TimeGenerated > ago(24h)
| summarize Records=count() by Operation, EntityName, ResultStatus
| order by Records desc
```

:::

::: {.evidence}
Capture `05-power-platform-connectors-connected.png` and export the query results as CSV.
:::

### Connect Entra ID and Entra External ID logs to Sentinel

::: {.step}

**Portal procedure**

- Open Microsoft Sentinel workspace `<EC-LAW-NAME>`.
- Select **Content hub**.
- Search for **Microsoft Entra ID** and install the content if not already installed.
- Select **Data connectors**.
- Open the **Microsoft Entra ID** connector page.
- Select the log types required for Power Pages and external identity investigation:
  - `SigninLogs`.
  - `AuditLogs`.
  - `AADNonInteractiveUserSignInLogs` when available.
  - `AADServicePrincipalSignInLogs` when available.
  - Risk-related sign-in or user risk tables when licensed and available.
- Apply changes.
- For Entra External ID customer tenants, route logs to `<EC-LAW-NAME>` in the workforce tenant first, then use Microsoft Sentinel against that workspace.

**Validation query**

```kusto
SigninLogs
| where TimeGenerated > ago(24h)
| where AppId == "<EC-EXTERNALID-APP-ID>" or AppDisplayName has "<EC-POWERPAGES-APP-DISPLAY-NAME>"
| summarize SignIns=count(), Failures=countif(ResultType != 0), Risky=countif(IsRisky == true) by AppDisplayName
```

:::

::: {.evidence}
Capture `06-entra-id-connector-connected.png` and `06-external-id-signinlogs-validation.png`.
:::

### Create Sentinel watchlists

::: {.step}

**Portal procedure**

- In Microsoft Sentinel workspace `<EC-LAW-NAME>`, select **Configuration** > **Watchlist**.
- Select **New**.
- Create watchlist `<EC-WATCHLIST-APPROVED-ADMINS>` with columns `UserPrincipalName`, `Role`, `Owner`, `Notes`.
- Upload the approved administrators CSV from the RFC package.
- Create watchlist `<EC-WATCHLIST-APPROVED-COUNTRIES>` with columns `CountryCode`, `CountryName`, `ApprovalReason`.
- Upload the approved geography CSV from the RFC package.
- Create watchlist `<EC-WATCHLIST-CHANGE-WINDOWS>` with columns `StartTimeUtc`, `EndTimeUtc`, `ChangeTicket`, `ApprovedBy`.
- Upload the approved change windows CSV.

**Optional Azure PowerShell note**

- Watchlists can be deployed through Sentinel REST/ARM automation in a later automation package. For the initial ticket, upload and validate watchlists through the portal to establish evidence.

:::

::: {.evidence}
Capture `07-sentinel-watchlists-created.png` showing all three watchlists.
:::

### Enable built-in Microsoft Business Applications analytics rules

::: {.step}

**Portal procedure**

- Open Microsoft Sentinel workspace `<EC-LAW-NAME>`.
- Select **Analytics**.
- Select **Rule templates**.
- Filter by solution **Microsoft Business Applications**.
- Enable built-in templates relevant to Power Platform and Dataverse, including detections for anomalous Dataverse activity, suspicious Power Apps activity, suspicious data destruction, mass deletion, and Power Automate activity by departing users where available.
- For each rule:
  - Select the template.
  - Select **Create rule**.
  - Keep the rule enabled.
  - Set severity according to the Elections Canada severity mapping.
  - Map entities when prompted.
  - Set incident creation to **Enabled**.
  - Select **Review + create**.
  - Select **Create**.

:::

::: {.evidence}
Capture `08-business-apps-analytics-rules-enabled.png` showing enabled rules.
:::

### Create Elections Canada custom Sentinel analytics rules

Create each custom rule using **Analytics** > **Create** > **Scheduled query rule**. Use workspace `<EC-LAW-NAME>`. Use incident creation **Enabled** for every rule below.

#### Rule S-01 - Power Platform environment deleted or created outside change window

| Field           | Configuration                                                                  |
| --------------- | ------------------------------------------------------------------------------ |
| Rule name       | `<EC-SENTINEL-RULE-PP-ENV-CHANGE-OUTSIDE-WINDOW>`                            |
| Severity        | High                                                                           |
| Tactic          | Impact / Defense Evasion                                                       |
| Query frequency | 15 minutes                                                                     |
| Lookup period   | 15 minutes                                                                     |
| Entity mapping  | Account =`ActorName`; Cloud application or custom detail = `EnvironmentId` |

```kusto
let ChangeWindow = _GetWatchlist('<EC-WATCHLIST-CHANGE-WINDOWS>');
PowerPlatformAdminActivity
| where TimeGenerated > ago(15m)
| where EventOriginalType has_any ("environment", "Environment")
| where EventOriginalType has_any ("Create", "Delete", "Remove", "Update")
| extend Actor=tostring(ActorName), Env=tostring(EnvironmentId), Activity=tostring(EventOriginalType)
| extend InApprovedWindow = tobool(false)
| project TimeGenerated, Actor, Env, Activity, EventOriginalUid, InApprovedWindow
| where InApprovedWindow == false
```

::: {.evidence}
Capture `09-s01-env-change-rule.png`.
:::

#### Rule S-02 - Power Platform DLP policy modified

| Field           | Configuration                                 |
| --------------- | --------------------------------------------- |
| Rule name       | `<EC-SENTINEL-RULE-PP-DLP-POLICY-MODIFIED>` |
| Severity        | High                                          |
| Tactic          | Defense Evasion                               |
| Query frequency | 15 minutes                                    |
| Lookup period   | 15 minutes                                    |

```kusto
PowerPlatformAdminActivity
| where TimeGenerated > ago(15m)
| where EventOriginalType has_any ("Dlp", "DLP", "Policy")
| summarize Events=count(), Activities=make_set(EventOriginalType, 20) by ActorName, EnvironmentId, bin(TimeGenerated, 15m)
| where Events > 0
```

::: {.evidence}
Capture `09-s02-dlp-policy-rule.png`.
:::

#### Rule S-03 - Custom connector created, updated, or deleted

| Field           | Configuration                                  |
| --------------- | ---------------------------------------------- |
| Rule name       | `<EC-SENTINEL-RULE-CUSTOM-CONNECTOR-CHANGE>` |
| Severity        | Medium                                         |
| Tactic          | Persistence / Command and Control              |
| Query frequency | 15 minutes                                     |
| Lookup period   | 15 minutes                                     |

```kusto
PowerPlatformAdminActivity
| where TimeGenerated > ago(15m)
| where EventOriginalType has_any ("Connector", "CustomConnector", "Connection")
| where EventOriginalType has_any ("Create", "Update", "Delete", "Remove")
| project TimeGenerated, ActorName, ActorUserType, EnvironmentId, EventOriginalType, EventOriginalUid
```

::: {.evidence}
Capture `09-s03-custom-connector-rule.png`.
:::

#### Rule S-04 - Power Pages administrative or site configuration change

| Field           | Configuration                                   |
| --------------- | ----------------------------------------------- |
| Rule name       | `<EC-SENTINEL-RULE-POWERPAGES-CONFIG-CHANGE>` |
| Severity        | Medium                                          |
| Tactic          | Persistence / Initial Access                    |
| Query frequency | 15 minutes                                      |
| Lookup period   | 15 minutes                                      |

```kusto
PowerPlatformAdminActivity
| where TimeGenerated > ago(15m)
| where EventOriginalType has_any ("Power Pages", "PowerPages", "Portal", "Website")
| where EventOriginalType has_any ("Create", "Update", "Delete", "Set", "Change")
| project TimeGenerated, ActorName, EnvironmentId, EventOriginalType, EventOriginalUid
```

::: {.evidence}
Capture `09-s04-power-pages-config-rule.png`.
:::

#### Rule S-05 - Dataverse high-volume delete or destructive activity

| Field           | Configuration                                |
| --------------- | -------------------------------------------- |
| Rule name       | `<EC-SENTINEL-RULE-DATAVERSE-MASS-DELETE>` |
| Severity        | High                                         |
| Tactic          | Impact                                       |
| Query frequency | 15 minutes                                   |
| Lookup period   | 15 minutes                                   |

```kusto
DataverseActivity
| where TimeGenerated > ago(15m)
| where Operation in~ ("Delete", "DeleteMultiple") or Message has "Delete"
| summarize DeleteCount=count() by SystemUserId, ClientIp, EntityName, bin(TimeGenerated, 15m)
| where DeleteCount >= <EC-DATAVERSE-DELETE-THRESHOLD>
```

::: {.evidence}
Capture `09-s05-dataverse-mass-delete-rule.png`.
:::

#### Rule S-06 - Entra External ID risky sign-in to Power Pages

| Field           | Configuration                                        |
| --------------- | ---------------------------------------------------- |
| Rule name       | `<EC-SENTINEL-RULE-EXTID-RISKY-SIGNIN-POWERPAGES>` |
| Severity        | High                                                 |
| Tactic          | Initial Access / Credential Access                   |
| Query frequency | 15 minutes                                           |
| Lookup period   | 15 minutes                                           |

```kusto
SigninLogs
| where TimeGenerated > ago(15m)
| where AppId == "<EC-EXTERNALID-APP-ID>" or AppDisplayName has "<EC-POWERPAGES-APP-DISPLAY-NAME>"
| where IsRisky == true or RiskLevelDuringSignIn in ("medium", "high") or RiskLevelAggregated in ("medium", "high")
| project TimeGenerated, UserPrincipalName, IPAddress, Location, AppDisplayName, ResultType, RiskLevelDuringSignIn, RiskLevelAggregated, RiskState
```

::: {.evidence}
Capture `09-s06-external-id-risky-signin-rule.png`.
:::

#### Rule S-07 - Application credential or secret added to Power Pages identity application

| Field           | Configuration                                          |
| --------------- | ------------------------------------------------------ |
| Rule name       | `<EC-SENTINEL-RULE-APP-CREDENTIAL-ADDED-POWERPAGES>` |
| Severity        | High                                                   |
| Tactic          | Persistence / Credential Access                        |
| Query frequency | 15 minutes                                             |
| Lookup period   | 15 minutes                                             |

```kusto
AuditLogs
| where TimeGenerated > ago(15m)
| where OperationName has_any ("Add service principal credentials", "Add application credentials", "Update application")
| where tostring(TargetResources) has "<EC-EXTERNALID-APP-ID>" or tostring(TargetResources) has "<EC-POWERPAGES-APP-DISPLAY-NAME>"
| project TimeGenerated, OperationName, InitiatedBy, TargetResources, Result
```

::: {.evidence}
Capture `09-s07-app-credential-added-rule.png`.
:::

### Configure automation and notification routing

::: {.step}

**Portal procedure**

- Open Microsoft Sentinel workspace `<EC-LAW-NAME>`.
- Select **Automation**.
- Select **Create** > **Automation rule**.
- Name the rule `<EC-SENTINEL-AUTO-ROUTE-PP-SECURITY-INCIDENTS>`.
- Set trigger to **When incident is created**.
- Add condition for analytics rule name starts with `<EC-SENTINEL-RULE-` or solution equals Microsoft Business Applications.
- Set action to assign owner `<EC-SOC-QUEUE-OR-OWNER>` or apply tag `PowerPlatform`.
- Add action to run playbook `<EC-SENTINEL-PLAYBOOK-NOTIFY-SOC>` if approved.
- Select **Apply**.

:::

::: {.evidence}
Capture `10-sentinel-automation-routing-rule.png`.
:::

### Create the Sentinel workbook view

::: {.step}

**Portal procedure**

- Open Microsoft Sentinel workspace `<EC-LAW-NAME>`.
- Select **Workbooks**.
- Open the workbook installed by Microsoft Business Applications if available.
- Save a copy as `<EC-SENTINEL-WORKBOOK-PP-SECURITY>`.
- Add or validate tiles for:
  - Power Platform admin activity by operation.
  - Dataverse destructive operations.
  - Power Pages configuration changes.
  - External ID sign-ins and failures for `<EC-EXTERNALID-APP-ID>`.
  - Incidents by severity and rule.
- Save the workbook.

:::

::: {.evidence}
Capture `11-sentinel-workbook-security-view.png`.
:::

## Support runbooks for Sentinel incidents

| Incident / rule                                        | First response                                          | Initial triage                                                                              | Escalation owner                                                                    | Closure criteria                                                                                       | Tuning notes                                                                    |
| ------------------------------------------------------ | ------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| `<EC-SENTINEL-RULE-PP-ENV-CHANGE-OUTSIDE-WINDOW>`    | SOC acknowledges incident and checks RFC/change window. | Validate actor, environment ID, operation, and whether approved change exists.              | SOC to Power Platform Administrator; escalate to incident response if unauthorized. | Change is matched to approved RFC or unauthorized action is contained and incident record is complete. | Maintain current change-window watchlist.                                       |
| `<EC-SENTINEL-RULE-PP-DLP-POLICY-MODIFIED>`          | SOC acknowledges as high priority.                      | Identify policy name, actor, before/after state if available, and affected environment.     | SOC to Power Platform governance owner.                                             | DLP change is approved or reverted; impact documented.                                                 | Exclude approved automation/service principals only through watchlist approval. |
| `<EC-SENTINEL-RULE-CUSTOM-CONNECTOR-CHANGE>`         | SOC validates connector change.                         | Review connector endpoint, authentication type, creator, and environment.                   | SOC to Power Platform Administrator and API/security owner.                         | Connector is approved or disabled/removed.                                                             | Tune by approved connector owners and approved environments.                    |
| `<EC-SENTINEL-RULE-POWERPAGES-CONFIG-CHANGE>`        | SOC checks whether change affects external-facing site. | Review site, actor, configuration field, auth settings, and recent deployments.             | SOC to Power Pages owner and Identity team.                                         | Change is approved or rolled back; external exposure assessed.                                         | Separate production and non-production thresholds.                              |
| `<EC-SENTINEL-RULE-DATAVERSE-MASS-DELETE>`           | SOC treats as potential destructive activity.           | Validate user, IP, entity, delete count, and whether bulk operation was approved.           | SOC to Dataverse owner; escalate to IR for unauthorized destructive action.         | Activity is approved or contained and data recovery decision documented.                               | Set thresholds by table criticality.                                            |
| `<EC-SENTINEL-RULE-EXTID-RISKY-SIGNIN-POWERPAGES>`   | SOC checks user, IP, location, and risk details.        | Validate whether account is compromised, MFA/CA result, repeated failures, and geolocation. | SOC to Identity team.                                                               | Risk is remediated/dismissed with documented justification.                                            | Requires P2 risk fields for full fidelity; tune if hidden risk values dominate. |
| `<EC-SENTINEL-RULE-APP-CREDENTIAL-ADDED-POWERPAGES>` | SOC treats as high priority persistence signal.         | Identify credential type, app, actor, and approval record.                                  | SOC to Identity/application owner.                                                  | Credential is approved and documented or removed; app secrets rotated if required.                     | Maintain app allowlist and approved secret rotation windows.                    |

## Final validation checklist

- Microsoft Sentinel is enabled on `<EC-LAW-NAME>`.
- Microsoft Business Applications solution is installed.
- Power Platform Admin Activity, Dataverse, and Power Automate connectors are connected where available.
- Microsoft Entra ID connector is connected and returns records for `<EC-EXTERNALID-APP-ID>`.
- Watchlists `<EC-WATCHLIST-APPROVED-ADMINS>`, `<EC-WATCHLIST-APPROVED-COUNTRIES>`, and `<EC-WATCHLIST-CHANGE-WINDOWS>` exist.
- Built-in Microsoft Business Applications analytics rules are enabled.
- Custom rules S-01 through S-07 are created and enabled.
- Automation rule `<EC-SENTINEL-AUTO-ROUTE-PP-SECURITY-INCIDENTS>` is enabled.
- Workbook `<EC-SENTINEL-WORKBOOK-PP-SECURITY>` is saved.
- Screenshots and query exports are saved to `<EC-EVIDENCE-FOLDER>`.

```powershell
Stop-Transcript
```

## Official references

- Microsoft Learn - Connect Microsoft Power Platform and Dynamics 365 Customer Engagement to Microsoft Sentinel: https://learn.microsoft.com/en-us/azure/sentinel/business-applications/deploy-power-platform-solution
- Microsoft Learn - Microsoft Sentinel solution for Microsoft Business Apps: https://learn.microsoft.com/en-us/azure/sentinel/business-applications/solution-overview
- Microsoft Learn - Security content reference for Power Platform solution: https://learn.microsoft.com/en-us/azure/sentinel/business-applications/power-platform-solution-security-content
- Microsoft Learn - Send Microsoft Entra ID data to Microsoft Sentinel: https://learn.microsoft.com/en-us/azure/sentinel/connect-azure-active-directory
- Microsoft Learn - Configure Microsoft Entra diagnostic settings: https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-configure-diagnostic-settings
- Microsoft Learn - Set up Azure Monitor in external tenants: https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-azure-monitor
- Microsoft Learn - Power Platform activity logs and auditing in Microsoft Purview: https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-overview
- Microsoft Learn - PowerPlatformAdminActivity table: https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/powerplatformadminactivity
- Microsoft Learn - DataverseActivity table: https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/dataverseactivity
