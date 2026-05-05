# Manual Azure SRE Agent Portal Setup

Use this guide when `srectl` is unavailable or cannot authenticate to the private NuGet feed. It maps the local files under `sre-config` to manual objects in `https://sre.azure.com`.

## Demo Environment

- Subscription: `ME-MngEnvMCAP352465-sithukyaw-2`
- Application resource group: `rg-zava77ac`
- Application region: `centralus`
- Main API: `https://app-zava77ac.azurewebsites.net`
- IT portal: `https://app-zava77ac-itportal.azurewebsites.net`
- Warranty API: `https://app-zava77ac-warranty.azurewebsites.net`
- SQL server: `sql-zava77ac.database.windows.net`
- SQL database: `sqldb-zava77ac`

Keep the SQL password, GitHub PAT, ServiceNow password, and Outlook consent out of source control.

## Before You Start

Prepare these values:

- SQL connection string:

```text
Server=tcp:sql-zava77ac.database.windows.net,1433;Database=sqldb-zava77ac;User ID=sqladmin;Password=<demo-sql-password>;Encrypt=True;TrustServerCertificate=False;
```

- GitHub PAT or OAuth access for `meetshamir/AzureFriday-SREAgent` or your fork.
- ServiceNow PDI URL, username, and password.
- Optional Outlook/Teams consent if you want Agent 2 to send notifications.

## Agent 1: SQL And App Performance

Agent 1 covers SQL performance, blocking diagnosis, deployment validation, alert response, and weekly cost reporting.

### 1. Create The SRE Agent Resource

1. Open `https://sre.azure.com`.
2. Select **Create Agent**.
3. Use these values:
   - Name: `zava-sreagent-1`
   - Subscription: `ME-MngEnvMCAP352465-sithukyaw-2`
   - Resource group: create/use an SRE-agent resource group, or use `rg-zava77ac` for the demo.
   - Region/model provider: choose any region/provider combination available in the portal.
4. Create the agent and wait for provisioning to succeed.
5. Select **Set up your agent**.

The agent resource region does not need to match the app region. The important part is granting it access to `rg-zava77ac`.

### 2. Add Azure Resource Access

1. Go to **Full setup** > **Azure Resources**.
2. Add resource group `rg-zava77ac`.
3. Choose permissions:
   - Use **Reader** if you only want investigation and metric/log analysis.
   - Use **Contributor** for the deployment-validator demo because it may restart apps or roll back app configuration after approval.
4. Confirm the portal created the managed identity role assignment.

### 3. Connect The Code Repository

1. Go to **Quickstart** or **Connectors** > **Code Repository**.
2. Add GitHub using OAuth or PAT.
3. Select `meetshamir/AzureFriday-SREAgent` or your fork.
4. Confirm the repository appears as connected.

### 4. Add SQL MCP Connector

The SQL skills reference tools with the `zava-mssql_` prefix, so name the MCP connection `zava-mssql` if the portal lets you choose the connection ID.

1. Go to **Builder** > **Connectors** > **Add connector**.
2. Choose **MCP** or **Custom MCP server**.
3. Use package/source: `mssql-mcp@latest`.
4. Set connection name or ID: `zava-mssql`.
5. Add environment variable:

```text
MSSQL_CONNECTION_STRING=Server=tcp:sql-zava77ac.database.windows.net,1433;Database=sqldb-zava77ac;User ID=sqladmin;Password=<demo-sql-password>;Encrypt=True;TrustServerCertificate=False;
```

1. Save and test the connector.
2. Confirm tools like these appear:
   - `zava-mssql_mssql_connect_database`
   - `zava-mssql_mssql_get_schema`
   - `zava-mssql_mssql_execute_query`
   - `zava-mssql_mssql_run_sql_query`

If the portal generates a different connection prefix, either rename the connector to `zava-mssql` or update the tool names in the four SQL skills.

### 5. Add GitHub MCP Connector

This is needed for deployment validation and root-cause analysis from commit diffs.

1. Go to **Builder** > **Connectors** > **Add connector**.
2. Choose GitHub MCP or Custom MCP.
3. Use package/source: `@github/github-mcp-server`.
4. Set connection name or ID: `github-mcp` if possible.
5. Add environment variable:

```text
GITHUB_PERSONAL_ACCESS_TOKEN=<fine-grained-pat>
```

1. Save and test repository read access.

