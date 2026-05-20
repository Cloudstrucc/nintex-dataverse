# Azure Monitor and Microsoft Purview Monitoring for Power Platform

## Document Control

| Field | Value |
|---|---|
| Organization | Elections Canada |
| Document owner | Platform Engineering |
| Author | Frederick Pearson |
| Target implementation teams | IT Operations, Power Platform Administrators, Identity Operations, Purview/Compliance Administrators |
| Primary technologies | Azure Monitor, Log Analytics, Application Insights, Microsoft Purview, Entra External ID diagnostic settings |
| Primary workload scope | Power Pages, Power Apps, Dataverse, Power Automate, external user sign-in and registration telemetry |

## Implementation Summary

Elections Canada will use Azure Monitor as the operational monitoring layer for Power Platform environments and external-facing Power Pages sites. Azure Monitor will collect telemetry through Application Insights, store telemetry in Log Analytics, execute operational alert rules, notify IT Operations through action groups, and support IT Operations dashboards and support runbooks.

Elections Canada will use Microsoft Purview as the audit and compliance evidence layer for Power Platform. Purview will provide audit records for Power Platform admin activity, Power Apps activity, Dataverse/model-driven app activity, and compliance investigation support. Purview evidence will support operational investigations, compliance reviews, eDiscovery support, and evidence packages for incidents or service tickets.

Elections Canada will route Entra External ID diagnostics to Azure Monitor because Power Pages sites use Entra External ID for external user sign-in and registration. This will allow IT Operations and Identity Operations to validate the health and reliability of sign-in, registration, and identity diagnostics for external users.


<div class="diagram" role="img" aria-label="Azure Monitor and Microsoft Purview operational monitoring architecture for Power Platform and Entra External ID">
<svg viewBox="0 0 1040 520" width="100%" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="2" stdDeviation="2" flood-opacity="0.14"/></filter>
    <marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M0,0 L0,6 L9,3 z" fill="#1e384b"/></marker>
  </defs>
  <rect x="10" y="10" width="1020" height="500" rx="16" fill="#f8f8f8" stroke="#d8d8d8"/>
  <text x="35" y="44" font-size="22" font-weight="700" fill="#222">Elections Canada - Azure Monitor and Purview monitoring boundary</text>
  <g filter="url(#shadow)">
    <rect x="50" y="90" width="220" height="110" rx="12" fill="#ffffff" stroke="#6a0032" stroke-width="2"/>
    <text x="70" y="122" font-size="18" font-weight="700" fill="#6a0032">Power Platform</text>
    <text x="70" y="150" font-size="13" fill="#333">Power Pages</text><text x="70" y="170" font-size="13" fill="#333">Power Apps / Dataverse</text><text x="70" y="190" font-size="13" fill="#333">Power Automate</text>
    <rect x="50" y="260" width="220" height="110" rx="12" fill="#ffffff" stroke="#036064" stroke-width="2"/>
    <text x="70" y="292" font-size="18" font-weight="700" fill="#036064">Entra External ID</text>
    <text x="70" y="320" font-size="13" fill="#333">External users</text><text x="70" y="340" font-size="13" fill="#333">Sign-in and registration</text><text x="70" y="360" font-size="13" fill="#333">Audit and diagnostic logs</text>
    <rect x="360" y="90" width="230" height="110" rx="12" fill="#ffffff" stroke="#1e384b" stroke-width="2"/>
    <text x="380" y="122" font-size="18" font-weight="700" fill="#1e384b">Application Insights</text>
    <text x="380" y="150" font-size="13" fill="#333">Operational telemetry</text><text x="380" y="170" font-size="13" fill="#333">Requests, dependencies</text><text x="380" y="190" font-size="13" fill="#333">Exceptions, traces</text>
    <rect x="360" y="260" width="230" height="110" rx="12" fill="#ffffff" stroke="#1e384b" stroke-width="2"/>
    <text x="380" y="292" font-size="18" font-weight="700" fill="#1e384b">Log Analytics</text>
    <text x="380" y="320" font-size="13" fill="#333">Workspace storage</text><text x="380" y="340" font-size="13" fill="#333">KQL queries</text><text x="380" y="360" font-size="13" fill="#333">Operational evidence</text>
    <rect x="700" y="90" width="260" height="110" rx="12" fill="#ffffff" stroke="#8b9538" stroke-width="2"/>
    <text x="720" y="122" font-size="18" font-weight="700" fill="#8b9538">Azure Monitor</text>
    <text x="720" y="150" font-size="13" fill="#333">Alerts and action groups</text><text x="720" y="170" font-size="13" fill="#333">Workbooks and dashboards</text><text x="720" y="190" font-size="13" fill="#333">IT Operations triage</text>
    <rect x="700" y="260" width="260" height="110" rx="12" fill="#ffffff" stroke="#6a0032" stroke-width="2"/>
    <text x="720" y="292" font-size="18" font-weight="700" fill="#6a0032">Microsoft Purview</text>
    <text x="720" y="320" font-size="13" fill="#333">Audit evidence</text><text x="720" y="340" font-size="13" fill="#333">DLP and compliance records</text><text x="720" y="360" font-size="13" fill="#333">eDiscovery support</text>
  </g>
  <line x1="270" y1="145" x2="360" y2="145" stroke="#1e384b" stroke-width="3" marker-end="url(#arrow)"/>
  <line x1="590" y1="145" x2="700" y2="145" stroke="#1e384b" stroke-width="3" marker-end="url(#arrow)"/>
  <line x1="270" y1="315" x2="360" y2="315" stroke="#1e384b" stroke-width="3" marker-end="url(#arrow)"/>
  <line x1="590" y1="315" x2="700" y2="315" stroke="#6a0032" stroke-width="3" marker-end="url(#arrow)"/>
  <path d="M 165 200 C 165 230, 720 220, 720 260" fill="none" stroke="#6a0032" stroke-width="3" marker-end="url(#arrow)"/>
  <path d="M 475 200 L 475 260" fill="none" stroke="#1e384b" stroke-width="3" marker-end="url(#arrow)"/>
  <rect x="70" y="425" width="890" height="48" rx="8" fill="#fff" stroke="#cfcfcf"/>
  <text x="90" y="455" font-size="13" fill="#333">Implementation result: IT Operations receives operational alerts from Azure Monitor, while Purview provides audit and compliance evidence for Power Platform and external identity activity.</text>
