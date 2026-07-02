# Execution Evidence

Screenshots from the live Snowflake run (**executed & validated 2026-07-02**: 18/18 setup
verification + 21/21 reconciliation/DQ). Results are recorded in
[`../validation_results.md`](../validation_results.md).

## Save these files here (exact names)

The wide one-row views are captured **transposed** (tall metric→value) so every value fits in a
single screenshot — run `07_data_quality/07_evidence_snapshot.sql` for those.

| File | Capture this (all narrow/tall — fit in one screenshot) |
|---|---|
| `01_kpi_snapshot.png` | Query **A** in `07_evidence_snapshot.sql` — executive/AML/STR KPIs, transposed |
| `02_aml_typologies.png` | Query **B** in `07_evidence_snapshot.sql` — all 11 rules (6 columns) |
| `03_reconciliation.png` | the 21/21 grid from `06_reconciliation_verification.sql` |
| `04_setup_verification.png` | the 18/18 grid from `05_setup_verification.sql` |

Optional extras: `05_db_schema_layout.png` (Snowsight → Data → the 7 schemas),
`06_query_history.png` (Activity → Query History showing successful runs).

## Tips
- Keep the **query text + result grid** both visible in one shot — self-explanatory evidence.
- The data is **synthetic**, so nothing needs redacting; screenshots are safe to share.
- Once these files are in this folder, they get linked from the README **Execution Evidence**
  section. No screenshots are fabricated — images appear only once they exist.
