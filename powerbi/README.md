# powerbi/

Power BI reporting layer for the platform — how the dashboards consume Snowflake.

- `dashboard_specification.md` — the four dashboard pages (Executive Overview, AML
  Monitoring, STR Workflow, Market/GGR Performance), their KPIs and visuals. **Delivered in
  Phase 14.**
- Snowflake↔Power BI connection guidance, the recommended semantic model, and DAX measures
  live under [`../snowflake/10_powerbi/`](../snowflake/10_powerbi) (also Phase 14).

Dashboards are driven by the **reporting views** in `snowflake/06_reporting/` (Phase 10), so
Power BI never touches raw or core tables directly. All figures are synthetic and illustrative.
