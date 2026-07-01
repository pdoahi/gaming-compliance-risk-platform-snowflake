# Execution Proof Checklist

> **Status: `Pending Manual Snowflake Execution`.** This is the tick-box record that turns the
> repo from a *documented implementation* into a *proven* one. Nothing is checked yet — check
> each box only after you have actually done it in Snowflake. Do not pre-tick.

Legend: `[ ]` not done · `[~]` in progress · `[x]` done (with evidence).

## A. Environment
- [ ] Snowflake trial/account opened; Snowsight worksheet created
- [ ] Active role and warehouse confirmed (`SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE();`)
- [ ] Custom roles granted to my user (`DATA_ENGINEER`, `BI_REPORTING`)

## B. Build (in order — see manual_snowflake_test_plan.md)
- [ ] `00_setup/01–03` warehouses, DB, schemas, roles
- [ ] `01_ingestion/01–03` formats, stage, RAW tables
- [ ] `01_ingestion/05` synthetic data generated (RAW populated)
- [ ] `02_staging/01–02` staging built; invalid rows = 0
- [ ] `03_core_model/01–04` dims + facts loaded
- [ ] `00_setup/04` governance policies applied (optional, after core)
- [ ] `04_aml_rules/01–03` alerts generated + scored
- [ ] `05_str_workflow/01–02` STR cases + SLA
- [ ] `06_reporting/01–05` 11 reporting views compiled

## C. Smoke tests (record numbers in validation_results.md)
- [ ] Transaction count returned (~5,300)
- [ ] Market month count = 36
- [ ] AML alert count > 0
- [ ] Distinct alert typologies firing (up to 11)
- [ ] STR case count > 0
- [ ] `VW_ALERT_TYPOLOGY_BREAKDOWN` returns 11 rows
- [ ] `VW_EXECUTIVE_OVERVIEW` returns 1 row
- [ ] `VW_AML_MONITORING_SUMMARY` returns 1 row
- [ ] `VW_STR_WORKFLOW_SUMMARY` returns 1 row
- [ ] `VW_MARKET_PERFORMANCE` returns 36 rows

## D. Validation scripts (record STATUS in validation_results.md)
- [ ] `07_data_quality/03_phase_validation_queries.sql` — all phase gates reviewed
- [ ] `07_data_quality/01_data_quality_checks.sql` — no unexpected `FAIL`
- [ ] `07_data_quality/02_reconciliation_queries.sql` — R1–R8 reconcile
- [ ] `07_data_quality/00_pre_phase10_validation_checks.sql`
- [ ] `07_data_quality/04_post_phase10_reporting_validation.sql` — P1–P6

## E. Optional extras
- [ ] `08_automation/01–02` stream + (suspended) task created
- [ ] `09_snowpark/aml_risk_scoring_example.py` run in a Snowpark env
- [ ] `10_powerbi/` Power BI connected to `REPORTING` under `BI_REPORTING`

## F. Evidence captured (see screenshot_capture_guide.md)
- [ ] Database/schema layout
- [ ] Synthetic data tables populated
- [ ] AML alerts by typology
- [ ] STR cases generated
- [ ] Reporting views returning rows
- [ ] Validation query results
- [ ] Snowsight query history (successful runs)
- [ ] (Optional) Power BI connection/model
- [ ] Images saved under `docs/evidence/`

## G. Repo updated after execution
- [ ] `validation_results.md` filled with real numbers + date
- [ ] README **Execution Evidence** links added
- [ ] README **Validation and Execution Status** switched to the "executed on [DATE]" wording
- [ ] `final_readiness_checklist.md` evidence column updated

---

**Sign-off (after a real run):** executed by `<name>` on `<date>`; overall result `<PASS/PARTIAL/FAIL>`.
