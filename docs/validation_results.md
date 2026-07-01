# Validation Results

> **Execution status: `Pending Manual Snowflake Execution`.**
>
> **Manual Snowflake execution is required. Validation scripts have been prepared but not
> executed in this environment.** No result below is real yet — every value is a labelled
> **placeholder** to be filled in after you run the platform. Nothing here is claimed as passed.

**How to use this file:** run the platform per
[`manual_snowflake_test_plan.md`](manual_snowflake_test_plan.md), then replace each
`_pending_` / `<fill>` placeholder with the actual result, set the execution date, and commit.

- **Execution date:** `<YYYY-MM-DD — not yet executed>`
- **Snowflake edition / region:** `<fill>`
- **Executed by:** `<fill>`
- **Warehouse(s) used:** `WH_INGESTION`, `WH_TRANSFORM`, `WH_REPORTING`

---

## 1. Deployment execution log

| Step | Script(s) | Status | Rows / notes |
|---|---|---|---|
| Setup | `00_setup/01–03` | _pending_ | |
| Ingestion + data gen | `01_ingestion/01–03, 05` | _pending_ | RAW row counts: `<fill>` |
| Staging | `02_staging/01–02` | _pending_ | invalid rows should be 0 |
| Core model | `03_core_model/01–04` | _pending_ | dims + facts loaded |
| Governance (optional) | `00_setup/04` | _pending_ | demo pattern |
| AML rules | `04_aml_rules/01–03` | _pending_ | alerts generated |
| STR workflow | `05_str_workflow/01–02` | _pending_ | cases generated |
| Reporting views | `06_reporting/01–05` | _pending_ | 11 views compiled |
| Validation | `07_data_quality/00–04` | _pending_ | see §3 |

Status values: `PASS` / `FAIL` / `PARTIAL` / `_pending_`.

## 2. Smoke-test results

| # | Check | Query target | Expected | Actual | Status |
|---|---|---|---|---|---|
| 1 | Transaction count | `CORE.FACT_TRANSACTIONS` | ~5,300 | `<fill>` | _pending_ |
| 2 | Market month count | `CORE.FACT_MARKET_PERFORMANCE` | 36 | `<fill>` | _pending_ |
| 3 | AML alert count | `CORE.FACT_AML_ALERTS` | > 0 | `<fill>` | _pending_ |
| 4 | Alert typologies firing | `COUNT(DISTINCT ALERT_TYPE_KEY)` | up to 11 | `<fill>` | _pending_ |
| 5 | STR case count | `CORE.FACT_STR_CASES` | > 0 | `<fill>` | _pending_ |
| 6 | Typology view rows | `REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN` | 11 | `<fill>` | _pending_ |
| 7 | Executive overview | `REPORTING.VW_EXECUTIVE_OVERVIEW` | 1 row | `<fill>` | _pending_ |
| 8 | AML monitoring summary | `REPORTING.VW_AML_MONITORING_SUMMARY` | 1 row | `<fill>` | _pending_ |
| 9 | STR workflow summary | `REPORTING.VW_STR_WORKFLOW_SUMMARY` | 1 row | `<fill>` | _pending_ |
| 10 | Market performance | `REPORTING.VW_MARKET_PERFORMANCE` | 36 rows | `<fill>` | _pending_ |

## 3. Validation-script results

Record the `STATUS` column output from each script.

### `03_phase_validation_queries.sql` (per-phase gates 4–10)
| Phase gate | Status | Note |
|---|---|---|
| Phase 4 setup | _pending_ | |
| Phase 5 ingestion | _pending_ | |
| Phase 6 staging | _pending_ | |
| Phase 7 core | _pending_ | |
| Phase 8 AML | _pending_ | |
| Phase 9 STR | _pending_ | |
| Phase 10 reporting | _pending_ | |

### `01_data_quality_checks.sql`
| Check group | Status | Note |
|---|---|---|
| Duplicate IDs (txn/alert/case) | _pending_ | `FAIL` = grain broke |
| Null critical keys | _pending_ | |
| Invalid/orphan dates | _pending_ | |
| Negative amounts | _pending_ | `REVIEW` expected |
| Orphan alerts/cases | _pending_ | |
| SLA logic consistency | _pending_ | |

### `02_reconciliation_queries.sql` (R1–R8)
| Recon | Status | Note |
|---|---|---|
| R1 RAW→STAGING counts | _pending_ | |
| R2 STAGING→CORE counts | _pending_ | |
| R3 value reconciliation | _pending_ | |
| R4 AML view vs fact | _pending_ | |
| R5 STR view vs fact | _pending_ | |
| R6–R8 reporting reconcile | _pending_ | |

### `04_post_phase10_reporting_validation.sql` (P1–P6)
| Check | Status | Note |
|---|---|---|
| P1 views exist (11) | _pending_ | |
| P2 rows returned | _pending_ | |
| P3 no inflation | _pending_ | |
| P4 reconciliation | _pending_ | |
| P5 BI readiness | _pending_ | |
| P6 (as defined in script) | _pending_ | |

## 4. Issues found & fixes applied

| Issue | Script/layer | Fix | Re-run status |
|---|---|---|---|
| _(none recorded yet — populate during execution)_ | | | |

## 5. Final verdict

- **Overall:** `_pending manual execution_`
- **Evidence:** see [`screenshot_capture_guide.md`](screenshot_capture_guide.md); store images under `docs/evidence/`.
- Once complete, update the README **Execution Evidence** and **Validation and Execution
  Status** sections with the execution date and a link to this file.

---

_This file intentionally contains no fabricated results. Placeholders remain until a real run
populates them._
