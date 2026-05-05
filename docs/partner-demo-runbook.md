# Partner Demo Runbook

This runbook captures the deployed technical partner implementation demo environment.

## Deployment

- Subscription: `ME-MngEnvMCAP352465-sithukyaw-2`
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
$env:ZAVA_SUBSCRIPTION_ID = "ff32b3d4-0692-4e68-a2d3-f896637777ac"
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

Create two agents in `https://sre.azure.com` and attach them to `rg-zava77ac`.

For detailed portal-only setup, use [manual-sre-agent-portal-setup.md](manual-sre-agent-portal-setup.md).

Agent 1: SQL and app performance

- Add Azure resource access to `rg-zava77ac`.
- Connect this GitHub repository.
- Add SQL MCP with this connection string shape:

```text
Server=tcp:sql-zava77ac.database.windows.net,1433;Database=sqldb-zava77ac;User ID=sqladmin;Password=<demo-sql-password>;Encrypt=True;TrustServerCertificate=False;
```

- Add GitHub MCP with a fine-grained PAT for this repo.
- Link alert handlers for `alert-zava77ac-dtu-high`, `alert-zava77ac-http-5xx`, and `alert-zava77ac-health-check`.
- Recreate/import the Agent 1 skills, tools, hooks, scheduled task, and custom agents from `sre-config/agent1`.

Agent 2: IT support and ServiceNow

- Add Azure resource access to `rg-zava77ac`.
- Configure the ServiceNow native tools or connector.
- Configure `LookupServiceNowIncident` with the ServiceNow instance URL and credentials through the SRE Agent portal or secret settings.
- Configure `CheckWarranty` with `WARRANTY_API_URL=https://app-zava77ac-warranty.azurewebsites.net` if the portal supports tool environment variables.
- Recreate/import the Agent 2 tools and custom agent from `sre-config/agent2`.

## Known Deployment Notes

- `westus2`, `eastus`, and `eastus2` were blocked for Azure SQL provisioning in this subscription; `centralus` succeeded.
- The public Learn docs emphasize portal-based SRE Agent setup. A public `srectl` install path was not found during implementation.
- The repository references `.github/workflows/deploy.yml`, but that file is not present. Use the simulator/manual HTTP trigger path for Scenario 3 unless a workflow is added.