</svg>
</div>


## Monitoring Requirements

### Azure Monitor operational requirements

Elections Canada will implement Azure Monitor to monitor operational health and reliability for the following Power Platform workload areas:

- Power Pages availability and response behaviour.
- Power Automate cloud flow run failures.
- Power Automate trigger and action dependency failures.
- Dataverse and model-driven app diagnostics and performance telemetry.
- Canvas app client-side errors and application traces where telemetry is exported.
- Custom connector, API, gateway, and Azure dependency failures where those dependencies are visible in Application Insights.
- Telemetry ingestion health for Power Platform telemetry exports.
- Entra External ID sign-in and registration diagnostic log flow to Log Analytics.

### Microsoft Purview evidence requirements

Elections Canada will implement Microsoft Purview audit and compliance evidence procedures for the following Power Platform workload areas:

- Power Platform tenant and environment administration activity.
- Power Apps activity and maker/user activity available in Purview audit.
- Dataverse and model-driven app activity where auditing is enabled and Purview can access the activity logs.
- DLP, compliance, retention, and eDiscovery support records where applicable.
- Evidence export, screenshot capture, and audit-search result preservation for support and investigation tickets.

### Entra External ID operational requirements

Elections Canada will collect Entra External ID diagnostic logs into Log Analytics to support Power Pages external authentication monitoring. The operational monitoring implementation will include:

- Diagnostic settings in the external tenant.
- Log Analytics routing for sign-in and audit activity categories available in the tenant.
- Operational alerts for external authentication failure spikes.
- Operational alerts for registration-related issues and high-volume failure patterns where captured in available logs.
- Operational alerts for diagnostic ingestion gaps.

## Target Architecture

### Logical architecture

Power Platform operational telemetry will be exported into Application Insights. Application Insights will be connected to a Log Analytics workspace so IT Operations can use Azure Monitor Logs, KQL, alert rules, action groups, workbooks, and dashboard queries. Entra External ID diagnostic settings will route external identity diagnostics to the same or a dedicated Log Analytics workspace, depending on Elections Canada workspace segmentation policy.

Microsoft Purview will remain the audit and compliance evidence source for Power Platform activities that are captured by Purview audit. Purview will not be used as the operational telemetry platform. Azure Monitor will own operational alerts and dashboards. Purview will own audit search, compliance evidence, and retention/eDiscovery support.

### Data flow

- Power Pages, Dataverse, Power Apps, and Power Automate telemetry flows to Application Insights through the Power Platform data export capability.
- Application Insights telemetry is queryable through Azure Monitor Logs / Log Analytics.
- Azure Monitor alert rules execute KQL or metric-based alerting logic against the Application Insights or workspace data.
- Azure Monitor action groups notify IT Operations destinations such as email distribution lists, Teams/webhook endpoints, ITSM integrations, or automation endpoints.
- Entra External ID diagnostic settings send identity diagnostics to Log Analytics.
- Power Platform audit records are made available in Microsoft Purview after environment auditing and Purview audit access settings are configured.
- Purview search and export results are attached as evidence to investigation records or operational tickets when audit evidence is required.

## Resource Naming and Placeholder Standards

Resource names in the build book use placeholders. Implementers must replace placeholder values with approved Elections Canada names before deployment.

