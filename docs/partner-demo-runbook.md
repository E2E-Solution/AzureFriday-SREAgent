# Partner Demo Runbook

This runbook captures the deployed technical partner implementation demo environment.

## Deployment

- Subscription: `<YOUR-SUBSCRIPTION-NAME>`
- Resource group: `rg-zava77ac`
- Region: `centralus`
- Prefix: `zava77ac`
- Demo policy tag: `SecurityControl=Ignore`

## Resource URLs

- Main API: `https://app-zava77ac.azurewebsites.net`
- IT portal: `https://app-zava77ac-itportal.azurewebsites.net`
- Warranty API: `https://app-zava77ac-warranty.azurewebsites.net`
- SQL server: `sql-zava77ac.database.windows.net`
- SQL database: `sqldb-zava77ac`
- Dashboard: Azure Portal search for `dash-zava77ac`
- SRE Agent portal: `https://sre.azure.com`

## Verified Checks

```powershell
Invoke-RestMethod https://app-zava77ac.azurewebsites.net/health
Invoke-RestMethod https://app-zava77ac.azurewebsites.net/api/products
Invoke-RestMethod https://app-zava77ac-warranty.azurewebsites.net/health
Invoke-RestMethod https://app-zava77ac-warranty.azurewebsites.net/devices
Invoke-WebRequest https://app-zava77ac-itportal.azurewebsites.net/
```

## Simulator Environment

Set these before running scenarios. Keep the SQL password out of source control.

```powershell
$env:ZAVA_SQL_SERVER = "sql-zava77ac.database.windows.net"
$env:ZAVA_SQL_DATABASE = "sqldb-zava77ac"
$env:ZAVA_SQL_USER = "sqladmin"
$env:ZAVA_SQL_PASSWORD = "<demo-sql-password>"
$env:ZAVA_APP_URL = "https://app-zava77ac.azurewebsites.net"
$env:ZAVA_SUBSCRIPTION_ID = "<YOUR-SUBSCRIPTION-ID>"
```

For ServiceNow, add these when Scenario 4 is ready:

```powershell
$env:ZAVA_SN_URL = "https://<instance>.service-now.com"
$env:ZAVA_SN_USER = "admin"
$env:ZAVA_SN_PASS = "<servicenow-password>"
```

## Scenario Order

1. SQL slow-query remediation: `python simulator/demo.py 1`
2. SQL blocking chain: `python simulator/demo.py 2`
3. Bad deployment health validation: `python simulator/demo.py 3`
4. ServiceNow laptop replacement: `python simulator/demo.py 4`
5. Reset between rehearsals: `python simulator/demo.py 5`

The first slow-query run expands `Products` to about 2 million rows. Expect that one-time setup to take several minutes on Basic SQL.

## SRE Agent Setup Notes

The current demo uses `srectl` for repeatable configuration deployment. The CLI was installed manually from the internal Azure Artifacts feed at `https://dev.azure.com/msazure/One/_artifacts/feed/SREAgentCli` because direct NuGet feed authentication was unreliable in this environment.

For the full CLI setup, install, resource deployment, profile, and apply commands, use [srectl-deployment-guide.md](srectl-deployment-guide.md).

For detailed portal-only setup, use [manual-sre-agent-portal-setup.md](manual-sre-agent-portal-setup.md).

Current SRE Agent resources:

- Original Agent 1: `zava-sreagent-1`
  - Endpoint: `https://<YOUR-AGENT-1-ENDPOINT>.australiaeast.azuresre.ai`
  - Profile: `zava-agent1`
- Agent 2: `zava-sreagent-2`
  - Endpoint: `https://<YOUR-AGENT-2-ENDPOINT>.australiaeast.azuresre.ai`
  - Profile: `zava-agent2`
  - Remote objects: `CheckWarranty`, `LookupServiceNowIncident`, `it-support-handler`
- Agent 3: `zava-sreagent-3`
  - Endpoint: `https://<YOUR-AGENT-3-ENDPOINT>.australiaeast.azuresre.ai`
  - Profile: `zava-agent3`
  - Remote objects: SQL skills, `AssessChangeRisk`, hooks, deployment validators, and `weekly-cost-report`

Use these profile commands during the demo:

```powershell
srectl profile list
srectl profile set --name zava-agent2
srectl status
srectl profile set --name zava-agent3
srectl status
```

Agent 3 is the clean redeploy target for the Agent 1 SQL/app performance configuration. The original Agent 1 resource remains in place for comparison or fallback.

## Portal Configuration Still Required

The CLI installs custom tools, skills, hooks, agents, and scheduled tasks. Some connectors and triggers may still need to be configured in `https://sre.azure.com`, depending on portal capabilities and secret handling.

Agent 1: SQL and app performance

- Add Azure resource access to `rg-zava77ac`.
- Connect this GitHub repository.
- Add SQL MCP with this connection string shape:

```text
Server=tcp:sql-zava77ac.database.windows.net,1433;Database=sqldb-zava77ac;User ID=sqladmin;Password=<demo-sql-password>;Encrypt=True;TrustServerCertificate=False;
```

- Add GitHub MCP with a fine-grained PAT for this repo.
- Link alert handlers for `alert-zava77ac-dtu-high`, `alert-zava77ac-http-5xx`, and `alert-zava77ac-health-check`.
- If using Agent 3, the Agent 1 skills, tools, hooks, scheduled task, and custom agents have already been applied from `sre-config/agent1` with `srectl`.

Agent 2: IT support and ServiceNow

- Add Azure resource access to `rg-zava77ac`.
- Configure the ServiceNow native tools or connector.
- Configure `LookupServiceNowIncident` with the ServiceNow instance URL and credentials through the SRE Agent portal or secret settings.
- Configure `CheckWarranty` with `WARRANTY_API_URL=https://app-zava77ac-warranty.azurewebsites.net` if the portal supports tool environment variables.
- If using `zava-sreagent-2`, the Agent 2 tools and custom agent have already been applied from `sre-config/agent2` with `srectl`.

## Known Deployment Notes

- `westus2`, `eastus`, and `eastus2` were blocked for Azure SQL provisioning in this subscription; `centralus` succeeded.
- `srectl` was installed from package `sreagent.cli` in the internal Azure Artifacts feed `SREAgentCli`. The working version was `1.0.38`.
- This `srectl` version uses `srectl profile create`, `srectl profile set`, and `srectl init --resource-url`. It does not use the older `srectl config set-context` syntax.
- The repository references `.github/workflows/deploy.yml`, but that file is not present. Use the simulator/manual HTTP trigger path for Scenario 3 unless a workflow is added.
