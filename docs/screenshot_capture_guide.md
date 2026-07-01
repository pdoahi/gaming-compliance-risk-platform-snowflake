# Screenshot & Evidence Capture Guide

> Use this **after** running the platform in Snowflake to capture proof of execution. **Do not
> fabricate screenshots** — capture real output only. Until then, evidence status is
> **Pending**.

Save images to `docs/evidence/` using the suggested file names, then link them from the README
**Execution Evidence** section and from [`validation_results.md`](validation_results.md).

| # | Screenshot | How to produce it | Suggested file |
|---|---|---|---|
| 1 | **Database / schema layout** | Snowsight → Data → `GAMING_COMPLIANCE_DB` showing the 7 schemas | `01_db_schema_layout.png` |
| 2 | **Synthetic data populated** | Run `SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS;` and show a `SELECT * ... LIMIT 20` | `02_data_populated.png` |
| 3 | **AML alerts by typology** | `SELECT * FROM REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN ORDER BY ALERTS DESC;` | `03_aml_by_typology.png` |
| 4 | **STR cases generated** | `SELECT * FROM REPORTING.VW_STR_WORKFLOW_SUMMARY;` and a `FACT_STR_CASES` sample | `04_str_cases.png` |
| 5 | **Reporting views returning rows** | `SELECT * FROM REPORTING.VW_EXECUTIVE_OVERVIEW;` (plus market view) | `05_reporting_views.png` |
| 6 | **Validation query results** | Output of `07_data_quality/*` showing the `STATUS` column | `06_validation_status.png` |
| 7 | **Query history (successful runs)** | Snowsight → Activity → Query History filtered to your session | `07_query_history.png` |
| 8 | **(Optional) Power BI** | Power BI Desktop connected to `REPORTING`, or the model view | `08_powerbi_model.png` |

## Tips
- Capture the **query text + result grid together** so the evidence is self-explanatory.
- Include the **role/warehouse** indicator in the corner of Snowsight where visible.
- Redact nothing — the data is synthetic, so screenshots are safe to share.
- For validation shots, make sure the `STATUS` column (`PASS`/`FAIL`/`REVIEW`) is visible.

## After capturing
1. Put the files in `docs/evidence/`.
2. Add a small gallery to the README **Execution Evidence** section:
   ```markdown
   ## Execution Evidence
   Executed in Snowflake on YYYY-MM-DD. See docs/validation_results.md.
   ![DB layout](docs/evidence/01_db_schema_layout.png)
   ![AML by typology](docs/evidence/03_aml_by_typology.png)
   ```
3. Update [`execution_proof_checklist.md`](execution_proof_checklist.md) section F.

> Until real screenshots exist, keep the README **Execution Evidence** section marked
> **Pending** — an empty evidence section is more credible than an invented one.