| Artifact | Placeholder | Suggested production naming pattern |
|---|---|---|
| Azure subscription | `<AZURE_SUBSCRIPTION_ID>` | Existing approved Elections Canada Azure subscription |
| Azure resource group | `<RESOURCE_GROUP_NAME>` | `rg-ec-pp-monitoring-prod-cac` |
| Azure region | `<AZURE_REGION>` | `canadacentral` |
| Log Analytics workspace | `<LOG_ANALYTICS_WORKSPACE_NAME>` | `law-ec-pp-monitoring-prod-cac` |
| Application Insights resource | `<APPLICATION_INSIGHTS_NAME>` | `appi-ec-pp-prod-cac` |
| Azure Monitor action group | `<ACTION_GROUP_NAME>` | `ag-ec-pp-itops-prod` |
| Action group short name | `<ACTION_GROUP_SHORT_NAME>` | `EC-PP-OPS` |
| Power Platform production environment | `<POWER_PLATFORM_ENVIRONMENT_NAME>` | `EC-PP-PROD` |
| Power Platform environment ID | `<POWER_PLATFORM_ENVIRONMENT_ID>` | Environment GUID from Power Platform admin center |
| Power Platform export package | `<POWER_PLATFORM_EXPORT_PACKAGE_NAME>` | `export-ec-pp-prod-to-appi` |
| Entra External ID tenant | `<EXTERNAL_ID_TENANT_ID>` | External tenant GUID |
| Entra diagnostic setting | `<ENTRA_DIAGNOSTIC_SETTING_NAME>` | `diag-ec-extid-to-law-prod` |
| Evidence folder | `<EVIDENCE_REPOSITORY_URL>` | Approved SharePoint/records repository location |

## Roles and Responsibilities

| Team | Implementation responsibility | Operational responsibility |
|---|---|---|
| IT Operations | Create or validate Log Analytics, Application Insights, Azure Monitor action groups, alert rules, workbooks, and operational validation. | Triage operational alerts, maintain thresholds, attach evidence to tickets, manage operational runbooks. |
| Power Platform Administrators | Configure Power Platform data export to Application Insights and validate environment-level telemetry. | Validate Power Platform environment telemetry and assist with flow/app/environment triage. |
| Identity Operations | Configure Entra External ID diagnostic routing to Log Analytics. | Triage external identity operational alerts and validate sign-in/registration flows. |
| Purview/Compliance Administrators | Configure Purview audit access, validate audit search, and define evidence export procedures. | Support audit/eDiscovery/compliance evidence requests and maintain role-based access to Purview evidence. |
| Security/SOC | Consume relevant telemetry from operational or audit sources when needed by security workflows. | Correlate with SIEM tooling under the separate security monitoring build books. |

## Azure Monitor Alert Catalogue

The following operational alerts are implemented for Power Platform monitoring. Thresholds are starting values and must be tuned through change control after baselining production activity.

| Alert name | Severity | Workload | Purpose | Initial threshold |
|---|---:|---|---|---|
| `<ALERT_PP_POWERPAGES_AVAILABILITY_FAILURE>` | Sev 2 | Power Pages | Detect repeated availability test failures for external-facing sites. | Failed availability count >= 3 in 15 minutes |
| `<ALERT_PP_POWERPAGES_RESPONSE_TIME_HIGH>` | Sev 3 | Power Pages | Detect sustained high page response time. | 95th percentile duration > 5 seconds over 15 minutes |
| `<ALERT_PP_FLOW_RUN_FAILURE_SPIKE>` | Sev 2 | Power Automate | Detect elevated failed cloud flow runs. | Failed requests >= 5 in 15 minutes |
| `<ALERT_PP_FLOW_DEPENDENCY_FAILURE_SPIKE>` | Sev 3 | Power Automate | Detect trigger/action connector or dependency failures. | Failed dependencies >= 10 in 15 minutes |
| `<ALERT_PP_DATAVERSE_EXCEPTION_SPIKE>` | Sev 2 | Dataverse / model-driven apps | Detect application exception spikes. | Exceptions >= 5 in 15 minutes |
| `<ALERT_PP_CONNECTOR_DEPENDENCY_FAILURE>` | Sev 3 | Connectors / APIs | Detect failed downstream calls or gateway/API dependencies. | Failed dependencies >= 10 in 15 minutes |
| `<ALERT_PP_TELEMETRY_INGESTION_GAP>` | Sev 2 | Monitoring pipeline | Detect missing telemetry from the production environment. | No telemetry for 60 minutes during expected production hours |
| `<ALERT_EXTID_FAILED_SIGNIN_SPIKE>` | Sev 2 | Entra External ID | Detect spikes in external user authentication failures. | Failed sign-ins >= 20 in 15 minutes |
| `<ALERT_EXTID_AUDIT_ACTIVITY_SPIKE>` | Sev 3 | Entra External ID | Detect unusual spikes in external identity audit activity. | Audit events >= 50 in 15 minutes |
| `<ALERT_EXTID_DIAGNOSTIC_INGESTION_GAP>` | Sev 2 | External identity monitoring | Detect missing external tenant diagnostic logs. | No sign-in/audit logs for 60 minutes during expected activity window |

## Azure Monitor Dashboard and Workbook Requirements

Elections Canada will implement an Azure Monitor workbook for IT Operations. The workbook will include:

- Power Platform environment selection by `<POWER_PLATFORM_ENVIRONMENT_ID>`.
- Power Pages availability and response time trend.
- Power Automate failed request trend.
- Power Automate dependency failure trend.
- Dataverse/model-driven app exception trend.
- Connector/API dependency failure trend.
- Entra External ID failed sign-in trend.
- Telemetry ingestion status.
- Links to support runbooks and evidence folder locations.

## Appendix A - Azure Monitor Operational Build Book

### Prerequisites

