# snowflake/

All Snowflake SQL for the platform, organized as **ordered, layered steps**. Run the folders
in numeric order; within a folder, run files in numeric order. Scripts are added phase by
phase and use Snowflake SQL syntax, uppercase object names, and `CREATE OR REPLACE` where
appropriate.

## Layered flow

```text
RAW → STAGING → CORE / ANALYTICS → REPORTING → BI / APP LAYER
```

## Folder map (phase that populates it)

| Folder | Contents | Phase |
|---|---|---|
| `00_setup/` | Warehouses, database, schemas, roles, grants | 4 |
| `01_ingestion/` | File formats, stages, RAW tables, `COPY INTO` + in-DB synthetic data generator | 5 / 15 |
| `02_staging/` | Typed / cleaned staging tables + transformations | 6 |
| `03_core_model/` | Dimensions + facts (create & load) | 7 |
| `04_aml_rules/` | Alert-type seed, AML alert generation, scoring | 8 |
| `05_str_workflow/` | STR case generation + SLA logic | 9 |
| `06_reporting/` | BI-ready reporting views | 10 |
| `07_data_quality/` | Data quality, reconciliation, phase validation | 11 |
| `08_automation/` | Streams & Tasks (optional) | 13 |
| `09_snowpark/` | Snowpark Python example (optional) | 13 |
| `10_powerbi/` | Power BI connection guide, model, measures | 14 |

## Target database

```text
GAMING_COMPLIANCE_DB
  RAW · STAGING · CORE · ANALYTICS · REPORTING · GOVERNANCE · UTILITY
```

## Standards

- Cost-aware compute: `XSMALL`/`SMALL` warehouses, `AUTO_SUSPEND`, `AUTO_RESUME`.
- No hardcoded credentials or secrets — you supply your own account context.
- All data is synthetic and clearly labelled.

## Execution status

These scripts are **authored and statically reviewed** but **not yet executed** against a live
Snowflake account. Status: **Pending Manual Snowflake Execution.** To run the whole platform in
order, follow [`../docs/deployment_guide.md`](../docs/deployment_guide.md); record outcomes in
[`../docs/validation_results.md`](../docs/validation_results.md).
