# Snowflake Learning Audit

> This project is a **hands-on Snowflake learning exercise** as well as a portfolio piece. I
> have no prior professional Snowflake experience — this document shows which Snowflake
> concepts I have applied, *where*, which are still to come, and how the work reflects
> deliberate learning rather than only generated code. Synthetic data only.

## How this shows *applied* learning (not just AI output)

Each concept below is tied to a **specific file and a business reason**, and the design makes
deliberate Snowflake choices a beginner wouldn't get for free:

- **`TRANSIENT` tables** for RAW/STAGING to skip Fail-safe and cut storage cost (understanding
  the storage/cost model, not just `CREATE TABLE`).
- **`AUTO_SUSPEND` / `INITIALLY_SUSPENDED`** on right-sized, workload-isolated warehouses
  (understanding separation of storage & compute).
- **Least-privilege RBAC** with functional roles + `FUTURE` grants (understanding Snowflake's
  role hierarchy, not just `GRANT ALL`).
- **`METADATA$FILENAME` / `METADATA$FILE_ROW_NUMBER`** capture on `COPY INTO` (Snowflake-native
  load lineage).
- **A grain firewall** keeping market/GGR separate from transaction-level AML (dimensional-
  modeling judgement).
- **Validation scripts** I run and interpret myself in Snowflake (the checkpoint discipline).

## Concepts implemented so far

| Concept | Where I applied it |
|---|---|
| Databases & schemas (layered) | `00_setup/02_create_database_schemas.sql` |
| Virtual warehouses + cost controls | `00_setup/01_create_warehouses.sql` |
| Role-based access control (least privilege) | `00_setup/03_create_roles_grants.sql` |
| File formats (reusable) | `01_ingestion/01_create_file_formats.sql` |
| Internal stages | `01_ingestion/02_create_stages.sql` |
| RAW-layer landing design (source-faithful + metadata) | `01_ingestion/03_create_raw_tables.sql` |
| `COPY INTO` with stage metadata | `01_ingestion/04_load_data_examples.sql` |
| STAGING transformations (`TRY_TO_*`, normalization, DQ flags) | `02_staging/02_staging_transformations.sql` |
| Dimensional modeling (fact constellation) | `03_core_model/01–02`, `docs/data_model.md` |
| Fact & dimension tables | `03_core_model/01_create_dimensions.sql`, `02_create_facts.sql` |
| Surrogate keys (`IDENTITY`) | `03_core_model/01–02` |
| Generated calendar (`GENERATOR`, `SEQ4`) | `03_core_model/03_load_dimensions.sql` |
| CTEs | throughout `03–06` |
| `CASE` logic | AML scoring, staging normalization, player risk banding |
| Aggregations | reporting views (`06_reporting/*`) |
| Window functions (`COUNT/SUM OVER`, `LAG`, `PERCENTILE_CONT`, `QUALIFY`) | `04_aml_rules/02`, `05_str_workflow/01`, `03_core_model/04` |
| Data-quality checks | `02_staging/02` (`IS_VALID`/`DQ_ISSUES`), `07_data_quality/00` |
| AML rule logic (11 typologies) | `04_aml_rules/02_generate_aml_alerts.sql` |
| STR workflow + SLA logic | `05_str_workflow/01–02` |
| Reporting views (semantic layer) | `06_reporting/01–05` |
| Power BI-ready views | `06_reporting/*` + `docs/reporting_layer.md` |

## Concepts missing / underdeveloped (planned for later phases)

| Concept | Status | Where it lands |
|---|---|---|
| Streams (change tracking) | Not yet | Phase 13 (`08_automation/01_streams.sql`) |
| Tasks (scheduled transforms) | Not yet | Phase 13 (`08_automation/02_tasks.sql`) |
| Snowpark Python (risk scoring) | Not yet | Phase 13 (`09_snowpark/`) |
| Masking / row-access policies | Not yet | Phase 12 (governance) |
| Time Travel / cloning demos | Referenced only | Phase 12 |
| SCD Type 2 (KYC/risk history) | Roadmap documented | future enhancement (`data_model.md` §6) |
| CI/CD deployment | Not yet | future enhancement |

## Improvements to make later (non-blocking for Phase 10)

- Add the **synthetic data generator + sample CSVs** so the pipeline runs end-to-end.
- Promote **market-by-product** from STAGING into a CORE fact for product-mix reporting.
- Replace deterministic `HASH()`-synthesized dimension attributes with a proper synthetic
  **customer/KYC master** source.
- Add **rejects handling** on `COPY INTO` (`ON_ERROR = CONTINUE` + a rejects table).

## Learning trajectory

Foundations (databases, warehouses, RBAC, ingestion) → transformation (staging, DQ) →
modeling (dims/facts, surrogate keys, grain) → analytics logic (AML rules, STR SLAs, window
functions) → serving (reporting views / semantic layer). Next: automation (Streams/Tasks),
in-database Python (Snowpark), and governance (policies).

See the concrete mapping in [`snowflake_skills_matrix.md`](snowflake_skills_matrix.md).