- An approved Azure subscription `<AZURE_SUBSCRIPTION_ID>` is required for the monitoring resources.
- An approved Azure resource group `<RESOURCE_GROUP_NAME>` is required in `<AZURE_REGION>`.
- A Log Analytics workspace `<LOG_ANALYTICS_WORKSPACE_NAME>` is required for Azure Monitor Logs.
- A workspace-based Application Insights resource `<APPLICATION_INSIGHTS_NAME>` is required for Power Platform telemetry.
- A Power Platform production environment `<POWER_PLATFORM_ENVIRONMENT_NAME>` is required in scope for monitoring.
- The implementer requires Global Administrator or appropriate delegated roles, plus Power Platform Administrator and Azure Owner/Contributor access for the target subscription/resource group.
- The implementer requires access to the Power Platform admin center, Azure portal, Entra admin center, and evidence repository `<EVIDENCE_REPOSITORY_URL>`.
- A notification destination for IT Operations is required before action group configuration. Use placeholder `<IT_OPERATIONS_NOTIFICATION_DESTINATION>`.

### Create or validate the Azure resource group

Portal implementation:

- Sign in to the Azure portal as a Global Administrator or an account with delegated Azure permissions.
- Open **Subscriptions**.
- Select subscription `<AZURE_SUBSCRIPTION_ID>`.
- Select **Resource groups**.
- Select **Create**.
- Enter resource group name `<RESOURCE_GROUP_NAME>`.
- Select region `<AZURE_REGION>`.
- Select **Review + create**.
- Select **Create**.

Optional Azure PowerShell:

```powershell
Connect-AzAccount -Tenant "<TENANT_ID>"
Set-AzContext -SubscriptionId "<AZURE_SUBSCRIPTION_ID>"
New-AzResourceGroup -Name "<RESOURCE_GROUP_NAME>" -Location "<AZURE_REGION>"
```

Evidence capture:

- Take a screenshot of the resource group **Overview** page showing resource group name, subscription, and region.
- Save the screenshot as `EV-AZMON-001-ResourceGroup.png` in `<EVIDENCE_REPOSITORY_URL>`.

### Create or validate the Log Analytics workspace

Portal implementation:

- In the Azure portal, search for **Log Analytics workspaces**.
- Select **Create**.
- Select subscription `<AZURE_SUBSCRIPTION_ID>`.
- Select resource group `<RESOURCE_GROUP_NAME>`.
- Enter workspace name `<LOG_ANALYTICS_WORKSPACE_NAME>`.
- Select region `<AZURE_REGION>`.
- Select **Review + create**.
- Select **Create**.
- Open the new workspace.
- Select **Usage and estimated costs**.
- Set the daily cap according to Elections Canada cost-management requirements.
- Select **Data retention** and set operational retention according to Elections Canada operational support policy. Use 90 days as a starting operational value unless the approved policy states otherwise.

Optional Azure PowerShell:

```powershell
New-AzOperationalInsightsWorkspace `
  -ResourceGroupName "<RESOURCE_GROUP_NAME>" `
  -Name "<LOG_ANALYTICS_WORKSPACE_NAME>" `
  -Location "<AZURE_REGION>" `
  -Sku "PerGB2018"
```

Evidence capture:

- Take a screenshot of the workspace **Overview** page.
- Take a screenshot of **Usage and estimated costs** showing retention and cost controls.
- Save evidence as `EV-AZMON-002-LogAnalyticsOverview.png` and `EV-AZMON-003-LogAnalyticsRetention.png`.

### Create or validate Application Insights

Portal implementation:

- In the Azure portal, search for **Application Insights**.
- Select **Create**.
- Select subscription `<AZURE_SUBSCRIPTION_ID>`.
- Select resource group `<RESOURCE_GROUP_NAME>`.
- Enter name `<APPLICATION_INSIGHTS_NAME>`.
- Select region `<AZURE_REGION>`.
- Set **Resource Mode** to **Workspace-based**.
- Select Log Analytics workspace `<LOG_ANALYTICS_WORKSPACE_NAME>`.
- Select **Review + create**.
- Select **Create**.
- Open the Application Insights resource.
- Select **Properties** and record the Application ID, Connection string, and linked workspace name in the implementation record.

Optional Azure PowerShell:

```powershell
$workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName "<RESOURCE_GROUP_NAME>" -Name "<LOG_ANALYTICS_WORKSPACE_NAME>"
New-AzApplicationInsights `
  -ResourceGroupName "<RESOURCE_GROUP_NAME>" `
  -Name "<APPLICATION_INSIGHTS_NAME>" `
  -Location "<AZURE_REGION>" `
  -WorkspaceResourceId $workspace.ResourceId
```

Evidence capture:

- Take a screenshot of the Application Insights **Overview** page.
- Take a screenshot of **Properties** showing the linked workspace.
- Save evidence as `EV-AZMON-004-AppInsightsOverview.png` and `EV-AZMON-005-AppInsightsProperties.png`.

### Configure Power Platform export to Application Insights

Portal implementation:

- Sign in to the Power Platform admin center.
- Select **Manage**.
- Select **Data export**.
- Select the **App Insights** tab.
- Select **New data export**.
- Enter export package name `<POWER_PLATFORM_EXPORT_PACKAGE_NAME>`.
- Select the data types required for the workload:
  - Dataverse diagnostics and performance.
  - Power Automate cloud flow runs.
  - Power Automate triggers and actions.
