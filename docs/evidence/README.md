# Execution Evidence

Screenshots from the live Snowflake run (**executed & validated 2026-07-02**: 18/18 setup
verification + 21/21 reconciliation/DQ). Results are recorded in
[`../validation_results.md`](../validation_results.md).

## Save these four files here (exact names)

| File | Capture this query (screenshot the query **and** its result grid) |
|---|---|
| `01_executive_overview.png` | `SELECT * FROM REPORTING.VW_EXECUTIVE_OVERVIEW;` |
| `02_aml_typologies.png` | `SELECT * FROM REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN ORDER BY ALERTS DESC;` |
| `03_str_workflow.png` | `SELECT * FROM REPORTING.VW_STR_WORKFLOW_SUMMARY;` |
| `04_reconciliation.png` | the 21/21 grid from `07_data_quality/06_reconciliation_verification.sql` |

Optional extras: `05_db_schema_layout.png` (Snowsight → Data → the 7 schemas),
`06_query_history.png` (Activity → Query History showing successful runs).

## Tips
- Keep the **query text + result grid** both visible in one shot — self-explanatory evidence.
- The data is **synthetic**, so nothing needs redacting; screenshots are safe to share.
- Once these files are in this folder, they get linked from the README **Execution Evidence**
  section. No screenshots are fabricated — images appear only once they exist.
