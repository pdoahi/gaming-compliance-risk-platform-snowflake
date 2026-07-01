# Phase 10 — Reporting Views: Learning Notes

> What I practiced building the reporting layer, and why it's designed this way. Part of the
> "make the Snowflake learning visible" thread. Synthetic data only.

## Snowflake / SQL concepts used in Phase 10

- **Views (`CREATE OR REPLACE VIEW`)** as a serving layer — logic lives in the warehouse, not
  in Power BI.
- **CTEs** to stage each metric domain (transactions, market, AML, STR) before combining.
- **Aggregations** (`COUNT`, `SUM`, `AVG`, `MAX`) with `ROUND` and `NULLIF` divide-by-zero
  guards for clean percentages/ratios.
- **`IFF` / `CASE`** for conditional counts (e.g. `SUM(IFF(IS_ESCALATED,1,0))`) and the player
  composite risk band.
- **Window function** (`LAG`) for fiscal-year YoY growth.
- **`CROSS JOIN` of one-row CTEs** to assemble a single-row KPI view safely.
- **A month "spine"** (`UNION` of distinct months) so a trend line covers months present in
  one fact but not another.

## Why reporting views matter in a warehouse

They form the **semantic layer**: the contract between the data warehouse and BI. Benefits:
- BI tools bind to **stable, business-named columns**, insulated from physical refactors.
- Metric definitions are **centralized and consistent** (one definition of "SLA compliance"),
  instead of each dashboard re-deriving them differently.
- Security is simpler — BI reads only `REPORTING`, never the raw/core tables.

## How CTEs and aggregations were used

Each view aggregates its domain(s) first, then selects. Example (`VW_EXECUTIVE_OVERVIEW`):
one CTE each for transactions / market / AML / STR — every CTE returns exactly one row — then a
`CROSS JOIN` produces the single KPI row. Because each CTE is already collapsed, there is no way
for the join to multiply rows.

## How grain duplication was avoided

The core discipline (full detail in [`reporting_layer.md`](reporting_layer.md) →
*Grain Management and Reporting Safety*):
- **Market/GGR is never joined to transaction/alert/case facts** — market views read only the
  monthly market fact + date.
- **Cross-domain metrics are combined only after pre-aggregating** each domain to a single row
  (executive) or to a shared grain like **month** (trends) or **player** (risk profile).

## How AML, STR, and market metrics stay logically separate

Separate view files per domain (`02_aml`, `03_str`, `04_market`, `05_player_risk`), each
reading its own fact at its own grain. The only place they meet is the executive one-row
summary and the monthly trend — both on pre-aggregated, grain-aligned results.

## Portfolio-safe simulations vs. real-world gaps

| In this project (portfolio-safe) | In a real regulated environment |
|---|---|
| Synthetic data; deterministic KYC/risk attributes | Governed customer/KYC master; certified sources |
| Views open to reporting roles | Row-level security by team/region; masking of identifiers |
| Metrics defined in views | Certified/governed metric catalog + reconciliation to finance |
| Refresh on demand | Scheduled Tasks/Streams incremental refresh (Phase 13) |

## What I'd improve next

Add a product-mix market fact in CORE (currently staging-only), and back the trend/exec views
with materialized aggregates or Dynamic Tables if refresh cost grew.
