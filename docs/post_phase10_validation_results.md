# Post-Phase-10 Validation Results

> Outcome of validating the reporting layer. Separates **static review** (verifiable in this
> repo) from **runtime checks** (require a live Snowflake run). Synthetic data only.

## Execution status

**SQL validation scripts were created but still need to be executed manually in Snowflake.**

There is no live Snowflake connection in this environment, so **no reporting check is claimed
as passed**. The runnable checks are in
[`snowflake/07_data_quality/04_post_phase10_reporting_validation.sql`](../snowflake/07_data_quality/04_post_phase10_reporting_validation.sql)
(checks P1 → P6).

## Static review of the reporting layer (verifiable here)

| Aspect | Finding |
|---|---|
| View count | 11 `REPORTING.VW_*` views defined across `06_reporting/01–05` |
| Compilation risk | Views reference only existing CORE tables/columns; standard Snowflake SQL |
| Grain safety | KPI views use one-row CTE `CROSS JOIN`; trends use a month spine; profiles pre-aggregate to their key (no fan-out by construction) — see `reporting_layer.md` |
| Market isolation | Market views read only `FACT_MARKET_PERFORMANCE` + `DIM_DATE` (no cross-grain join) |
| Reconciliation design | P4 checks tie view totals back to `COUNT(*)`/`SUM(...)` on the facts |
| Power BI readiness | Business-named, stable columns; month/date fields present; risk bands + status groupings defined |
| Player-risk grain | One row per player (`DIM_PLAYER`-driven); asserted by P3 |

**Static conclusion:** the views are structurally sound and designed to reconcile; runtime
confirmation is pending.

## ⚠️ Manual Test Execution Required

Run in Snowflake (role `DATA_ENGINEER`, warehouse `WH_REPORTING`) after building the views:

1. `snowflake/07_data_quality/04_post_phase10_reporting_validation.sql`
2. Confirm **P1** (11 views), **P2** (rows returned), **P3** (no inflation), **P4**
   (reconciliation `PASS`), **P5** (BI readiness).
3. Record the `STATUS` results here.

Any **P3/P4 `FAIL`** indicates a grain or reconciliation problem in a view and must be fixed
before the dashboards are trusted.

## Results table (to be filled after execution)

| Check | Status | Detail |
|---|---|---|
| P1 views exist | _pending_ | |
| P2 rows returned | _pending_ | |
| P3 no inflation | _pending_ | |
| P4 reconciliation | _pending_ | |
| P5 BI readiness | _pending_ | |
