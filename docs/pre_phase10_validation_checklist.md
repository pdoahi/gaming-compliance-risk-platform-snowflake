# Pre-Phase-10 Validation Checklist

> A structured checkpoint confirming Phases 1–9 produced a model the Phase 10 reporting
> views can safely sit on. The runnable checks are in
> [`snowflake/07_data_quality/00_pre_phase10_validation_checks.sql`](../snowflake/07_data_quality/00_pre_phase10_validation_checks.sql).
> All data is **synthetic**.

## How to read this

Each SQL check returns `CHECK_NAME`, `STATUS` (`PASS` / `FAIL` / `REVIEW`), and a `DETAIL`
value. Run the whole script in a Snowflake worksheet (role `DATA_ENGINEER`, warehouse
`WH_TRANSFORM`) after the synthetic data is loaded, and scan the `STATUS` column.

## Manual Test Execution Required

These validation queries were **created but not executed** — this project is authored against
Snowflake syntax but has **no live Snowflake connection in this environment**. Do **not**
assume any check has passed. To validate:

1. Run Phases 1–9 in your Snowflake account (generate + `PUT` synthetic data, then run
   `00_setup` → `05_str_workflow` in order).
2. Run `00_pre_phase10_validation_checks.sql`.
3. Record the `STATUS` column results in
   [`pre_phase10_validation_results.md`](pre_phase10_validation_results.md).

## The checks

### A. Repository / object readiness
| Check | Verifies | Passing | A failure means | Mode |
|---|---|---|---|---|
| A1 | 7 schemas exist | `PASS` (count = 7) | setup 02 not run | Auto |
| A2 | 6 dimensions exist | `PASS` (count = 6) | core 01 not run | Auto |
| A3 | 4 fact tables exist | `PASS` (count = 4) | core 02 not run | Auto |
| A4 | RAW/STAGING tables exist | `PASS` (≥5) | ingestion/staging not run | Auto |

### B. Core data-model (row presence)
| Check | Verifies | Passing | A failure means | Mode |
|---|---|---|---|---|
| B1–B5 | dims/facts have rows | `PASS` (>0) | loads didn't run / no source data | Auto |
| B6 | `DIM_ALERT_TYPE` seeded 11 | `PASS` (=11) | AML seed not run | Auto |
| B7 | `DIM_STATUS` seeded 5 | `PASS` (=5) | dimension load not run | Auto |
| B8 | STR cases exist iff escalated alerts exist | `PASS` | STR generation didn't run | Auto |

### C. Relationships (orphans → 0)
Transactions→player/account, alerts→transaction/player/type, cases→alert/player/analyst/status.
**Passing = 0 orphans.** A non-zero count means a surrogate-key lookup failed in a load step —
this is a **blocking** issue for reporting (joins would drop or mislabel rows).

### D. Business logic
Alerts have a type, a risk score, and an escalation flag; cases have SLA target, investigation
days, breach flag, and STR-submitted flag; **D8** confirms cases were created **only** from
escalated alerts. **Passing = 0 bad rows.** Failures here directly break the AML/STR summary
views (missing scores/statuses → null KPIs).

### E. Grain & reconciliation
No duplicate transaction/alert/case IDs (E1–E3); market fact is one row per month (E4);
transaction counts reconcile RAW → valid-STAGING → CORE (E5). **Passing:** 0 dupes; rows =
distinct months; counts align (E5 is `REVIEW` — small differences are expected if staging
flagged invalid rows). Duplicates would **inflate** every reporting metric.

### F. Data quality
No null critical IDs (F1–F2), no negative amounts (F3, `REVIEW`), valid date keys (F4), no
cases without alerts (F5) or alerts without transactions (F6), and no gaps in market months
(F7). **Passing = 0** (F3/F7 are `REVIEW` — flag for a human, not necessarily a defect).

## Interpreting results
- **All `PASS`** → the model is reporting-ready; proceed to build/trust Phase 10 views.
- **Any `FAIL` in C or D** → **blocking**; fix the referenced load step before reporting.
- **`REVIEW`** → inspect the `DETAIL`; document if it is an intentional synthetic-data quirk.
