# Snowflake Skills → Project Deliverables Matrix

> Maps each Snowflake skill to **where it appears in this repo**, its **business purpose**, its
> **portfolio value**, and **status**. The goal: make it obvious what was learned and how it was
> applied. Synthetic data only.

| Snowflake Skill | Where It Appears in the Project | Files or Folders | Business Purpose | Portfolio Value | Status |
|---|---|---|---|---|---|
| Database & schema design | Layered `GAMING_COMPLIANCE_DB` (7 schemas) | `snowflake/00_setup/02` | Separate landing/curate/serve concerns | Shows medallion/layered thinking | Done |
| Warehouse strategy | 4 workload-isolated warehouses, cost-aware | `snowflake/00_setup/01` | Right-size compute; control spend | Cost-awareness is a senior signal | Done |
| Roles & grants | 6 functional roles + grants | `snowflake/00_setup/03` | Who can touch what | Governance literacy | Done |
| Least-privilege access | `FUTURE` grants; BI role = REPORTING only | `snowflake/00_setup/03` | Minimize blast radius | Security-minded design | Done |
| File formats | Reusable CSV + JSON formats | `snowflake/01_ingestion/01` | Consistent parsing | Reusability discipline | Done |
| Internal stages | `RAW.STG_LANDING` + folders | `snowflake/01_ingestion/02` | Land files before load | Ingestion mechanics | Done |
| `COPY INTO` loading | Load w/ `METADATA$FILENAME`, batch id | `snowflake/01_ingestion/04` | Auditable bulk load | Load lineage know-how | Done |
| RAW-layer design | Source-faithful VARCHAR + metadata, `TRANSIENT` | `snowflake/01_ingestion/03` | Preserve source, cut storage cost | Understands storage model | Done |
| STAGING transformations | `TRY_TO_*`, normalization, DQ flags | `snowflake/02_staging/02` | Type/clean without failing loads | Robust ELT | Done |
| Dimensional modeling | Fact constellation, conformed dims | `snowflake/03_core_model/*`, `docs/data_model.md` | Analytics-friendly schema | Kimball fundamentals | Done |
| Fact & dimension tables | 6 dims + 4 facts | `snowflake/03_core_model/01–02` | Model the business | Core data-warehouse skill | Done |
| Surrogate keys | `NUMBER IDENTITY` PKs + FK lookups | `snowflake/03_core_model/*` | Stable joins, decouple from source ids | Modeling maturity | Done |
| CTEs | Layered CTEs across engine + views | `snowflake/04–06/*` | Readable, staged SQL | Clean SQL craftsmanship | Done |
| Window functions | `COUNT/SUM OVER`, `LAG`, `PERCENTILE_CONT`, `QUALIFY` | `snowflake/04_aml_rules/02`, `05_str_workflow/01` | Velocity, structuring, spikes, dedupe | Advanced SQL | Done |
| `CASE` statements | Scoring, normalization, risk banding | `snowflake/04_aml_rules/03`, `06_reporting/05` | Explainable logic | Business-rule encoding | Done |
| Aggregation logic | KPI + breakdown views | `snowflake/06_reporting/*` | Turn rows into metrics | Metric definition | Done |
| AML rule generation | 11 typologies → alerts | `snowflake/04_aml_rules/02` | Detect suspicious activity | Domain + SQL depth | Done |
| STR workflow generation | Escalated alerts → cases | `snowflake/05_str_workflow/01` | Investigation pipeline | Workflow modeling | Done |
| SLA logic | Target by priority, breach flag | `snowflake/05_str_workflow/02` | Regulatory timeliness | Compliance realism | Done |
| Data-quality checks | `IS_VALID`/`DQ_ISSUES`; validation scripts | `snowflake/02_staging/02`, `07_data_quality/00` | Trustworthy data | Testing discipline | Done |
| Relationship validation | Orphan/FK checks | `snowflake/07_data_quality/00` (C-block) | Referential integrity | Rigor | Done |
| Grain management | Market firewall; pre-agg before join | `docs/reporting_layer.md`, `06_reporting/*` | Avoid double-counting | Prevents classic BI bug | Done |
| Power BI-ready views | Business-named `VW_*` semantic layer | `snowflake/06_reporting/*`, `docs/reporting_layer.md` | Clean BI contract | BI enablement | Done |
| Streams (CDC) | Append-only stream on transactions | `snowflake/08_automation/01` | Incremental processing | Automation depth | Done (optional) |
| Tasks (scheduling) | Stream-gated task, suspended by default | `snowflake/08_automation/02` | Scheduled ELT/alerts | Orchestration | Done (optional) |
| Snowpark Python | Feature-eng + heuristic risk score | `snowflake/09_snowpark/` | In-DB risk scoring | ML/eng breadth | Done (optional) |
| Masking / row-access policies | `MP_IDENTIFIER` mask + `RAP_REGION` row policy | `snowflake/00_setup/04` | Protect sensitive fields | Governance depth | Done (demo pattern) |
| Classification tags | `DATA_CLASSIFICATION` + `PII` tags | `snowflake/00_setup/04` | Find/govern sensitive data | Governance literacy | Done (demo pattern) |
| Time Travel / retention | 14-day retention on RESTRICTED facts | `snowflake/00_setup/04` | Point-in-time audit/recovery | Audit awareness | Done (demo pattern) |
| Synthetic data generation | In-DB generator (no files needed) | `snowflake/01_ingestion/05` | Make the pipeline runnable | Reproducibility | Done |
| Power BI integration package | Connection guide + model + DAX + dashboard spec | `snowflake/10_powerbi/`, `powerbi/` | BI enablement | Semantic-layer delivery | Done |
| SCD Type 2 | Roadmap only | `docs/data_model.md` §6 | Historical KYC/risk | Audit-grade modeling | Roadmap |

Legend: **Done** = implemented (authored & in-repo) · **(optional)** = portfolio extra, not on
the critical path · **(demo pattern)** = illustrative governance, not production access control ·
**Roadmap** = documented, not yet built.

> **Status vs. execution.** "Done" means the SQL/code is authored and present in the repo. The
> platform as a whole was **executed and validated** in a Snowflake trial on 2026-07-02
> (18/18 setup verification + 21/21 reconciliation/DQ) — see
> [`validation_results.md`](validation_results.md); individual optional items (Streams/Tasks,
> Snowpark, governance policies) were not each separately exercised at runtime.
