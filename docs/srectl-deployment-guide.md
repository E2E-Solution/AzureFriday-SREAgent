# srectl-Based SRE Agent Deployment Guide

This guide documents the deployment path used for the partner demo after installing `srectl` manually from the internal Azure Artifacts feed.

Use this guide when you want to create SRE Agent resources with Azure CLI/Bicep, then install the local agent, tool, skill, hook, and scheduled task configuration from `sre-config` with `srectl`.

## Demo Environment

- Subscription: `<YOUR-SUBSCRIPTION-NAME>`
- Subscription ID: `<YOUR-SUBSCRIPTION-ID>`
- Resource group: `rg-zava77ac`
- App region: `centralus`
- SRE Agent region: `australiaeast`
- Main API: `https://app-zava77ac.azurewebsites.net`
- IT portal: `https://app-zava77ac-itportal.azurewebsites.net`
- Warranty API: `https://app-zava77ac-warranty.azurewebsites.net`

Current SRE Agent resources:

| Role | Azure resource | Endpoint |
| ---- | -------------- | -------- |
| Original Agent 1 | `zava-sreagent-1` | `https://<YOUR-AGENT-1-ENDPOINT>.australiaeast.azuresre.ai` |
| Agent 2, IT support | `zava-sreagent-2` | `https://<YOUR-AGENT-2-ENDPOINT>.australiaeast.azuresre.ai` |
| Agent 3, SQL/app SRE | `zava-sreagent-3` | `https://<YOUR-AGENT-3-ENDPOINT>.australiaeast.azuresre.ai` |

Agent 1 was left intact. Agent 3 is the new SQL and app performance agent used when you want a clean redeploy of the Agent 1 configuration.

## Install srectl From Azure Artifacts

The working install path for this demo was manual download from the Azure Artifacts feed:

```text
https://dev.azure.com/msazure/One/_artifacts/feed/SREAgentCli
```

The installed package metadata is:

```text
Package ID: sreagent.cli
Version: 1.0.38
Command: srectl
Runtime: .NET 9
```

### Option A: Manual nupkg Download

Use this when direct NuGet feed authentication fails.

1. Open `https://dev.azure.com/msazure/One/_artifacts/feed/SREAgentCli` in a browser.
2. Sign in with an account that has access to the `msazure/One` Azure DevOps project and the `SREAgentCli` feed.
3. Select package `sreagent.cli`.
4. Download the desired `.nupkg`, for example `sreagent.cli.1.0.38.nupkg`.
5. Put the package in a local folder, for example:

```powershell
New-Item -ItemType Directory -Force .\.artifacts\srectl | Out-Null
Copy-Item "$env:USERPROFILE\Downloads\sreagent.cli.1.0.38.nupkg" .\.artifacts\srectl\
```

1. Install or update the global tool from that local folder:

```powershell
dotnet tool install --global sreagent.cli --add-source .\.artifacts\srectl --version 1.0.38

# If already installed, use update instead:
dotnet tool update --global sreagent.cli --add-source .\.artifacts\srectl --version 1.0.38
```

1. Verify the command:

```powershell
srectl --version
where.exe srectl
dotnet tool list --global
```

Expected global tool entry:

```text
Package Id        Version      Commands
----------------------------------------
sreagent.cli      1.0.38       srectl
```

### Option B: Direct Feed Install

Use this only if your Azure Artifacts NuGet authentication is working.

```powershell
dotnet nuget add source "https://pkgs.dev.azure.com/msazure/One/_packaging/SREAgentCli/nuget/v3/index.json" --name SREAgentCli
dotnet tool install --global sreagent.cli --add-source SREAgentCli --version 1.0.38
```

If the package is already installed:

```powershell
dotnet tool update --global sreagent.cli --add-source SREAgentCli --version 1.0.38
```

## Create SRE Agent Resources With Bicep

The repo includes `infra/sre-agent.bicep`, a reusable template for SRE Agent resources. It creates:

- `Microsoft.App/agents@2025-05-01-preview`
- A regional user-assigned managed identity
- Agent knowledge graph access scoped to `rg-zava77ac`
- AzMonitor incident management configuration
- Application Insights logging configuration
- Reader, Monitoring Reader, Log Analytics Reader, Azure Monitor Monitoring Contributor, and SRE Agent User role assignments

Before deploying, confirm Azure CLI is on the expected subscription:

```powershell
az account show --query "{name:name, id:id, tenantId:tenantId}" -o table
```

Deploy Agent 2:

```powershell
az deployment group create `
  --resource-group rg-zava77ac `
  --name SRE-Agent-zava-sreagent-2-cli `
  --template-file infra/sre-agent.bicep `
  --parameters agentName=zava-sreagent-2 `
               userAssignedIdentityName=zava-sreagent-2-uai `
               userObjectId=<YOUR-USER-OBJECT-ID> `
               location=australiaeast `
               appInsightsName=ai-zava77ac
```

Deploy Agent 3:

```powershell
az deployment group create `
  --resource-group rg-zava77ac `
  --name SRE-Agent-zava-sreagent-3-cli `
  --template-file infra/sre-agent.bicep `
  --parameters agentName=zava-sreagent-3 `
               userAssignedIdentityName=zava-sreagent-3-uai `
               userObjectId=<YOUR-USER-OBJECT-ID> `
               location=australiaeast `
               appInsightsName=ai-zava77ac
```

Validate the resources and capture endpoints:

```powershell
az resource show `
  --ids "/subscriptions/<YOUR-SUBSCRIPTION-ID>/resourceGroups/rg-zava77ac/providers/Microsoft.App/agents/zava-sreagent-2" `
  --query "{name:name, endpoint:properties.agentEndpoint, state:properties.provisioningState, power:properties.powerState, running:properties.runningState}" `
  -o json

az resource show `
  --ids "/subscriptions/<YOUR-SUBSCRIPTION-ID>/resourceGroups/rg-zava77ac/providers/Microsoft.App/agents/zava-sreagent-3" `
  --query "{name:name, endpoint:properties.agentEndpoint, state:properties.provisioningState, power:properties.powerState, running:properties.runningState}" `
  -o json
```

`runningState` may show `BuildingKnowledgeGraph` for a while after provisioning. That is expected.

## Configure srectl Profiles

This installed `srectl` version uses profiles and `init --resource-url`. It does not use the older `srectl config set-context` syntax.

Run these commands from the repository root:

```powershell
Set-Location C:\Work\AzureFriday-SREAgent

srectl profile create `
  --name zava-agent2 `
  --url "https://<YOUR-AGENT-2-ENDPOINT>.australiaeast.azuresre.ai" `
  --set-current

srectl init --resource-url "https://<YOUR-AGENT-2-ENDPOINT>.australiaeast.azuresre.ai"

srectl profile create `
  --name zava-agent3 `
  --url "https://<YOUR-AGENT-3-ENDPOINT>.australiaeast.azuresre.ai" `
  --set-current

srectl init --resource-url "https://<YOUR-AGENT-3-ENDPOINT>.australiaeast.azuresre.ai"
```

Check profiles:

```powershell
srectl profile list
srectl status
```

Expected profiles:

```text
zava-agent1
zava-agent2
zava-agent3
```

Note: `srectl init` creates local helper files such as `.github/instructions.md`, `agents/example_agent.yaml`, and `tools/example_tool.yaml` if they do not already exist.

## Apply Agent 2 Configuration

Agent 2 handles IT support and ServiceNow-oriented flows. It uses the local config under `sre-config/agent2`.

```powershell
Set-Location C:\Work\AzureFriday-SREAgent

srectl profile set --name zava-agent2
srectl init --resource-url "https://<YOUR-AGENT-2-ENDPOINT>.australiaeast.azuresre.ai"

Push-Location .\sre-config\agent2
srectl tool apply --name CheckWarranty
srectl tool apply --name LookupServiceNowIncident
srectl agent validate --name it-support-handler
srectl agent apply --name it-support-handler
Pop-Location

srectl tool list
srectl agent list
```

Expected remote resources:

```text
Tools:
- CheckWarranty
- LookupServiceNowIncident

Agents:
- it-support-handler
```

ServiceNow values should be configured through portal secret settings or your SRE Agent tool runtime configuration:

```text
SERVICENOW_URL=https://<instance>.service-now.com
SERVICENOW_USER=admin
SERVICENOW_PASS=<servicenow-password>
```

If the tool runtime supports environment variables, set:

```text
WARRANTY_API_URL=https://app-zava77ac-warranty.azurewebsites.net
```

The current `CheckWarranty` tool also defaults to the deployed warranty API when `WARRANTY_API_URL` is not set.

## Apply Agent 3 Configuration

Agent 3 is the clean redeploy target for the SQL and app performance configuration that was originally applied to Agent 1.

```powershell
Set-Location C:\Work\AzureFriday-SREAgent

srectl profile set --name zava-agent3
srectl init --resource-url "https://<YOUR-AGENT-3-ENDPOINT>.australiaeast.azuresre.ai"

Push-Location .\sre-config\agent1
srectl tool apply --name AssessChangeRisk

srectl skill apply --name sql-query-diagnosis
srectl skill apply --name sql-performance-fix
srectl skill apply --name sql-blocking-diagnosis
srectl skill apply --name sql-blocking-fix

srectl hook apply --file .\hooks\sql-write-guard.yaml
srectl hook apply --file .\hooks\change-risk-assessor.yaml

srectl agent validate --name sql-performance-investigator --check-tools
srectl agent validate --name deployment-validator --check-tools
srectl agent validate --name deployment-validator-gh --check-tools

srectl agent apply --name sql-performance-investigator
srectl agent apply --name deployment-validator
srectl agent apply --name deployment-validator-gh

srectl scheduledtask apply --file .\scheduledtasks\weekly-cost-report\weekly-cost-report.yaml
Pop-Location

srectl tool list
srectl skill list
srectl hook list
srectl agent list
srectl scheduledtask list
```

Expected remote resources:

```text
Tools:
- AssessChangeRisk

Skills:
- sql-query-diagnosis
- sql-performance-fix
- sql-blocking-diagnosis
- sql-blocking-fix

Hooks:
- sql-write-guard
- change-risk-assessor

Agents:
- sql-performance-investigator
- deployment-validator
- deployment-validator-gh

Scheduled tasks:
- weekly-cost-report
```

Important: `srectl scheduledtask apply` creates a scheduled task. Check `srectl scheduledtask list` before re-running it on the same endpoint to avoid duplicates.

## Smoke Tests

Check connectivity:

```powershell
srectl profile set --name zava-agent2
srectl status

srectl profile set --name zava-agent3
srectl status
```

Test Agent 2:

```powershell
srectl profile set --name zava-agent2
srectl agent test --name it-support-handler --message "Use CheckWarranty for serial number SN-2021-DEL-3344 and summarize whether a laptop replacement is eligible." --no-wait
```

Test Agent 3:

```powershell
srectl profile set --name zava-agent3
srectl agent test --name deployment-validator --message "Validate https://app-zava77ac.azurewebsites.net/health and summarize whether the deployment is healthy." --no-wait
```

For live rehearsals, omit `--no-wait` to open the interactive thread.

## Troubleshooting

- If `srectl config set-context` is referenced in older notes, replace it with `srectl profile create`, `srectl profile set`, and `srectl init --resource-url`.
- If `srectl profile create` cannot connect, confirm the SRE Agent Azure resource is `Succeeded` and `Running`.
- If `srectl agent validate --check-tools` fails, apply the referenced tools first or configure missing MCP connectors in `https://sre.azure.com`.
- If SQL skills cannot find `zava-mssql_*` tools, configure the SQL MCP connector in the portal with connection name `zava-mssql` or update the skill tool names.
- If GitHub MCP tools are missing, configure the GitHub MCP connector in the portal before testing `deployment-validator` or `deployment-validator-gh`.
- If direct NuGet feed authentication fails, use the manual `.nupkg` download path and install from a local folder.
