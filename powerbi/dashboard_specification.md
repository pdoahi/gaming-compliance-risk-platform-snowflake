# Power BI Dashboard Specification

> **Phase 14 deliverable.** The dashboard pages the reporting layer supports, their metrics,
> visuals, and source views. Tool-agnostic design; the connection/model/measures live in
> [`../snowflake/10_powerbi/`](../snowflake/10_powerbi). Synthetic data only — figures are
> illustrative.

Pages map to the business workflow: **market & program health → detect (AML) → investigate
(STR) → market performance**, plus an optional player-risk view.

---

## Page 1 — Executive Overview
**Audience:** Chief Compliance Officer, leadership.
**Source:** `VW_EXECUTIVE_OVERVIEW`, `VW_MONTHLY_COMPLIANCE_TRENDS`.

- **KPI cards:** Total Transactions, Total Transaction Value, Total GGR, Active Accounts,
  GGR per Active, AML Alerts, Escalation Rate %, STR Cases, STRs Submitted, STR Conversion %,
  SLA Compliance %, Avg Investigation Days.
- **Charts:** GGR trend (line, monthly) · AML alerts & escalations (line/bar, monthly) ·
  STR cases vs STRs filed (monthly) · Hold % card.
- **Slicers:** Date (fiscal year, month).

## Page 2 — AML Monitoring
**Audience:** AML analysts, financial-crime lead.
**Source:** `VW_AML_MONITORING_SUMMARY`, `VW_ALERT_TYPOLOGY_BREAKDOWN`, `VW_MONTHLY_COMPLIANCE_TRENDS`.

- **KPI cards:** Total Alerts, Escalated Alerts, Escalation Rate %, Avg Risk Score,
  Critical Alerts, Sanctions Hits, High-Risk Accounts.
- **Charts:** Alerts by rule/typology (bar) · Alerts by month with escalated overlay (line) ·
  Alerts by severity (stacked) · Escalated vs non-escalated (donut).
- **Slicers:** Rule, Severity, Date.

## Page 3 — STR Workflow
**Audience:** AML operations manager, MLRO.
**Source:** `VW_STR_WORKFLOW_SUMMARY`, `VW_SLA_PERFORMANCE`, `VW_ANALYST_WORKLOAD`,
`VW_STR_STATUS_FUNNEL`.

- **KPI cards:** Total Cases, Open Backlog, STRs Filed, STR Conversion %,
  SLA Compliance %, Avg Investigation Days.
- **Charts:** Case funnel (New→Closed, ordered by `WORKFLOW_ORDER`) · SLA compliance & breaches
  by priority (bar) · Open-case aging buckets (column) · Analyst workload (clustered bar:
  total / open / STRs).
- **Slicers:** Status, Priority, Analyst.

## Page 4 — Market / GGR Performance
**Audience:** Finance, strategy, executives.
**Source:** `VW_MARKET_PERFORMANCE`, `VW_MARKET_FISCAL_YEAR`.

- **KPI cards:** Total GGR, Total Wagers, Hold %, Active Accounts, GGR per Active, GGR YoY %.
- **Charts:** Wagers vs GGR over time (dual axis, monthly) · MoM GGR growth (column) ·
  Fiscal-year GGR with YoY labels (bar) · Hold % trend.
- **Slicers:** Fiscal Year, Date.
- **Grain note:** this page uses **only** the market views — never blended with
  transaction/alert/case data (grain firewall).

## Page 5 — Player Risk Profile (optional)
**Audience:** Analysts / managers doing triage.
**Source:** `VW_PLAYER_RISK_PROFILE`.

- **KPI cards:** Players, High-Risk Players, Players with Alerts, Players with STRs.
- **Table/visuals:** player list with KYC status, risk level, PEP/watchlist, txn count & value,
  alert & escalated counts, max risk score, last alert date, composite risk band · risk-band
  distribution (donut) · top players by max risk score.
- **Slicers:** KYC Risk Level, Composite Risk Band, PEP/Watchlist.

---

## Interactions & theme

- **Cross-filtering** on within each page; drill-through Executive → detail pages.
- **Severity colors:** Low `#16a34a` · Medium `#ca8a04` · High `#ea580c` · Critical `#dc2626`;
  primary `#2563eb`; neutral grays. Consistent across pages.

## Portfolio note

All figures are **synthetic**. Building the actual `.pbix` is a manual step in Power BI Desktop
(assemble from this spec + the model/measures in `../snowflake/10_powerbi/`); it is a future
enhancement for this repo.
