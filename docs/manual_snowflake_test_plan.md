# Manual Snowflake Test Plan

> **Execution status: `Executed 2026-07-02` (18/18 setup verification).** This runbook was used
> to run the platform in a Snowflake trial; it remains the **reusable checklist** for running it
> again in any Snowflake account. Recorded results: [`validation_results.md`](validation_results.md).
> Synthetic data only.

Pair this with the full runbook in [`deployment_guide.md`](deployment_guide.md); this document
adds the **validation focus** and **smoke-test queries**.

---

## Exact script order (existing repo files)

Run in a Snowsight worksheet, top to bottom. Each file sets its own role/warehouse/schema.

**1. Create warehouses, database, schemas, roles** *(role: `SYSADMIN` / `SECURITYADMIN`)*
```
snowflake/00_setup/01_create_warehouses.sql
snowflake/00_setup/02_create_database_schemas.sql
snowflake/00_setup/03_create_roles_grants.sql
```
Then grant the custom roles to your user: `GRANT ROLE DATA_ENGINEER TO USER <you>;` (repeat for `BI_REPORTING`).

**2. Generate / load synthetic data** *(role: `DATA_ENGINEER`, WH `WH_INGESTION`)*
```
snowflake/01_ingestion/01_create_file_formats.sql
snowflake/01_ingestion/02_create_stages.sql
snowflake/01_ingestion/03_create_raw_tables.sql
snowflake/01_ingestion/05_generate_synthetic_data.sql     -- in-DB generator (no files)
```
*(Alternative to `05`: `04_load_data_examples.sql` for file-based `COPY INTO`. Use one, not both.)*

**3. RAW → STAGING** *(WH `WH_TRANSFORM`)*
```
snowflake/02_staging/01_create_staging_tables.sql
snowflake/02_staging/02_staging_transformations.sql
```

**4. CORE model**
```
snowflake/03_core_model/01_create_dimensions.sql
snowflake/03_core_model/02_create_facts.sql
snowflake/03_core_model/03_load_dimensions.sql
snowflake/03_core_model/04_load_facts.sql
```

**5. Governance (optional, demo pattern)** *(role: `ACCOUNTADMIN`; run AFTER core model)*
```
snowflake/00_setup/04_governance_policies.sql
```

**6. AML rules**
```
snowflake/04_aml_rules/01_alert_type_seed_data.sql
snowflake/04_aml_rules/02_generate_aml_alerts.sql
snowflake/04_aml_rules/03_alert_scoring_logic.sql
```

**7. STR workflow**
```
snowflake/05_str_workflow/01_generate_str_cases.sql
snowflake/05_str_workflow/02_case_sla_logic.sql
```

**8. REPORTING views**
```
snowflake/06_reporting/01_executive_views.sql
snowflake/06_reporting/02_aml_views.sql
snowflake/06_reporting/03_str_views.sql
snowflake/06_reporting/04_market_views.sql
snowflake/06_reporting/05_player_risk_views.sql
```

**9. Validation** *(WH `WH_TRANSFORM`; reporting checks use `WH_REPORTING`)*
```
snowflake/07_data_quality/03_phase_validation_queries.sql     -- are the phases built?
snowflake/07_data_quality/00_pre_phase10_validation_checks.sql
snowflake/07_data_quality/01_data_quality_checks.sql
snowflake/07_data_quality/02_reconciliation_queries.sql
snowflake/07_data_quality/04_post_phase10_reporting_validation.sql
```

**10. Optional extras**
```
snowflake/08_automation/01_streams.sql, 02_tasks.sql   (leave the task suspended)
snowflake/09_snowpark/aml_risk_scoring_example.py       (Snowpark-enabled Python env)
snowflake/10_powerbi/                                   (connect Power BI to REPORTING)
```

---

## Smoke-test queries

Run after step 8. Fill the "Result" column in
[`validation_results.md`](validation_results.md). Expected magnitudes assume the default
generator (~5,300 transactions).

```sql
USE ROLE DATA_ENGINEER;  USE WAREHOUSE WH_REPORTING;  USE DATABASE GAMING_COMPLIANCE_DB;

-- 1. Transaction count            (expect ~5,300)
SELECT COUNT(*) AS TRANSACTIONS FROM CORE.FACT_TRANSACTIONS;

-- 2. Market month count           (expect 36)
SELECT COUNT(*) AS MARKET_MONTHS FROM CORE.FACT_MARKET_PERFORMANCE;

-- 3. AML alert count              (expect > 0, typically a few thousand)
SELECT COUNT(*) AS AML_ALERTS FROM CORE.FACT_AML_ALERTS;

-- 4. Alert typology count         (expect up to 11 distinct rules firing)
SELECT COUNT(DISTINCT ALERT_TYPE_KEY) AS TYPOLOGIES_FIRING FROM CORE.FACT_AML_ALERTS;

-- 5. STR case count               (expect > 0)
SELECT COUNT(*) AS STR_CASES FROM CORE.FACT_STR_CASES;

-- 6. Reporting view row count     (expect 11 — one row per rule)
SELECT COUNT(*) AS TYPOLOGY_ROWS FROM REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN;

-- 7. Executive overview check     (expect exactly 1 KPI row)
SELECT * FROM REPORTING.VW_EXECUTIVE_OVERVIEW;

-- 8. AML monitoring summary check (expect 1 row; ESCALATION_RATE_PCT populated)
SELECT * FROM REPORTING.VW_AML_MONITORING_SUMMARY;

-- 9. STR workflow summary check   (expect 1 row; SLA_COMPLIANCE_PCT populated)
SELECT * FROM REPORTING.VW_STR_WORKFLOW_SUMMARY;

-- 10. Market performance check    (expect 36 monthly rows; HOLD_PCT ~7–8%)
SELECT * FROM REPORTING.VW_MARKET_PERFORMANCE ORDER BY YEAR_MONTH;
```

---

## What to do with the output

- Every validation script returns a `STATUS` column (`PASS` / `FAIL` / `REVIEW`). Investigate
  every `FAIL`; eyeball every `REVIEW`.
- Record actual numbers/statuses in [`validation_results.md`](validation_results.md) and tick
  [`execution_proof_checklist.md`](execution_proof_checklist.md).
- If something fails, note the error and fix, then re-run from the affected layer down.
- **Do not** mark anything "passed" until you have actually run it.
