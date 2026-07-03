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
- **Validation scripts** authored to be run and interpreted in Snowflake at each checkpoint
  (the checkpoint discipline; live execution is the pending next step).

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

## Concepts since implemented (Phases 12–15)

These were "planned for later" during the early phases and are now **implemented in the repo**
and part of the executed & validated build (2026-07-02, 18/18 + 21/21 — see
[`validation_results.md`](validation_results.md)):

| Concept | Status | Where it lives |
|---|---|---|
| Streams (change tracking) | Implemented (optional) | `08_automation/01_streams.sql` |
| Tasks (scheduled transforms) | Implemented (optional, suspended) | `08_automation/02_tasks.sql` |
| Snowpark Python (risk scoring) | Implemented (optional) | `09_snowpark/aml_risk_scoring_example.py` |
| Masking / row-access policies | Implemented (demo pattern) | `00_setup/04_governance_policies.sql` |
| Data-classification tags | Implemented (demo pattern) | `00_setup/04_governance_policies.sql` |
| Time Travel / retention | Implemented (demo pattern) | `00_setup/04_governance_policies.sql` |
| Synthetic data generator (in-DB) | Implemented | `01_ingestion/05_generate_synthetic_data.sql` |

## Still open (deliberate scope boundaries)

| Concept | Status | Notes |
|---|---|---|
| SCD Type 2 (KYC/risk history) | Roadmap | documented in `data_model.md` §6 |
| CI/CD deployment (dbt/native) | Future | out of scope for a portfolio build |
| Zero-copy cloning demo | Future | Time Travel is shown; cloning is described, not scripted |
| Rejects handling on `COPY INTO` | Future | generator path avoids file-load errors; `ON_ERROR=CONTINUE` + rejects table would harden the file path |
| Real customer/KYC master source | Future | dimension attributes are `HASH()`-synthesized today |

## Learning trajectory

Foundations (databases, warehouses, RBAC, ingestion) → transformation (staging, DQ) →
modeling (dims/facts, surrogate keys, grain) → analytics logic (AML rules, STR SLAs, window
functions) → serving (reporting views / semantic layer) → **automation (Streams/Tasks),
in-database Python (Snowpark), governance (masking/row-access/tags/Time Travel), and BI
enablement (Power BI package)**. The platform was then **executed and validated** in a Snowflake
trial (2026-07-02, 18/18 + 21/21; see [`validation_results.md`](validation_results.md)).

See the concrete mapping in [`snowflake_skills_matrix.md`](snowflake_skills_matrix.md).
