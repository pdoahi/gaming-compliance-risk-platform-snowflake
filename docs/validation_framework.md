# Validation Framework

> **Phase 11 deliverable.** How data quality and reconciliation are verified across the whole
> platform — ingestion → staging → core → AML → STR → reporting. Scripts live in
> [`snowflake/07_data_quality/`](../snowflake/07_data_quality). Synthetic data only.

## The scripts

| Script | Purpose | Layers covered |
|---|---|---|
| `00_pre_phase10_validation_checks.sql` | Readiness gate before trusting reporting (Phase-10 checkpoint) | object readiness, core, relationships, business logic, grain, DQ |
| **`01_data_quality_checks.sql`** | Standing DQ suite (reusable) | STAGING, CORE, AML, STR, MARKET, REPORTING |
| **`02_reconciliation_queries.sql`** | Row-count + value reconciliation across layers | RAW→STAGING→CORE→AML→STR→REPORTING |
| **`03_phase_validation_queries.sql`** | One readiness gate per phase (4–10) | all phases |
| `04_post_phase10_reporting_validation.sql` | Reporting-view compile / rows / no-inflation / reconcile | REPORTING vs CORE |

`01–03` (bold) are the canonical Phase 11 framework; `00`/`04` are the Phase-10 checkpoint
scripts and remain useful as targeted gates.

## What each check proves (and what a failure means)

Every check returns `STATUS` = `PASS` / `FAIL` / `REVIEW`.

- **Duplicate IDs** (transaction/alert/case) → `FAIL` means grain broke; metrics would inflate.
- **Null critical IDs / keys** → `FAIL` means a load step lost a key; joins would drop rows.
- **Invalid dates** (orphan `DATE_KEY`) → `FAIL` means the calendar doesn't cover the data;
  trends break.
- **Negative amounts** → `REVIEW` (flag for a human; not necessarily a defect on synthetic data).
- **Missing account relationships / orphans** (alerts without transactions, cases without
  alerts) → `FAIL`; the compliance lineage is broken.
- **Market months missing** → `REVIEW`; a gap in the monthly series affects trend continuity.
- **Invalid case durations** (`< 0` or close-before-open) → `FAIL`; SLA math is wrong.
- **SLA logic validation** (`SLA_BREACHED = (INVESTIGATION_DAYS > SLA_DAYS)`) → `FAIL` means the
  breach flag is inconsistent with the dates.
- **Row-count reconciliation** → `PASS` when counts flow through layers as expected
  (STG-valid = CORE); `REVIEW` when they differ by the number of DQ-flagged rows (expected).

## Coverage

| Layer | Covered by |
|---|---|
| Ingestion (RAW) | `02` (R1/R2 counts), `03` (Phase 5 gate) |
| Staging | `01` (invalid-row + issue breakdown), `02` (STG-valid vs CORE) |
| Core | `01` (dupes/keys/amounts/dates), `03` (Phase 7 gate) |
| AML | `01` (alert integrity), `02` (R4/R7), `03` (Phase 8 gate) |
| STR | `01` (case integrity + SLA logic), `02` (R5/R7), `03` (Phase 9 gate) |
| Reporting | `01` (view presence), `02` (R4–R8 reconcile), `04` (P1–P6) |

## How to run

1. In a Snowflake worksheet, role `DATA_ENGINEER`, warehouse `WH_TRANSFORM` (reporting checks
   use `WH_REPORTING`).
2. Run `03_phase_validation_queries.sql` first (are the phases even built?).
3. Then `01_data_quality_checks.sql` and `02_reconciliation_queries.sql`.
4. Scan the `STATUS` column; investigate every `FAIL`, eyeball every `REVIEW`.

## Manual Test Execution Required

These scripts are authored to Snowflake syntax but **not executed** in this repo (no live
connection). Do **not** treat any check as passed until you run them against your account with
the synthetic data loaded. Record outcomes alongside the Phase-10 results docs.

## Real-world extension

A production programme would add: automated scheduling (Tasks) of these checks, alerting on
`FAIL`, a persisted `UTILITY.DQ_RESULTS` history table, and certified thresholds per check.
