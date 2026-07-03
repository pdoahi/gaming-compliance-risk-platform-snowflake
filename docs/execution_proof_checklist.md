# Execution Proof Checklist

> **Status: `Executed & validated — 2026-07-02`.** The platform was built and run in a Snowflake
> trial. Sections A–D, F, and G are complete, verified by the **18/18 setup-verification** and
> **21/21 reconciliation/DQ** grids (recorded in [`validation_results.md`](validation_results.md))
> and the screenshots in [`evidence/`](evidence). Section E (optional extras) and a few optional
> evidence shots are left unticked by design.

Legend: `[ ]` not done · `[~]` in progress · `[x]` done (with evidence).

## A. Environment
- [x] Snowflake trial/account opened; Snowsight worksheet created
- [x] Active role and warehouse confirmed (`SELECT CURRENT_ROLE(), CURRENT_WAREHOUSE();`)
- [x] Custom roles granted to my user (`DATA_ENGINEER`, `BI_REPORTING`)

## B. Build (in order — see manual_snowflake_test_plan.md)
- [x] `00_setup/01–03` warehouses, DB, schemas, roles
- [x] `01_ingestion/01–03` formats, stage, RAW tables
- [x] `01_ingestion/05` synthetic data generated (RAW populated — 5,310 rows)
- [x] `02_staging/01–02` staging built; invalid rows = 0
- [x] `03_core_model/01–04` dims + facts loaded
- [ ] `00_setup/04` governance policies applied (optional, after core — not run this session)
- [x] `04_aml_rules/01–03` alerts generated + scored
- [x] `05_str_workflow/01–02` STR cases + SLA
- [x] `06_reporting/01–05` 11 reporting views compiled

## C. Smoke tests (recorded in validation_results.md)
- [x] Transaction count returned (5,310)
- [x] Market month count = 36
- [x] AML alert count > 0 (5,749)
- [x] Distinct alert typologies firing (11)
- [x] STR case count > 0 (3,051)
- [x] `VW_ALERT_TYPOLOGY_BREAKDOWN` returns 11 rows
- [x] `VW_EXECUTIVE_OVERVIEW` returns 1 row
- [x] `VW_AML_MONITORING_SUMMARY` returns 1 row
- [x] `VW_STR_WORKFLOW_SUMMARY` returns 1 row
- [x] `VW_MARKET_PERFORMANCE` returns 36 rows

## D. Validation scripts (recorded in validation_results.md)
The consolidated one-grid scripts were used: `05_setup_verification.sql` (18/18) and
`06_reconciliation_verification.sql` (21/21), the latter covering the `01` DQ checks and `02`
R1–R8 reconciliation.
- [x] `07_data_quality/06_reconciliation_verification.sql` — 21/21 (R1–R8 + integrity)
- [x] `07_data_quality/05_setup_verification.sql` — 18/18
- [ ] `07_data_quality/03_phase_validation_queries.sql` — per-phase gates (not run separately)
- [ ] `07_data_quality/00_pre_phase10_validation_checks.sql` (not run separately)
- [ ] `07_data_quality/04_post_phase10_reporting_validation.sql` (not run separately)

## E. Optional extras
- [ ] `08_automation/01–02` stream + (suspended) task created
- [ ] `09_snowpark/aml_risk_scoring_example.py` run in a Snowpark env
- [ ] `10_powerbi/` Power BI connected to `REPORTING` under `BI_REPORTING`

## F. Evidence captured (see screenshot_capture_guide.md)
- [ ] Database/schema layout
- [ ] Synthetic data tables populated (raw-table shot)
- [x] AML alerts by typology
- [x] STR cases generated
- [x] Reporting views returning rows
- [x] Validation query results (21/21 grid)
- [ ] Snowsight query history (successful runs)
- [ ] (Optional) Power BI connection/model
- [x] Images saved under `docs/evidence/`

## G. Repo updated after execution
- [x] `validation_results.md` filled with real numbers + date
- [x] README **Execution Evidence** links added
- [x] README **Validation and Execution Status** switched to the "executed on [DATE]" wording
- [x] `final_readiness_checklist.md` evidence column updated

---

**Sign-off:** executed & validated by the repository owner on **2026-07-02** — **18/18 setup
verification + 21/21 reconciliation/DQ, all PASS** (all 11 AML typologies firing; two defects
found & fixed — R10 concentration, R03 duplicate alerts). Evidence screenshots captured and
linked in the README; optional extras (E) and a couple of optional evidence shots remain.