- Select filters for environment `<POWER_PLATFORM_ENVIRONMENT_NAME>` and environment ID `<POWER_PLATFORM_ENVIRONMENT_ID>`.
- Select **Next**.
- Select Azure subscription `<AZURE_SUBSCRIPTION_ID>`.
- Select resource group `<RESOURCE_GROUP_NAME>`.
- Select Application Insights resource `<APPLICATION_INSIGHTS_NAME>`.
- Select **Next**.
- Review the package details.
- Select **Create**.
- Record the export package name and creation timestamp in the implementation record.

Validation:

- Wait for telemetry to begin. Microsoft states that data starts being exported to Application Insights within 24 hours after setup.
- Open Application Insights `<APPLICATION_INSIGHTS_NAME>`.
- Select **Logs**.
- Run the validation query:

```kusto
union isfuzzy=true requests, dependencies, exceptions, traces, AppRequests, AppDependencies, AppExceptions, AppTraces
| where TimeGenerated >= ago(24h) or timestamp >= ago(24h)
| summarize Records=count() by Type
```

Evidence capture:

- Take a screenshot of the Power Platform data export package summary.
- Take a screenshot of the Application Insights **Logs** query result showing records.
- Save evidence as `EV-AZMON-006-PPExportPackage.png` and `EV-AZMON-007-TelemetryValidation.png`.

### Configure an Azure Monitor action group

Portal implementation:

- In the Azure portal, open **Monitor**.
- Select **Alerts**.
- Select **Action groups**.
- Select **Create**.
- Select subscription `<AZURE_SUBSCRIPTION_ID>` and resource group `<RESOURCE_GROUP_NAME>`.
- Enter action group name `<ACTION_GROUP_NAME>`.
- Enter display name `<ACTION_GROUP_SHORT_NAME>`.
- Open the **Notifications** tab.
- Add notification type `<IT_OPERATIONS_NOTIFICATION_TYPE>`.
- Enter destination `<IT_OPERATIONS_NOTIFICATION_DESTINATION>`.
- Open the **Actions** tab.
- Add webhook, Logic App, ITSM, or automation action only if approved by Elections Canada operational process.
- Select **Review + create**.
- Select **Create**.

Optional Azure PowerShell:

```powershell
$email = New-AzActionGroupReceiver -Name "IT Operations" -EmailReceiver -EmailAddress "<IT_OPERATIONS_EMAIL>"
Set-AzActionGroup `
  -ResourceGroupName "<RESOURCE_GROUP_NAME>" `
  -Name "<ACTION_GROUP_NAME>" `
  -ShortName "<ACTION_GROUP_SHORT_NAME>" `
  -Receiver $email
```

Evidence capture:

- Take a screenshot of the action group **Overview** page.
- Take a screenshot of the configured notification destination, masking personal addresses if required by privacy process.
- Save evidence as `EV-AZMON-008-ActionGroup.png`.

### Configure Azure Monitor alert rules

For each alert rule in the alert catalogue:

- In the Azure portal, open **Monitor**.
- Select **Alerts**.
- Select **Create**.
- Select **Alert rule**.
- On **Scope**, select Application Insights `<APPLICATION_INSIGHTS_NAME>` or Log Analytics workspace `<LOG_ANALYTICS_WORKSPACE_NAME>` based on the alert query source.
- Select **Condition**.
- Select **Custom log search**.
- Paste the KQL query for the alert.
- Select **Run** to validate that the query executes.
- Configure measurement using the documented threshold.
- Configure evaluation frequency and lookback period.
- Select **Actions**.
- Select action group `<ACTION_GROUP_NAME>`.
- Select **Details**.
- Enter the alert rule name from the alert catalogue.
- Set severity as defined in the alert catalogue.
- Enter a description that includes environment, workload, threshold, triage owner, and runbook link.
- Select **Review + create**.
- Select **Create**.

Power Pages availability failure query:

```kusto
AppAvailabilityResults
| where TimeGenerated >= ago(15m)
| where Name contains "<POWER_PAGES_SITE_NAME>" or Location has "<POWER_PAGES_SITE_URL>"
| where Success == false
| summarize FailedChecks=count()
```

Power Automate failed flow run query:

```kusto
AppRequests
| where TimeGenerated >= ago(15m)
| where Properties["environmentId"] == "<POWER_PLATFORM_ENVIRONMENT_ID>" or tostring(Properties.environmentId) == "<POWER_PLATFORM_ENVIRONMENT_ID>"
| where Success == false
| summarize FailedRuns=count() by tostring(OperationName)
```

Power Automate dependency failure query:

```kusto
AppDependencies
| where TimeGenerated >= ago(15m)
| where Properties["environmentId"] == "<POWER_PLATFORM_ENVIRONMENT_ID>" or tostring(Properties.environmentId) == "<POWER_PLATFORM_ENVIRONMENT_ID>"
| where Success == false
| summarize FailedDependencies=count() by tostring(Name), tostring(Target)
```

Dataverse/model-driven app exception query:

```kusto
AppExceptions
| where TimeGenerated >= ago(15m)
| where Properties["environmentId"] == "<POWER_PLATFORM_ENVIRONMENT_ID>" or tostring(Properties.environmentId) == "<POWER_PLATFORM_ENVIRONMENT_ID>"
| summarize ExceptionCount=count() by tostring(ProblemId), tostring(OuterMessage)
```

Telemetry ingestion gap query:

```kusto
union isfuzzy=true AppRequests, AppDependencies, AppExceptions, AppTraces
| where TimeGenerated >= ago(60m)
| where Properties["environmentId"] == "<POWER_PLATFORM_ENVIRONMENT_ID>" or tostring(Properties.environmentId) == "<POWER_PLATFORM_ENVIRONMENT_ID>"
| summarize TelemetryRecords=count()
```

Evidence capture:

- For each alert rule, take a screenshot of the **Condition** tab showing the query and threshold.
- Take a screenshot of the **Actions** tab showing `<ACTION_GROUP_NAME>`.
- Take a screenshot of the created alert rule **Overview** page.
- Save evidence with the pattern `EV-AZMON-ALERT-<ALERT_NAME>.png`.

### Create the IT Operations workbook

Portal implementation:

- In the Azure portal, open **Monitor**.
- Select **Workbooks**.
- Select **New**.
- Add a text block with the workbook title `Elections Canada - Power Platform Operational Monitoring`.
- Add a parameter for `<POWER_PLATFORM_ENVIRONMENT_ID>`.
- Add query tiles for:
  - Power Pages availability failures.
  - Power Pages response duration.
  - Power Automate failed runs.
  - Power Automate dependency failures.
  - Dataverse exception count.
  - Entra External ID failed sign-ins.
  - Telemetry ingestion status.
- Save the workbook as `<WORKBOOK_NAME>` using suggested name `wb-ec-pp-ops-monitoring-prod`.
- Set workbook permissions according to Elections Canada least-privilege requirements.

Evidence capture:

- Take a screenshot of the saved workbook overview.
- Take screenshots of each workbook section after queries return data.
- Save evidence as `EV-AZMON-009-WorkbookOverview.png` and related section screenshots.

## Appendix B - Entra External ID Operational Monitoring Build Book

### Prerequisites

- The Entra External ID tenant `<EXTERNAL_ID_TENANT_ID>` is required for external Power Pages authentication.
- A Log Analytics workspace `<LOG_ANALYTICS_WORKSPACE_NAME>` is required as the diagnostic destination.
- The implementer requires Global Administrator or Security Administrator access to configure tenant diagnostic settings.
- The implementer requires access to switch into the external tenant in the Entra admin center.

### Configure External ID diagnostics

Portal implementation:

- Sign in to the Microsoft Entra admin center.
- Use the directory switcher to switch to external tenant `<EXTERNAL_ID_TENANT_ID>`.
- Browse to **Entra ID**.
- Select **Monitoring & health**.
- Select **Diagnostic settings**.
- Select **Add diagnostic setting** or **Start set up** if the setup wizard is shown.
- Enter diagnostic setting name `<ENTRA_DIAGNOSTIC_SETTING_NAME>`.
- Select the available sign-in and audit log categories required by Elections Canada policy. At minimum, select available categories for sign-in activity and audit activity.
- Select **Send to Log Analytics workspace**.
- Select subscription `<AZURE_SUBSCRIPTION_ID>`.
- Select workspace `<LOG_ANALYTICS_WORKSPACE_NAME>`.
- Select **Save**.

Validation query:

```kusto
union isfuzzy=true SigninLogs, AADNonInteractiveUserSignInLogs, AuditLogs
| where TimeGenerated >= ago(24h)
| summarize Records=count() by Type
```

Failed external sign-in alert query:

```kusto
SigninLogs
| where TimeGenerated >= ago(15m)
| where ResultType != 0
| summarize FailedSignIns=count() by AppDisplayName, ResultDescription
```

External ID audit activity spike query:

```kusto
AuditLogs
| where TimeGenerated >= ago(15m)
| summarize AuditEvents=count() by OperationName, Result
```

External ID diagnostic ingestion gap query:

```kusto
union isfuzzy=true SigninLogs, AuditLogs
| where TimeGenerated >= ago(60m)
| summarize DiagnosticRecords=count()
```

Evidence capture:

- Take a screenshot of the external tenant diagnostic setting page showing the destination workspace.
- Take a screenshot of the validation query results in Log Analytics.
- Take screenshots of each External ID alert rule after creation.
- Save evidence as `EV-EXTID-001-DiagnosticSettings.png`, `EV-EXTID-002-ValidationQuery.png`, and `EV-EXTID-ALERT-<ALERT_NAME>.png`.

## Appendix C - Microsoft Purview Audit and Compliance Evidence Build Book

### Prerequisites

- Microsoft Purview audit access is required for authorized compliance and security staff.
- A Compliance Administrator, Security Administrator, or role with equivalent Purview permissions is required to validate audit search and evidence export.
- Power Platform production environments must have environment auditing configured.
- The Power Platform environment setting **Enable SAS Logging in Purview** must be enabled for each production environment in scope.
- The domain `https://*.api.powerplatformusercontent.com` must be allowed where the environment requires SAS functionality, in accordance with Microsoft guidance.
- Evidence exports must be saved to approved repository `<EVIDENCE_REPOSITORY_URL>`.

