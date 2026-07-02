# SQL Formatting & Readability Review

> A reviewer-focused pass over the SQL for readability. **No business logic was changed.** The
> existing SQL was already structured (header blocks, per-rule comments, layered CTEs), so this
> pass made targeted additions rather than wholesale reformatting — deliberately, because the
> scripts have **not been executed live** and churning untested SQL for cosmetics risks
> introducing errors that can't be caught here.

## Files changed this pass

| File | Change | Logic changed? |
|---|---|---|
| `snowflake/06_reporting/02_aml_views.sql` | Added explicit **grain comments** to both views (`VW_AML_MONITORING_SUMMARY` = 1 row; `VW_ALERT_TYPOLOGY_BREAKDOWN` = 1 row per rule) | No — comments only |
| `snowflake/06_reporting/03_str_views.sql` | Added **grain comments** to all four views (program summary, SLA-by-priority, per-analyst, status funnel) | No — comments only |
| `snowflake/00_setup/04_governance_policies.sql` | Added a **"DEMO GOVERNANCE PATTERN — not production"** note to the header (hard-coded region, role-only logic, elevated actor), pointing to `governance_model.md` | No — comment only |

## Files reviewed and left unchanged (already portfolio-ready)

| File | Why unchanged |
|---|---|
| `snowflake/04_aml_rules/02_generate_aml_alerts.sql` | Each of the 11 rules already carries a comment stating the typology + threshold; CTEs are clearly separated; the final `INSERT` `SELECT` is annotated (which columns are refined later). Aliases (`c`, `PC`, `PS`) are short but scoped to tiny sub-selects and explained by the rule comment above them. |
| `snowflake/06_reporting/01_executive_views.sql` | Already has grain notes, one-row `CROSS JOIN` pattern documented, and month-spine comments. |
| `snowflake/06_reporting/04_market_views.sql` | Grain firewall already commented; YoY logic annotated. |
| `snowflake/06_reporting/05_player_risk_views.sql` | Player grain already stated; composite risk band documented. |
| `snowflake/07_data_quality/*.sql` | Header blocks, per-check `STATUS` labels, and consistent `PASS`/`FAIL`/`REVIEW` conventions already present. |

## Conventions confirmed across the SQL

- **Uppercase** Snowflake object names and keywords throughout; no lowercase `CREATE` targets.
- Every script sets its **run context** (`USE ROLE` / `USE WAREHOUSE` / `USE SCHEMA`) at the top.
- **Header comment block** on every file (phase, purpose, run order, synthetic-data disclaimer).
- **CTE-per-step** structure with a comment introducing each CTE.
- `CASE` / `IFF` scoring blocks are indented and aligned.
- Reporting views now each declare their **grain** in the header comment.

## Logic issues found

**None.** No bugs or logic changes were required or made in this pass. (Grain-safety of the
reporting views was reviewed structurally — one-row `CROSS JOIN`s for KPI views, pre-aggregation
before cross-domain joins, market firewall intact — and is documented in
[`reporting_layer.md`](reporting_layer.md).)

## Observations (non-blocking, optional future polish)

- The AML rule sub-selects use terse aliases (`c`, `PC`, `PS`). They're readable in context;
  renaming to `TXN_COUNT` / `PAYEE_COUNT` / `PAYEE_SUM` would be a nicety but is not required.
- A shared "rule catalog" comment listing all 11 thresholds in one place already exists via the
  per-rule comments; a consolidated table could be added to `aml_rules_framework.md` if desired
  (it largely is).

## Verdict

The SQL is **easier for a reviewer to read** after this pass (explicit reporting-view grains,
explicit governance demo caveat) and remains **logic-identical**. Correctness was confirmed
**structurally** here and has since been **confirmed at runtime** — the platform ran end to end
in Snowflake on 2026-07-02 with a 18/18 setup verification (see
[`validation_results.md`](validation_results.md)).