### 6. Create Custom Tool: AssessChangeRisk

Create this before the SQL custom agent, because the agent references it.

1. Go to **Builder** > **Tools** > **Create tool**.
2. Type: **Python tool**.
3. Name: `AssessChangeRisk`.
4. Description: use the description from `sre-config/agent1/tools/AssessChangeRisk/AssessChangeRisk.yaml`.
5. Function code: copy the full `functionCode` block from that YAML.
6. Timeout: `240` seconds.
7. Parameters:
   - `operation`, string, required
   - `table_name`, string, required
   - `row_count`, integer if supported, otherwise string, required
   - `description`, string, required
8. Save and test with:

```text
operation=CREATE INDEX
table_name=Products
row_count=2000000
description=Add index on Products.Category for category search
```

Expected result: MEDIUM or HIGH risk with approval required.

### 7. Create SQL Skills

Go to **Builder** > **Skills** and create four skills. If the portal accepts Markdown with front matter, paste each `SKILL.md` as-is. If it uses separate fields, use the `name`, `description`, and body from each file.

Create these skills:

- `sql-query-diagnosis` from `sre-config/agent1/skills/sql-query-diagnosis/SKILL.md`
- `sql-performance-fix` from `sre-config/agent1/skills/sql-performance-fix/SKILL.md`
- `sql-blocking-diagnosis` from `sre-config/agent1/skills/sql-blocking-diagnosis/SKILL.md`
- `sql-blocking-fix` from `sre-config/agent1/skills/sql-blocking-fix/SKILL.md`

Attach the SQL MCP tools listed in each file. For the two fix skills, also ensure `AssessChangeRisk` and `AskUserQuestion` are available to the custom agent that uses the skills.

### 8. Create Guardrail Hooks

If your portal build exposes **Hooks**, **Guardrails**, or **Post-tool use checks**, create these two objects. If it does not, keep the same logic in the custom agent instructions and run all SQL fix scenarios in Review mode.

Create `sql-write-guard`:

- Source: `sre-config/agent1/hooks/sql-write-guard.yaml`
- Event: `PostToolUse`
- Activation: always
- Type: command
- Matcher: `.*sql.*|.*SQL.*|.*mssql.*`
- Timeout: `30`
- Fail mode: allow
- Script: copy the Python script from the YAML.

Create `change-risk-assessor`:

- Source: `sre-config/agent1/hooks/change-risk-assessor.yaml`
- Event: `PostToolUse`
- Activation: always
- Type: prompt
- Matcher: `.*create_index.*|.*update_data.*|.*delete_data.*|.*insert_data.*`
- Model: `ReasoningFast`
- Timeout: `30`
- Prompt: copy the prompt from the YAML.

### 9. Create Custom Agent: SQL Performance Investigator

1. Go to **Builder** > **Agent Canvas** > **Create** > **Custom Agent**.
2. Name: `sql-performance-investigator`.
3. Instructions: copy `spec.instructions` from `sre-config/agent1/agents/sql-performance-investigator/sql-performance-investigator.yaml`.
4. Enable skills.
5. Add skills:
   - `sql-query-diagnosis`
   - `sql-performance-fix`
   - `sql-blocking-diagnosis`
   - `sql-blocking-fix`
6. Add tools:
   - `PlotPieChart`
   - `PlotBarChart`
   - `PlotScatter`
   - `AssessChangeRisk`
   - `AskUserQuestion` if shown in built-in tools
   - All `zava-mssql` SQL MCP tools used by the skills
7. Mode: use **Review** for response plans that can run CREATE INDEX or KILL.
8. Save and test in the playground with:

```text
Use sql-query-diagnosis to inspect the Products table schema and current indexes. Do not make changes.
```

### 10. Create Custom Agent: Deployment Validator

1. Go to **Builder** > **Agent Canvas** > **Create** > **Custom Agent**.
2. Name: `deployment-validator`.
3. Instructions: copy `spec.instructions` from `sre-config/agent1/agents/deployment-validator/deployment-validator.yaml`.
4. Add tools:
   - GitHub MCP tools from `github-mcp`
   - Azure CLI, ARM, Azure Resource Graph, Azure Monitor, and Application Insights tools if the portal exposes them
5. Save and test with:

```text
Validate https://app-zava77ac.azurewebsites.net/health and summarize whether the deployment is healthy.
```