### Validate Purview audit access

Portal implementation:

- Sign in to the Microsoft Purview portal.
- Open **Solutions**.
- Select **Audit**.
- Confirm that the implementer can access audit search.
- Confirm that authorized staff are assigned either **Audit Logs** or **View-Only Audit Logs** roles as appropriate.

Optional PowerShell validation:

```powershell
Connect-ExchangeOnline -UserPrincipalName "<ADMIN_UPN>"
Get-ManagementRoleAssignment -Role "Audit Logs" | Format-Table RoleAssigneeName, Role
Get-ManagementRoleAssignment -Role "View-Only Audit Logs" | Format-Table RoleAssigneeName, Role
```

Evidence capture:

- Take a screenshot of the Purview **Audit** page.
- Take a screenshot or export of the role assignment validation, with privileged identities handled according to Elections Canada evidence-handling rules.
- Save evidence as `EV-PURVIEW-001-AuditAccess.png`.

### Enable Power Platform environment audit visibility in Purview

Portal implementation:

- Sign in to the Power Platform admin center as a Power Platform administrator or system administrator.
- Select **Manage**.
- Select **Environments**.
- Select production environment `<POWER_PLATFORM_ENVIRONMENT_NAME>`.
- Select **Settings**.
- Expand **Product**.
- Select **Privacy and Security**.
- Under **Storage Shared Access Signature (SAS) Security Settings**, set **Enable SAS Logging in Purview** to **On**.
- Select **Save**.
- Repeat for each production environment in scope.

Evidence capture:

- Take a screenshot of the environment **Privacy and Security** page showing **Enable SAS Logging in Purview** set to **On**.
- Save evidence as `EV-PURVIEW-002-SASLogging-<ENVIRONMENT_NAME>.png`.

### Validate Power Platform admin logs in Purview

Portal implementation:

- In Microsoft Purview, open **Solutions**.
- Select **Audit**.
- Create a new search for Power Platform administrative activity.
- Set the date range to the implementation window.
- Filter activities for Power Platform administration where available.
- Run the search.
- Validate that environment administration events are returned.
- Export the results if required by the RFC evidence process.

Evidence capture:

- Take a screenshot of the audit search query criteria.
- Take a screenshot of the returned result count.
- Save the export as `EV-PURVIEW-003-PowerPlatformAdminAudit.csv` if export is required.

### Validate Power Apps and Dataverse audit records in Purview

Portal implementation:

- In Microsoft Purview, open **Audit**.
- Search for Power Apps and Dataverse/model-driven app activities for production environment `<POWER_PLATFORM_ENVIRONMENT_NAME>`.
- Validate that records return for the selected timeframe.
- Capture search criteria, result count, and export reference.

Evidence capture:

- Take a screenshot of the audit search filters.
- Take a screenshot of result count and sample event details.
- Save evidence as `EV-PURVIEW-004-PowerAppsDataverseAudit.png`.

### Define the evidence procedure

The evidence package for operational monitoring must include:

- Screenshot of Log Analytics workspace configuration.
- Screenshot of Application Insights workspace linkage.
- Screenshot of Power Platform data export package.
- Screenshot of action group notification destination.
- Screenshot of every alert rule condition and action group assignment.
- Screenshot of workbook overview and critical tiles.
- Screenshot of Entra External ID diagnostic settings and validation query.
- Screenshot of Purview audit access and environment audit visibility.
- Exported Purview audit search files when required by an incident or compliance investigation.

## Appendix D - Operational Support Runbooks

### Power Pages availability failure

| Field | Runbook value |
|---|---|
| Alert name | `<ALERT_PP_POWERPAGES_AVAILABILITY_FAILURE>` |
| Severity | Sev 2 |
| Environment and workload affected | `<POWER_PLATFORM_ENVIRONMENT_NAME>` / `<POWER_PAGES_SITE_NAME>` |
| Query or metric used | `AppAvailabilityResults` failed checks |
| Expected first response | IT Operations validates whether the external-facing site is reachable from approved networks and public endpoints. |
| Initial triage steps | Review availability results, test site URL, check recent deployment/change tickets, validate authentication redirect to Entra External ID, review Power Platform service health. |
| Escalation owner | Power Platform support owner and web/application operations owner. |
| Closure criteria | Availability tests succeed for two consecutive evaluation windows and user-impacting incident record is updated. |
| False positives and tuning notes | Tune synthetic test locations and thresholds if transient regional network conditions create repeated non-actionable alerts. |

### Power Automate cloud flow failure spike

| Field | Runbook value |
|---|---|
| Alert name | `<ALERT_PP_FLOW_RUN_FAILURE_SPIKE>` |
| Severity | Sev 2 |
| Environment and workload affected | `<POWER_PLATFORM_ENVIRONMENT_NAME>` / production cloud flows |
| Query or metric used | `AppRequests` failed cloud flow runs |
| Expected first response | IT Operations identifies affected flow IDs and validates whether business process execution is impacted. |
| Initial triage steps | Review failed flow operation names, open Power Automate run history for affected flow, check connector status, validate service account authentication, review recent solution deployments. |
| Escalation owner | Power Platform application owner or flow owner. |
| Closure criteria | Failed run rate returns to baseline and affected business process owner confirms recovery. |
| False positives and tuning notes | Exclude known non-production flows and tune thresholds by production environment and critical flow grouping. |

