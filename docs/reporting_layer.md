# Reporting Layer (Phase 10)

> The BI-ready semantic layer: business-named `REPORTING.VW_*` views over CORE that feed the
> Power BI dashboards. Implemented in `snowflake/06_reporting/01–05`. Synthetic data only.

## Purpose

Power BI (and analysts) read **only** the `REPORTING` schema — never RAW/STAGING/CORE. Views
give stable, business-friendly column names and pre-computed metrics, so the dashboard layer
stays simple and the physical model can evolve underneath.

## Views by dashboard page

| Dashboard page | Views | Key metrics |
|---|---|---|
| **Executive Overview** | `VW_EXECUTIVE_OVERVIEW`, `VW_MONTHLY_COMPLIANCE_TRENDS` | total transactions & value, total GGR, active accounts, GGR/active, AML alerts, escalation rate, STR cases, STRs submitted, STR conversion, SLA compliance, avg investigation days |
| **AML Monitoring** | `VW_AML_MONITORING_SUMMARY`, `VW_ALERT_TYPOLOGY_BREAKDOWN` | alerts by typology/severity/score, escalation rate, avg risk score, high-risk accounts, sanctions hits, rules firing |
| **STR Workflow** | `VW_STR_WORKFLOW_SUMMARY`, `VW_SLA_PERFORMANCE`, `VW_ANALYST_WORKLOAD`, `VW_STR_STATUS_FUNNEL` | open backlog, STRs filed, STR conversion, SLA compliance, avg investigation days, aging buckets, per-analyst load, status funnel |
| **Market / GGR** | `VW_MARKET_PERFORMANCE`, `VW_MARKET_FISCAL_YEAR` | monthly wagers, GGR, hold %, active accounts, GGR/active, MoM growth, fiscal-year rollup + YoY |
| **Player Risk** | `VW_PLAYER_RISK_PROFILE` | KYC status/risk, PEP/watchlist, txn count & value, alert & escalated counts, max risk score, last alert date, case & STR counts, composite risk band |

## Design conventions

- **Business-readable names** (`ESCALATION_RATE_PCT`, `TOTAL_TRANSACTION_VALUE`,
  `SLA_COMPLIANCE_PCT`), avoiding raw key/technical names in the output.
- **Stable columns** so Power BI relationships/measures don't break on refactors.
- **Percentages and ratios pre-computed** with `NULLIF(...)` divide-by-zero guards.
- **CTEs** stage each metric domain before the final select.

## Grain Management and Reporting Safety

This is the single most important correctness rule in the reporting layer.

**The problem.** The facts live at different grains: `FACT_TRANSACTIONS` is *per transaction*,
`FACT_AML_ALERTS` is *per (transaction × rule)*, `FACT_STR_CASES` is *per case*, and
`FACT_MARKET_PERFORMANCE` is *per month*. Joining two different grains directly (e.g. monthly
market GGR to per-transaction rows) **fans out** and inflates values — a monthly GGR figure
would be repeated once per transaction in that month.

**The rules applied here:**
1. **Never join market/GGR to transaction/alert/case facts.** Market views read **only**
   `FACT_MARKET_PERFORMANCE` + `DIM_DATE`. (Verified: the market view file references no other
   fact.)
2. **Aggregate each domain to a single row before combining.** `VW_EXECUTIVE_OVERVIEW`
   collapses transactions, market, AML, and STR to one row each in separate CTEs, then
   `CROSS JOIN`s the one-row results — no fan-out possible.
3. **Combine cross-domain only at an aligned grain.** `VW_MONTHLY_COMPLIANCE_TRENDS` pre-
   aggregates alerts (by alert month), cases (by open month), and market (by month) each to
   **month** grain, then joins on `YEAR_MONTH` via a month spine.
4. **Profiles pre-aggregate to their key.** `VW_PLAYER_RISK_PROFILE` aggregates transactions,
   alerts, and cases to **player** grain in CTEs before left-joining `DIM_PLAYER` — so one row
   per player, no multiplication.
5. **Player-risk grain is explicit:** one row per player (`DIM_PLAYER` is the driving table).

**Result:** AML, STR, and market metrics stay logically separate; the only cross-domain
blending happens on pre-aggregated, grain-aligned results.

## Portfolio-safe simulation notes

- All figures derive from **synthetic** data; nothing represents a real market or customer.
- Some dimension attributes (KYC/risk) are deterministically synthesized (see `data_model.md`).
- In a real regulated environment these views would add: row-level security by team/region,
  certified metric definitions, and reconciliation to source-of-truth financial systems.