The repo also contains `deployment-validator-gh`. Use that variant only if you want a GitHub Actions specific agent. The repo currently does not contain `.github/workflows/deploy.yml`, so the simplest live demo path is manual trigger or simulator Scenario 3.

### 11. Create Alert Response Plans

Go to **Incident Response**, **Alert Handlers**, or **Response Plans**.

Create these mappings:

- Alert: `alert-zava77ac-dtu-high`
  - Target custom agent: `sql-performance-investigator`
  - Mode: Review
  - Prompt: `Investigate the DTU spike on sqldb-zava77ac. Start with diagnosis only. If a missing index or blocking chain is found, present risk and ask for approval before any fix.`

- Alert: `alert-zava77ac-http-5xx`
  - Target custom agent: `deployment-validator`
  - Mode: Review
  - Prompt: `Investigate HTTP 5xx errors for app-zava77ac. Check health, App Insights errors, recent deployment context, and recommend or perform approved recovery.`

- Alert: `alert-zava77ac-health-check`
  - Target custom agent: `deployment-validator`
  - Mode: Review
  - Prompt: `Investigate health check failures for app-zava77ac. Verify /health, check app configuration, and recommend or perform approved recovery.`

### 12. Create HTTP Trigger For Deployment Validation

1. Go to **Triggers** > **Create HTTP trigger**.
2. Name: `deployment-validator-http`.
3. Target custom agent: `deployment-validator`.
4. Mode: Review.
5. Save the generated trigger URL somewhere secure.
6. Test with a payload like:

```json
{
  "repo": "meetshamir/AzureFriday-SREAgent",
  "branch": "main",
  "commit_sha": "manual-demo",
  "app_url": "https://app-zava77ac.azurewebsites.net",
  "health_endpoint": "https://app-zava77ac.azurewebsites.net/health",
  "workflow_run_url": "manual portal test"
}
```

### 13. Create Weekly Cost Scheduled Task

1. Go to **Scheduled tasks** > **Create**.
2. Name: `weekly-cost-report`.
3. Cron: `0 9 * * 1`.
4. Target agent: use the main Agent 1 or a cost-report custom agent if you create one.
5. Prompt:

```text
Analyze Azure costs for the Zava resource group (rg-zava77ac) over the past 7 days. Break down costs by resource type. Identify top 3 cost drivers. Flag anomalies. Provide 3 recommendations to reduce costs. Format as a management report with Executive Summary, Cost Breakdown, Anomalies, Recommendations.
```

## Agent 2: IT Support And ServiceNow

Agent 2 handles ServiceNow incident lookup, warranty validation, IT portal laptop request submission, ticket updates, and optional employee email.

### Agent 2 Step 1: Create The SRE Agent Resource

1. Open `https://sre.azure.com`.
2. Select **Create Agent**.
3. Use these values:
   - Name: `zava-sreagent-2`
   - Subscription: `ME-MngEnvMCAP352465-sithukyaw-2`
   - Resource group: create/use an SRE-agent resource group, or use `rg-zava77ac` for the demo.
   - Region/model provider: choose any available portal combination.
4. Create the agent and wait for provisioning to succeed.

### Agent 2 Step 2: Add Azure Resource Access

1. Add resource group `rg-zava77ac`.
2. Reader permission is enough for most Agent 2 demo steps.
3. Contributor is only needed if you want Agent 2 to modify Azure resources, which this demo does not require.

### 3. Configure ServiceNow Access

Use whichever ServiceNow path your portal build exposes.

Option A: Native ServiceNow connector/tools

1. Go to **Builder** > **Connectors** or **Tools**.
2. Add ServiceNow.
3. Enter your PDI URL, username, and password or OAuth details.
4. Confirm these tools are available:
   - `GetServiceNowIncident`
   - `PostServiceNowDiscussionEntry`
   - `AcknowledgeServiceNowIncident`
   - `ResolveServiceNowIncident`

Option B: Custom tools only

Use `LookupServiceNowIncident` to fetch the incident by number, then use manual ticket update as a fallback if native update/resolve tools are unavailable.

### 4. Create Custom Tool: CheckWarranty

1. Go to **Builder** > **Tools** > **Create tool**.
2. Type: Python tool.
3. Name: `CheckWarranty`.
4. Description and code: copy from `sre-config/agent2/tools/CheckWarranty/CheckWarranty.yaml`.
5. Dependency: `requests`.
6. Environment variable if supported:

```text
WARRANTY_API_URL=https://app-zava77ac-warranty.azurewebsites.net
```

1. Parameter:
   - `serial_number`, string, required
2. Test with:

```text
serial_number=SN-2021-DEL-3344
```

Expected result: expired warranty and replacement eligibility.

### 5. Create Custom Tool: LookupServiceNowIncident

1. Go to **Builder** > **Tools** > **Create tool**.
2. Type: Python tool.
3. Name: `LookupServiceNowIncident`.
4. Description and code: copy from `sre-config/agent2/tools/LookupServiceNowIncident/LookupServiceNowIncident.yaml`.
5. Dependency: `requests`.
6. Environment variables or secret settings:

```text
SERVICENOW_URL=https://<instance>.service-now.com
SERVICENOW_USER=admin
SERVICENOW_PASS=<servicenow-password>
```

1. Parameter:
   - `incident_number`, string, required
2. Test with a real incident number from your PDI, for example `INC0010005`.

### 6. Configure Email And Browser Tools

1. Add or enable `SendOutlookEmail` if the portal exposes it.
2. Complete Microsoft 365 consent if required.
3. Add or enable Browser Operator if your portal build exposes it.

If Browser Operator is unavailable, keep the demo focused on incident lookup, warranty lookup, and ServiceNow update. You can manually show the IT portal form at `https://app-zava77ac-itportal.azurewebsites.net`.

### 7. Create Custom Agent: IT Support Handler

1. Go to **Builder** > **Agent Canvas** > **Create** > **Custom Agent**.
2. Name: `it-support-handler`.
3. Instructions: copy `spec.instructions` from `sre-config/agent2/agents/it-support-handler/it-support-handler.yaml`.
4. Add tools:
   - `CheckWarranty`
   - `LookupServiceNowIncident`
   - `GetServiceNowIncident` if available
   - `PostServiceNowDiscussionEntry` if available
   - `AcknowledgeServiceNowIncident` if available
   - `ResolveServiceNowIncident` if available
   - `SendOutlookEmail` if available
   - Browser Operator if available
5. Mode: Review for first rehearsal; Autonomous only after every tool is tested.
6. Save and test with:

```text
Use CheckWarranty for serial number SN-2021-DEL-3344 and summarize whether a laptop replacement is eligible.
```

### 8. Optional Incident Trigger

If your portal exposes ServiceNow incident platforms or HTTP triggers:

1. Create a trigger named `servicenow-laptop-request`.
2. Target custom agent: `it-support-handler`.
3. Mode: Review.
4. Trigger payload should include at least:

```json
{
  "incident_number": "INC0010005",
  "serial_number": "SN-2021-DEL-3344"
}
```

For the first demo, manual chat invocation is simpler and safer:

```text
/agent it-support-handler Handle ServiceNow incident INC0010005. Validate warranty before submitting any laptop replacement request.
```

## Rehearsal Checklist

### Agent 1

1. SQL MCP test succeeds with `SELECT 1`.
2. `sql-query-diagnosis` can inspect the `Products` table.
3. `AssessChangeRisk` returns approval-required output for a CREATE INDEX on `Products`.
4. Alert handler for `alert-zava77ac-dtu-high` targets `sql-performance-investigator`.
5. Run `python simulator/demo.py 1` and watch for diagnosis, approval, and index creation.

### Agent 2

1. `CheckWarranty` returns expired warranty for `SN-2021-DEL-3344`.
2. `LookupServiceNowIncident` can fetch a real PDI incident.
3. Native ServiceNow update/resolve tools work, or manual ticket update fallback is ready.
4. IT portal is reachable at `https://app-zava77ac-itportal.azurewebsites.net`.
5. Run `python simulator/demo.py 4` only after ServiceNow credentials and tools are verified.

## Troubleshooting

- If SQL tool names do not match `zava-mssql_*`, rename the MCP connector to `zava-mssql` or update the skill tool names.
- If GitHub MCP tools do not show up, check PAT scope and connector health.
- If Python tool dependencies fail, confirm the tool runtime supports installing `requests`.
- If SQL write actions feel too risky during the live demo, keep response plans in Review mode and approve only `CREATE INDEX IX_Products_Category ON Products(Category)`.
- If Agent 2 cannot use Browser Operator, narrate the form submission and let the agent complete warranty lookup plus ServiceNow update.