### Dataverse exception spike

| Field | Runbook value |
|---|---|
| Alert name | `<ALERT_PP_DATAVERSE_EXCEPTION_SPIKE>` |
| Severity | Sev 2 |
| Environment and workload affected | `<POWER_PLATFORM_ENVIRONMENT_NAME>` / Dataverse and model-driven apps |
| Query or metric used | `AppExceptions` exception count |
| Expected first response | IT Operations identifies exception type, affected users, and affected app/module. |
| Initial triage steps | Review exception messages, correlate with recent plugin/workflow/app releases, check Dataverse service health, review integration failure patterns. |
| Escalation owner | Dataverse application support team. |
| Closure criteria | Exception count returns to baseline and root cause is documented in the ticket. |
| False positives and tuning notes | Suppress known benign exceptions only after approval and evidence of non-impact. |

### Entra External ID failed sign-in spike

| Field | Runbook value |
|---|---|
| Alert name | `<ALERT_EXTID_FAILED_SIGNIN_SPIKE>` |
| Severity | Sev 2 |
| Environment and workload affected | `<EXTERNAL_ID_TENANT_ID>` / Power Pages external authentication |
| Query or metric used | `SigninLogs` failures |
| Expected first response | Identity Operations validates whether external users are blocked from sign-in or registration. |
| Initial triage steps | Review result codes, app display name, conditional access impact, identity provider configuration, registration flow changes, and user reports. |
| Escalation owner | Identity Operations and Power Pages support owner. |
| Closure criteria | Failed sign-ins return to baseline and successful external sign-ins are observed. |
| False positives and tuning notes | Tune thresholds for expected campaign or registration peaks. Separate brute-force/security patterns are handled by the SIEM/security build books. |

### Telemetry ingestion gap

| Field | Runbook value |
|---|---|
| Alert name | `<ALERT_PP_TELEMETRY_INGESTION_GAP>` |
| Severity | Sev 2 |
| Environment and workload affected | Monitoring pipeline for `<POWER_PLATFORM_ENVIRONMENT_NAME>` |
| Query or metric used | Count of recent Application Insights telemetry records |
| Expected first response | IT Operations validates whether telemetry export is still functioning. |
| Initial triage steps | Check Power Platform data export configuration, Application Insights availability, Log Analytics ingestion, Azure service health, and recent permission changes. |
| Escalation owner | IT Operations monitoring owner and Power Platform administrator. |
| Closure criteria | Telemetry resumes and monitoring gap is documented with timeframe. |
| False positives and tuning notes | Apply business-hours logic for low-activity workloads if 24x7 telemetry volume is not expected. |

## Appendix E - Validation Checklist

- Log Analytics workspace `<LOG_ANALYTICS_WORKSPACE_NAME>` exists and is in the approved subscription and region.
- Application Insights `<APPLICATION_INSIGHTS_NAME>` exists and is workspace-based.
- Power Platform data export package `<POWER_PLATFORM_EXPORT_PACKAGE_NAME>` exists and points to the correct Application Insights resource.
- Application Insights telemetry records are visible in Logs.
- Azure Monitor action group `<ACTION_GROUP_NAME>` exists and sends test notifications to `<IT_OPERATIONS_NOTIFICATION_DESTINATION>`.
- All alert rules in the alert catalogue are created, enabled, named consistently, and mapped to the action group.
- The IT Operations workbook exists and returns data for the production environment.
- Entra External ID diagnostic setting `<ENTRA_DIAGNOSTIC_SETTING_NAME>` sends available sign-in and audit logs to Log Analytics.
- Purview audit access is validated for authorized personnel.
- Power Platform production environments have **Enable SAS Logging in Purview** turned on.
- Evidence screenshots and exports are saved in `<EVIDENCE_REPOSITORY_URL>`.

## References

- [Export data to Application Insights - Power Platform](https://learn.microsoft.com/en-us/power-platform/admin/set-up-export-application-insights)
- [Set up Application Insights with Power Automate](https://learn.microsoft.com/en-us/power-platform/admin/app-insights-cloud-flow)
- [Create or edit a log search alert rule - Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-create-log-alert-rule)
- [Create and manage action groups in Azure Monitor](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/action-groups)
- [Overview of Azure Monitor alerts](https://learn.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-overview)
- [Azure Monitor in external tenants - Microsoft Entra External ID](https://learn.microsoft.com/en-us/entra/external-id/customers/how-to-azure-monitor)
- [Integrate Microsoft Entra logs with Azure Monitor logs](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-integrate-activity-logs-with-azure-monitor-logs)
- [Power Platform activity logging and auditing in Microsoft Purview](https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-overview)
- [View Power Platform admin logs in Microsoft Purview](https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-power-platform-admin)
- [View Power Apps activity logs in Microsoft Purview](https://learn.microsoft.com/en-us/power-platform/admin/activity-logging-auditing/activity-logs-power-apps)
- [Manage Dataverse auditing](https://learn.microsoft.com/en-us/power-platform/admin/manage-dataverse-auditing)
