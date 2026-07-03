# Execution Evidence

Screenshots from the live Snowflake run (**executed & validated 2026-07-02**: 18/18 setup
verification + 21/21 reconciliation/DQ). Results are recorded in
[`../validation_results.md`](../validation_results.md).

## Captured screenshots (linked from the README Execution Evidence section)

| File | Shows |
|---|---|
| `01_executive_overview_1.png` / `_2.png` | Executive KPI snapshot (transposed) — all 17 KPIs across two shots |
| `02_aml_typologies.png` | AML alerts by typology — all 11 rules firing (ALERTS sum to 5,749) |
| `03_str_workflow.png` | STR workflow summary (cases, STRs filed, conversion, SLA) |
| `04_reconciliation_1.png` / `_2.png` | Reconciliation + DQ grid — R1–R8 + integrity, all PASS (rows 1–15 of 21) |

The wide one-row views were captured **transposed** via
[`../../snowflake/07_data_quality/07_evidence_snapshot.sql`](../../snowflake/07_data_quality/07_evidence_snapshot.sql)
so every value is legible. The full 21/21 reconciliation grid is recorded in
[`../validation_results.md`](../validation_results.md).

## Tips
- Keep the **query text + result grid** both visible in one shot — self-explanatory evidence.
- The data is **synthetic**, so nothing needs redacting; screenshots are safe to share.
- Once these files are in this folder, they get linked from the README **Execution Evidence**
  section. No screenshots are fabricated — images appear only once they exist.
