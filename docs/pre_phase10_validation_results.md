# Pre-Phase-10 Validation Results

> Outcome of the pre-Phase-10 checkpoint and any fixes applied. Distinguishes **static
> review** (what can be verified by reading the SQL/model in this repo) from **runtime
> checks** (which require a live Snowflake run). Synthetic data only.

## Execution status

- **Static structural review:** performed in this repo (files, object definitions, keys,
  grains, view dependencies).
- **Runtime data checks (A–F in `00_pre_phase10_validation_checks.sql`):** **NOT executed**
  — no live Snowflake connection in this environment. See *Manual Test Execution Required*.

> **No check is claimed as passed.** The SQL exists and is ready to run; the data-level
> results must be produced by you in Snowflake.

## Static review findings (Phases 1–9)

| Area | Finding |
|---|---|
| Schemas / warehouses / roles | All defined (`00_setup/01–03`); 7 schemas, 4 warehouses, 6 roles present in DDL |
| Ingestion / staging | RAW landing + typed STAGING with DQ flags and traceability defined |
| Dimensions & facts | 6 dims + 4 facts defined with surrogate keys, FK constraints, audit columns |
| Business flow | `Player/Account → Transaction → AML Alert → STR Case → Reporting` preserved via surrogate FKs (alert→transaction, case→alert) |
| Market grain firewall | `FACT_MARKET_PERFORMANCE` has a single FK (`DIM_DATE`); market views read only the market fact + date |
| AML / STR logic | 11 typologies → `FACT_AML_ALERTS`; escalated alerts → `FACT_STR_CASES` with SLA fields |

**Static conclusion:** the model structurally supports the Phase 10 reporting views. No
blocking structural defect was found.

## Issue categorization

| Issue | Category | Action |
|---|---|---|
| Executive view lacked *total transactions* / *total transaction value* / GGR-per-active / STR conversion / avg investigation days | Non-Blocking (Phase 10 completeness) | **Fixed** — added a `txn` CTE + extra metrics in `VW_EXECUTIVE_OVERVIEW` |
| Player-risk view lacked *last alert date* | Non-Blocking (Phase 10 completeness) | **Fixed** — added `LAST_ALERT_DATE` to `VW_PLAYER_RISK_PROFILE` |
| Product/category market breakdown not in CORE (staging only) | Documentation | Documented in `reporting_layer.md`; monthly + fiscal-year market views cover the required page |
| SCD Type 2 for KYC/risk history; Streams/Tasks; Snowpark | Future Enhancement | Tracked for later phases; does not block Phase 10 |

**Blocking issues found: none.** The two fixes are reporting-layer enhancements (Phase 10
scope), not corrections to earlier phases — no earlier phase was rebuilt.

## Manual Test Execution Required

Run these in Snowflake and paste the `STATUS` column back here:

- `snowflake/07_data_quality/00_pre_phase10_validation_checks.sql` (checks A1 → F7)

Focus on: **C (relationships)** and **D (business logic)** — any `FAIL` there is blocking for
reporting and should be fixed before relying on the Phase 10 views. `REVIEW` rows (E5, F3, F7)
should be eyeballed and documented if they reflect intentional synthetic-data behavior.
