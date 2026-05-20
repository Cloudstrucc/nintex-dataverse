# Power Platform Azure Monitor Operational Monitoring Build Book

**Audience:** IT Operations / Azure Administrators / Power Platform Administrators
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
  - [6.2 Resource and licensing
    prerequisites](#resource-and-licensing-prerequisites)
- [7 Build steps](#build-steps)
  - [Create
    the monitoring resource group](#create-the-monitoring-resource-group)
  - [Create the
    Log Analytics workspace](#create-the-log-analytics-workspace)
  - [Assign least-privilege access to the workspace](#assign-least-privilege-access-to-the-workspace)
  - [Create workspace-based Application Insights](#create-workspace-based-application-insights)
  - [Configure Power Platform export to Application Insights](#configure-power-platform-export-to-application-insights)
  - [Validate initial Power Platform telemetry in Application
    Insights](#validate-initial-power-platform-telemetry-in-application-insights)
  - [Create Power Pages availability monitoring](#create-power-pages-availability-monitoring)
  - [Configure Entra External ID diagnostic settings to Log
    Analytics](#configure-entra-external-id-diagnostic-settings-to-log-analytics)
  - [Create the IT Operations action group](#create-the-it-operations-action-group)
  - [Create Azure Monitor operational alerts](#create-azure-monitor-operational-alerts)
  - [Create
    the Azure Monitor workbook](#create-the-azure-monitor-workbook)
- [8 Support runbooks for
  Azure Monitor alerts](#support-runbooks-for-azure-monitor-alerts)
- [9 Final validation checklist](#final-validation-checklist)
- [10 Official references](#official-references)

## Document control

| Field                       | Value                                                                                                                                                                                                  |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Organization                | Elections Canada                                                                                                                                                                                       |
| Author                      | Frederick Pearson, Platform Engineering                                                                                                                                                                |
| Primary implementation team | IT Operations / Azure administrators / Power Platform administrators                                                                                                                                   |
| Implementer role            | Global Administrator or delegated administrator with the specified Azure, Power Platform, Entra, Sentinel, or QRadar permissions                                                                       |
| Environment scope           | Production Power Platform environments, production Dataverse environments, external-facing Power Pages sites, and Entra External ID tenants or applications used for external registration and sign-in |
| Evidence requirement        | Every implementation step that changes configuration must be captured with a screenshot and saved to the evidence folder named in this build book                                                      |

## Implementation objective

Elections Canada will implement Azure Monitor as the operational monitoring layer for Power Platform, Power Pages, Power Automate, Dataverse, and Entra External ID sign-in/registration flows. The implementation will create Log Analytics, Application Insights, Power Platform telemetry export, External ID diagnostic log routing, IT Operations action groups, operational alert rules, and evidence-ready support runbooks.

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

| Requirement          | Required value                                                                                                                                                   |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Microsoft Entra role | Global Administrator, Security Administrator, or delegated roles that can configure diagnostic settings for Entra logs                                           |
| Azure RBAC           | Owner or Contributor on `<EC-SUBSCRIPTION-ID>` and Monitoring Contributor / Log Analytics Contributor for monitoring resources                                 |
| Power Platform role  | Power Platform Administrator or Dynamics 365 Administrator at tenant level, plus Environment Administrator or System Administrator in each Dataverse environment |
| Power Pages access   | Access to the production Power Pages URL and an approved synthetic monitoring account or anonymous health-check URL                                              |
| Evidence access      | Write access to `<EC-EVIDENCE-FOLDER>`                                                                                                                         |

### Resource and licensing prerequisites

- An Azure subscription `<EC-SUBSCRIPTION-ID>` is required to host Log Analytics, Application Insights, action groups, alert rules, and optional Event Hubs resources.
- A production Power Platform managed environment is required for Power Platform telemetry export to Application Insights.
- An Application Insights resource is required for Power Platform telemetry export.
- A unique Application Insights resource is required for each monitored production environment or tenant-level export package so out-of-box reports remain accurate.
- Power Platform telemetry export can take up to 24 hours before data appears in Application Insights.
- Entra External ID monitoring requires a destination Log Analytics workspace in the workforce tenant when the external tenant is separate.

## Build steps

### Create the monitoring resource group

::: {.step}

**Portal procedure**

- Sign in to the Azure portal.
- Search for **Resource groups**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Enter resource group name `<EC-RG-MONITORING>`.
- Select region `<EC-LOCATION>`.
- Select **Review + create**.
- Select **Create**.
- Open the new resource group and confirm the **Overview** page displays the correct subscription, location, and resource group name.

**Optional Azure PowerShell**

```powershell
New-AzResourceGroup `
  -Name "<EC-RG-MONITORING>" `
  -Location "<EC-LOCATION>" `
  -Tag @{Workload="PowerPlatformMonitoring"; Environment="Prod"; Owner="IT Operations"; Organization="Elections Canada"}
```

:::

::: {.evidence}
Capture `02-resource-group-overview.png` showing `<EC-RG-MONITORING>`, subscription, location, and tags.
:::

### Create the Log Analytics workspace

::: {.step}

**Portal procedure**

- In the Azure portal, search for **Log Analytics workspaces**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Select resource group `<EC-RG-MONITORING>`.
- Enter workspace name `<EC-LAW-NAME>`.
- Select region `<EC-LOCATION>`.
- Select **Review + create**.
- Select **Create**.
- After deployment, open `<EC-LAW-NAME>` and select **Overview**.
- Select **Usage and estimated costs**.
- Select **Data retention**.
- Set retention to the approved Elections Canada operational retention value, represented here as `<EC-LAW-RETENTION-DAYS>`.
- Select **OK** or **Save**.

**Optional Azure PowerShell**

```powershell
New-AzOperationalInsightsWorkspace `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -Name "<EC-LAW-NAME>" `
  -Location "<EC-LOCATION>" `
  -Sku "PerGB2018" `
  -RetentionInDays <EC-LAW-RETENTION-DAYS>
```

:::

::: {.evidence}
Capture `03-log-analytics-overview.png` and `03-log-analytics-retention.png`.
:::

### Assign least-privilege access to the workspace

::: {.step}

**Portal procedure**

- Open `<EC-LAW-NAME>`.
- Select **Access control (IAM)**.
- Select **Add** > **Add role assignment**.
- Assign **Log Analytics Reader** to the approved IT Operations support group `<EC-GRP-ITOPS-MONITORING-READERS>`.
- Assign **Monitoring Contributor** to the approved IT Operations monitoring administration group `<EC-GRP-ITOPS-MONITORING-ADMINS>`.
- Assign **Reader** to the approved Power Platform support group `<EC-GRP-PP-SUPPORT-READERS>`.
- Select **Review + assign**.

**Optional Azure PowerShell**

```powershell
$Workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "<EC-RG-MONITORING>" -Name "<EC-LAW-NAME>"
New-AzRoleAssignment -ObjectId "<EC-GRP-ITOPS-MONITORING-READERS-OBJECTID>" -RoleDefinitionName "Log Analytics Reader" -Scope $Workspace.ResourceId
New-AzRoleAssignment -ObjectId "<EC-GRP-ITOPS-MONITORING-ADMINS-OBJECTID>" -RoleDefinitionName "Monitoring Contributor" -Scope $Workspace.ResourceId
New-AzRoleAssignment -ObjectId "<EC-GRP-PP-SUPPORT-READERS-OBJECTID>" -RoleDefinitionName "Reader" -Scope $Workspace.ResourceId
```

:::

::: {.evidence}
Capture `04-workspace-iam-role-assignments.png` showing the assigned groups and roles.
:::

### Create workspace-based Application Insights

::: {.step}

**Portal procedure**

- In the Azure portal, search for **Application Insights**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Select resource group `<EC-RG-MONITORING>`.
- Enter name `<EC-APPINSIGHTS-NAME>`.
- Select region `<EC-LOCATION>`.
- For **Resource Mode**, select **Workspace-based**.
- Select Log Analytics workspace `<EC-LAW-NAME>`.
- Select **Review + create**.
- Select **Create**.
- Open the Application Insights resource and confirm it is linked to `<EC-LAW-NAME>`.

**Optional Azure PowerShell**

```powershell
$Workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "<EC-RG-MONITORING>" -Name "<EC-LAW-NAME>"
New-AzApplicationInsights `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -Name "<EC-APPINSIGHTS-NAME>" `
  -Location "<EC-LOCATION>" `
  -WorkspaceResourceId $Workspace.ResourceId `
  -ApplicationType "web"
```

:::

::: {.evidence}
Capture `05-application-insights-overview.png` showing `<EC-APPINSIGHTS-NAME>` and the workspace link.
:::

### Configure Power Platform export to Application Insights

::: {.step}

**Portal procedure**

- Sign in to the Power Platform admin center.
- Select **Manage** in the left navigation.
- Select **Data export**.
- Select the **App Insights** tab.
- Select **New data export**.
- Enter export package name `<EC-PP-APPINSIGHTS-EXPORT-NAME>`.
- Select the data types required for the environment:
  - **Dataverse diagnostics and performance**.
  - **Power Automate** for cloud flow runs, triggers, and actions when available for the tenant and environment.
- Select filters for environment `<EC-ENVIRONMENT-NAME>` / `<EC-ENVIRONMENT-ID>`.
- Select Azure subscription `<EC-SUBSCRIPTION-ID>`.
- Select Application Insights resource `<EC-APPINSIGHTS-NAME>`.
- Review the configuration.
- Select **Create**.
- Return to **Data export** > **App Insights** and verify the export package status.

**Optional automation note**

- This step is performed in the Power Platform admin center because the data export package is a Power Platform administrative configuration. Keep the Azure PowerShell transcript open, but capture this as portal evidence.

:::

::: {.evidence}
Capture `06-power-platform-data-export-created.png` showing export name, data types, environment, and Application Insights target.
:::

### Validate initial Power Platform telemetry in Application Insights

::: {.step}

**Portal procedure**

- Open Application Insights resource `<EC-APPINSIGHTS-NAME>`.
- Select **Logs**.
- Set time range to **Last 24 hours** after telemetry has had time to arrive.
- Run the following validation queries.
- Export each result set to CSV and save it to `<EC-EVIDENCE-FOLDER>/validation-results/`.

**Validation queries**

```kusto
requests
| where timestamp > ago(24h)
| summarize RequestCount=count(), FailedRequests=countif(success == false) by operation_Name
| order by FailedRequests desc
```

```kusto
dependencies
| where timestamp > ago(24h)
| summarize DependencyCount=count(), FailedDependencies=countif(success == false) by target, type
| order by FailedDependencies desc
```

```kusto
exceptions
| where timestamp > ago(24h)
| summarize ExceptionCount=count() by type, outerMessage
| order by ExceptionCount desc
```

:::

::: {.evidence}
Capture `07-appinsights-logs-validation.png` showing query results from requests, dependencies, and exceptions.
:::

### Create Power Pages availability monitoring

::: {.step}

**Portal procedure**

- Open Application Insights resource `<EC-APPINSIGHTS-NAME>`.
- Select **Availability**.
- Select **Add Classic test** or **Add Standard test**, depending on the tenant UI.
- Enter test name `<EC-PPAGES-AVAILABILITY-TEST-NAME>`.
- Set URL to `<EC-POWERPAGES-URL>` or approved health-check URL `<EC-POWERPAGES-HEALTHCHECK-URL>`.
- Set test frequency to **5 minutes**.
- Select at least three test locations approved by Elections Canada for external availability checks.
- Enable retry logic if offered by the portal.
- Set success criteria to HTTP 200 or the approved success condition for the page.
- Select **Create**.
- Open the created test and verify that the first test run begins.

**Optional Azure PowerShell**

```powershell
# Availability web tests can be deployed as Azure resources. Use this pattern when the Az.ApplicationInsights module in the admin environment supports web-test deployment.
# Replace the properties with approved values and validate in non-production first.
$AppInsights = Get-AzApplicationInsights -ResourceGroupName "<EC-RG-MONITORING>" -Name "<EC-APPINSIGHTS-NAME>"
# If New-AzApplicationInsightsWebTest is not available in the installed module, deploy the equivalent Microsoft.Insights/webtests ARM/Bicep template with New-AzResourceGroupDeployment.
```

:::

::: {.evidence}
Capture `08-power-pages-availability-test.png` showing the test URL, frequency, locations, and current status.
:::

### Configure Entra External ID diagnostic settings to Log Analytics

::: {.step}

**Portal procedure**

- Sign in to the Microsoft Entra admin center with the tenant context required for Entra External ID monitoring.
- Browse to **Entra ID** > **Monitoring & health** > **Diagnostic settings**.
- Select **Add diagnostic setting**.
- Enter diagnostic setting name `<EC-DIAG-EXTID-LAW-NAME>`.
- Select the required log categories:
  - **AuditLogs**.
  - **SignInLogs**.
  - **NonInteractiveUserSignInLogs** when available.
  - **ServicePrincipalSignInLogs** when available.
  - **ManagedIdentitySignInLogs** when available.
  - **ProvisioningLogs** when registration, provisioning, or lifecycle investigation is required.
- Select **Send to Log Analytics workspace**.
- Select subscription `<EC-SUBSCRIPTION-ID>`.
- Select workspace `<EC-LAW-NAME>`.
- Select **Save**.

**Optional Azure PowerShell**

```powershell
# The Microsoft Entra tenant diagnostic setting is a tenant-level diagnostic setting. Use the Azure Monitor diagnostic settings cmdlets when the tenant supports the scope.
$TenantScope = "/providers/Microsoft.aadiam/diagnosticSettings/<EC-DIAG-EXTID-LAW-NAME>"
# Portal configuration is the required method when the current Az module does not expose the tenant diagnostic setting scope in the admin environment.
```

:::

::: {.evidence}
Capture `09-entra-external-id-diagnostic-setting.png` showing selected log categories and destination `<EC-LAW-NAME>`.
:::

### Create the IT Operations action group

::: {.step}

**Portal procedure**

- In the Azure portal, search for **Monitor**.
- Select **Alerts**.
- Select **Action groups**.
- Select **Create**.
- Select subscription `<EC-SUBSCRIPTION-ID>` and resource group `<EC-RG-MONITORING>`.
- Enter action group name `<EC-ACTIONGROUP-ITOPS-NAME>`.
- Enter display name `<EC-ACTIONGROUP-ITOPS-SHORTNAME>`.
- On **Notifications**, add the approved notification channels:
  - Email/SMS/Push/Voice: `<EC-ITOPS-DISTRIBUTION-LIST>`.
  - Email/SMS/Push/Voice: `<EC-POWERPLATFORM-SUPPORT-DL>`.
- On **Actions**, add ITSM webhook, Logic App, or secure automation endpoint `<EC-ITSM-WEBHOOK-URI>` if approved.
- Select **Review + create**.
- Select **Create**.
- Use **Test action group** and verify receipt.

**Optional Azure PowerShell**

```powershell
$EmailReceiver = New-AzActionGroupEmailReceiverObject -Name "ITOpsEmail" -EmailAddress "<EC-ITOPS-DISTRIBUTION-LIST>"
New-AzActionGroup `
  -ResourceGroupName "<EC-RG-MONITORING>" `
  -Name "<EC-ACTIONGROUP-ITOPS-NAME>" `
  -ShortName "<EC-ACTIONGROUP-ITOPS-SHORTNAME>" `
  -Receiver $EmailReceiver
```

:::

::: {.evidence}
Capture `10-action-group-created.png` and `10-action-group-test-notification.png`.
:::

### Create Azure Monitor operational alerts

Create the following alert rules. Each alert uses action group `<EC-ACTIONGROUP-ITOPS-NAME>` and stores the alert in resource group `<EC-RG-MONITORING>` unless the RFC specifies otherwise.

#### Alert AM-01 - Power Pages availability failure

| Field                | Configuration                                                        |
| -------------------- | -------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-PPAGES-AVAILABILITY-CRITICAL>`                          |
| Severity             | 1 - Critical                                                         |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`              |
| Signal               | Availability test failure or log search over `availabilityResults` |
| Evaluation frequency | 5 minutes                                                            |
| Lookback window      | 10 minutes                                                           |
| Trigger              | Failed availability result count greater than or equal to 2          |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                      |

**Portal procedure**

- Open **Monitor** > **Alerts**.
- Select **Create** > **Alert rule**.
- Select scope `<EC-APPINSIGHTS-NAME>`.
- Select condition **Availability** / **Failed locations** if using the availability signal, or select **Custom log search** if using the KQL below.
- Enter the threshold above.
- Select action group `<EC-ACTIONGROUP-ITOPS-NAME>`.
- Enter alert name `<EC-ALERT-PPAGES-AVAILABILITY-CRITICAL>`.
- Set severity **1**.
- Select **Review + create** and **Create**.

```kusto
availabilityResults
| where timestamp > ago(10m)
| where name == "<EC-PPAGES-AVAILABILITY-TEST-NAME>"
| where success == false
| summarize FailedCount=count()
```

**Optional Azure PowerShell**

```powershell
# Use New-AzScheduledQueryRule for the custom log search variant after validating the query in Application Insights Logs.
# Store the query in a .kql file and deploy with approved scheduled-query-rule cmdlets or ARM/Bicep template.
```

::: {.evidence}
Capture `11-am01-ppages-availability-alert.png` showing scope, condition, severity, and action group.
:::

#### Alert AM-02 - Power Pages response time degradation

| Field                | Configuration                                                 |
| -------------------- | ------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-PPAGES-P95-LATENCY-WARNING>`                     |
| Severity             | 2 - Warning                                                   |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`       |
| Evaluation frequency | 5 minutes                                                     |
| Lookback window      | 15 minutes                                                    |
| Trigger              | p95 duration greater than `<EC-PPAGES-P95-MS>` milliseconds |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                               |

```kusto
requests
| where timestamp > ago(15m)
| where url startswith "<EC-POWERPAGES-URL>"
| summarize P95DurationMs=percentile(duration, 95)
| where P95DurationMs > <EC-PPAGES-P95-MS>
```

::: {.evidence}
Capture `11-am02-ppages-latency-alert.png`.
:::

#### Alert AM-03 - Power Automate cloud flow run failures

| Field                | Configuration                                                                 |
| -------------------- | ----------------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-FLOW-RUN-FAILURES-ERROR>`                                        |
| Severity             | 2 - Error                                                                     |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`                       |
| Evaluation frequency | 5 minutes                                                                     |
| Lookback window      | 15 minutes                                                                    |
| Trigger              | Failed request count greater than or equal to `<EC-FLOW-FAILURE-THRESHOLD>` |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                               |

```kusto
requests
| where timestamp > ago(15m)
| where success == false
| summarize FailedRuns=count() by operation_Name
| where FailedRuns >= <EC-FLOW-FAILURE-THRESHOLD>
```

::: {.evidence}
Capture `11-am03-flow-run-failure-alert.png`.
:::

#### Alert AM-04 - Power Automate action or trigger dependency failures

| Field                | Configuration                                                                          |
| -------------------- | -------------------------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-FLOW-DEPENDENCY-FAILURES-ERROR>`                                          |
| Severity             | 2 - Error                                                                              |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`                                |
| Evaluation frequency | 5 minutes                                                                              |
| Lookback window      | 15 minutes                                                                             |
| Trigger              | Failed dependency count greater than or equal to `<EC-DEPENDENCY-FAILURE-THRESHOLD>` |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                                        |

```kusto
dependencies
| where timestamp > ago(15m)
| where success == false
| summarize FailedDependencies=count() by target, type, operation_Name
| where FailedDependencies >= <EC-DEPENDENCY-FAILURE-THRESHOLD>
```

::: {.evidence}
Capture `11-am04-flow-dependency-failure-alert.png`.
:::

#### Alert AM-05 - Dataverse exception spike

| Field                | Configuration                                                                   |
| -------------------- | ------------------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-DATAVERSE-EXCEPTION-SPIKE-ERROR>`                                  |
| Severity             | 2 - Error                                                                       |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`                         |
| Evaluation frequency | 5 minutes                                                                       |
| Lookback window      | 15 minutes                                                                      |
| Trigger              | Exception count greater than or equal to `<EC-DATAVERSE-EXCEPTION-THRESHOLD>` |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                                 |

```kusto
exceptions
| where timestamp > ago(15m)
| summarize ExceptionCount=count() by type, outerMessage
| where ExceptionCount >= <EC-DATAVERSE-EXCEPTION-THRESHOLD>
```

::: {.evidence}
Capture `11-am05-dataverse-exception-alert.png`.
:::

#### Alert AM-06 - Connector or API dependency failure spike

| Field                | Configuration                                                                                  |
| -------------------- | ---------------------------------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-CONNECTOR-API-FAILURES-ERROR>`                                                    |
| Severity             | 2 - Error                                                                                      |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`                                        |
| Evaluation frequency | 5 minutes                                                                                      |
| Lookback window      | 15 minutes                                                                                     |
| Trigger              | Failed dependencies for a target greater than or equal to `<EC-CONNECTOR-FAILURE-THRESHOLD>` |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                                                |

```kusto
dependencies
| where timestamp > ago(15m)
| where success == false
| summarize FailedCalls=count() by target
| where FailedCalls >= <EC-CONNECTOR-FAILURE-THRESHOLD>
```

::: {.evidence}
Capture `11-am06-connector-api-failure-alert.png`.
:::

#### Alert AM-07 - Entra External ID sign-in failure spike for Power Pages

| Field                | Configuration                                                                                            |
| -------------------- | -------------------------------------------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-EXTID-SIGNIN-FAILURE-SPIKE-ERROR>`                                                          |
| Severity             | 2 - Error                                                                                                |
| Scope                | Log Analytics workspace `<EC-LAW-NAME>`                                                                |
| Evaluation frequency | 5 minutes                                                                                                |
| Lookback window      | 15 minutes                                                                                               |
| Trigger              | Failed sign-ins for `<EC-EXTERNALID-APP-ID>` greater than or equal to `<EC-EXTID-FAILURE-THRESHOLD>` |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                                                          |

```kusto
SigninLogs
| where TimeGenerated > ago(15m)
| where AppId == "<EC-EXTERNALID-APP-ID>" or AppDisplayName has "<EC-POWERPAGES-APP-DISPLAY-NAME>"
| where ResultType != 0
| summarize FailedSignIns=count() by AppDisplayName, ResultType, ResultDescription
| where FailedSignIns >= <EC-EXTID-FAILURE-THRESHOLD>
```

::: {.evidence}
Capture `11-am07-entra-external-id-failure-alert.png`.
:::

#### Alert AM-08 - Monitoring pipeline silence

| Field                | Configuration                                                         |
| -------------------- | --------------------------------------------------------------------- |
| Alert name           | `<EC-ALERT-PP-TELEMETRY-SILENCE-WARNING>`                           |
| Severity             | 3 - Warning                                                           |
| Scope                | Application Insights resource `<EC-APPINSIGHTS-NAME>`               |
| Evaluation frequency | 30 minutes                                                            |
| Lookback window      | 24 hours                                                              |
| Trigger              | No requests or dependencies for the monitored environment in 24 hours |
| Action group         | `<EC-ACTIONGROUP-ITOPS-NAME>`                                       |

```kusto
union requests, dependencies
| where timestamp > ago(24h)
| summarize TelemetryCount=count()
| where TelemetryCount == 0
```

::: {.evidence}
Capture `11-am08-telemetry-silence-alert.png`.
:::

### Create the Azure Monitor workbook

::: {.step}

**Portal procedure**

- Open **Azure Monitor**.
- Select **Workbooks**.
- Select **New**.
- Name the workbook `<EC-WORKBOOK-ITOPS-PP-MONITORING>`.
- Add a text section named **Scope** listing `<EC-ENVIRONMENT-NAME>`, `<EC-POWERPAGES-URL>`, and `<EC-EXTERNALID-APP-ID>`.
- Add query tiles for:
  - Power Pages availability failures.
  - Power Pages p95 duration.
  - Power Automate failed runs.
  - Flow action and trigger dependency failures.
  - Dataverse exceptions.
  - Connector/API failures.
  - Entra External ID sign-in failure spike.
- Select **Save**.
- Save the workbook in resource group `<EC-RG-MONITORING>`.

:::

::: {.evidence}
Capture `12-azure-monitor-workbook-overview.png` and `12-workbook-save-confirmation.png`.
:::

## Support runbooks for Azure Monitor alerts

| Alert                                           | First response                                                            | Initial triage                                                                                                                                                                                         | Escalation owner                                                                                                                         | Closure criteria                                                                                                                 | Tuning notes                                                                                                                     |
| ----------------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `<EC-ALERT-PPAGES-AVAILABILITY-CRITICAL>`     | Acknowledge alert in Azure Monitor and create/update the IT Ops incident. | Open Availability test results, confirm failed locations, test `<EC-POWERPAGES-URL>` from approved admin network, check Power Pages admin center health, check DNS/custom domain/certificate status. | IT Operations web/platform support; escalate to Power Platform administrator if site is reachable but authentication/app behavior fails. | Availability test passes from approved locations for two consecutive evaluation periods and user-impact statement is documented. | Suppress known maintenance windows using alert processing rules; tune if only one external location fails.                       |
| `<EC-ALERT-PPAGES-P95-LATENCY-WARNING>`       | Acknowledge and review workbook latency tile.                             | Compare p95 duration against baseline, inspect slow requests, review Dataverse/API dependency failures, validate external ID sign-in latency if login pages are affected.                              | IT Operations; escalate to Power Platform app owner for app-specific latency.                                                            | p95 returns below `<EC-PPAGES-P95-MS>` for two consecutive periods.                                                            | Use separate thresholds for anonymous public pages and authenticated pages if needed.                                            |
| `<EC-ALERT-FLOW-RUN-FAILURES-ERROR>`          | Acknowledge and identify affected flow from `operation_Name`.           | Open Power Automate run history, identify failed action, validate connector status and dependent service availability.                                                                                 | Power Platform support team; escalate to system owner for business process impact.                                                       | Flow succeeds or failed runs are explained by approved change/known outage.                                                      | Tune threshold per critical flow; create critical-flow-specific alerts for election-critical automations.                        |
| `<EC-ALERT-FLOW-DEPENDENCY-FAILURES-ERROR>`   | Acknowledge and identify failed dependency target.                        | Review dependency target, connector, API status, authentication errors, and retry behavior.                                                                                                            | IT Operations integration/API owner.                                                                                                     | Dependency calls return to normal and retries succeed.                                                                           | Exclude known transient targets only with documented approval.                                                                   |
| `<EC-ALERT-DATAVERSE-EXCEPTION-SPIKE-ERROR>`  | Acknowledge and review exception type and message.                        | Correlate exceptions with recent solution import, plugin changes, API deployment, or data operations.                                                                                                  | Power Platform administrator and Dataverse solution owner.                                                                               | Exception count returns below threshold and root cause is logged.                                                                | Tune by exception type if a noisy benign exception is identified.                                                                |
| `<EC-ALERT-CONNECTOR-API-FAILURES-ERROR>`     | Acknowledge and identify connector/API target.                            | Validate connector connection references, secret expiry, API availability, throttling, and network dependencies.                                                                                       | Integration/API owner.                                                                                                                   | Connector/API calls are succeeding and affected flows/apps recover.                                                              | Maintain approved target allowlist for expected failure-prone noncritical endpoints.                                             |
| `<EC-ALERT-EXTID-SIGNIN-FAILURE-SPIKE-ERROR>` | Acknowledge and check if Power Pages sign-in or registration is affected. | Review SigninLogs result codes, affected app, IP/country patterns, conditional access result, and identity provider status.                                                                            | Identity team; escalate to IT Security if suspicious patterns appear.                                                                    | Sign-in failure rate returns to baseline and any configuration issue is remediated.                                              | Separate brute-force/security rules must remain in SIEM; this Azure Monitor alert is for operational sign-in failure visibility. |
| `<EC-ALERT-PP-TELEMETRY-SILENCE-WARNING>`     | Acknowledge and verify that telemetry export still exists.                | Check Power Platform data export status, Application Insights ingestion, workspace ingestion, and recent platform activity.                                                                            | IT Operations; escalate to Power Platform administrator.                                                                                 | Telemetry resumes or a documented no-activity explanation is attached.                                                           | Tune during extended shutdown periods or approved non-use windows.                                                               |

## Final validation checklist

- `<EC-RG-MONITORING>` exists in `<EC-SUBSCRIPTION-ID>`.
- `<EC-LAW-NAME>` exists, has approved retention, and has correct RBAC.
- `<EC-APPINSIGHTS-NAME>` exists and is workspace-based.
- Power Platform data export package `<EC-PP-APPINSIGHTS-EXPORT-NAME>` is active.
- Application Insights validation queries return records or a documented 24-hour wait has been recorded.
- Entra External ID diagnostic setting `<EC-DIAG-EXTID-LAW-NAME>` sends logs to `<EC-LAW-NAME>`.
- Action group `<EC-ACTIONGROUP-ITOPS-NAME>` sends a test notification to the approved recipients.
- All AM-01 through AM-08 alert rules exist and use `<EC-ACTIONGROUP-ITOPS-NAME>`.
- Workbook `<EC-WORKBOOK-ITOPS-PP-MONITORING>` is saved and visible to IT Operations.
- Screenshots are saved for every evidence checkpoint.
- PowerShell transcript is stopped and saved.

```powershell
Stop-Transcript
```

## Official references

- Microsoft Learn - Export data to Application Insights: https://learn.microsoft.com/en-us/power-platform/admin/set-up-export-application-insights
- Microsoft Learn - Overview of integration with Application Insights: https://learn.microsoft.com/en-us/power-platform/admin/overview-integration-application-insights
- Microsoft Learn - Set up Application Insights with Power Automate: https://learn.microsoft.com/en-us/power-platform/admin/app-insights-cloud-flow
- Microsoft Learn - Configure Microsoft Entra diagnostic settings: https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-configure-diagnostic-settings
- Microsoft Learn - Set up Azure Monitor in external tenants: https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-azure-monitor
- Microsoft Learn - Create Azure Monitor log search alert rules: https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-log-alert-rule
- Microsoft Learn - Action groups in Azure Monitor: https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups
