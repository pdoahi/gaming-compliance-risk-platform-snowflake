# Recommended Power BI Model

> **Phase 14 deliverable.** How to arrange the imported `REPORTING.VW_*` views into a clean
> Power BI semantic model. Synthetic data only.

## Model shape

The reporting views are already **pre-aggregated and grain-safe** (Phase 10), so the Power BI
model is deliberately simple: a shared **Date** dimension, a few month-grain fact-like views, and
several one-row / lookup views used directly by cards and slicers.

```text
                 ┌───────────── Date (dim) ─────────────┐
                 │  YEAR_MONTH / month-start / FY        │
                 └───▲───────────────▲──────────────▲────┘
                     │               │              │
     VW_MONTHLY_COMPLIANCE_TRENDS  VW_MARKET_PERFORMANCE  (month grain)
     VW_ALERT_TYPOLOGY_BREAKDOWN   VW_ANALYST_WORKLOAD    (lookup / category)
     VW_PLAYER_RISK_PROFILE (player grain, standalone)
     VW_EXECUTIVE_/AML_/STR_ SUMMARY (one row → cards, no relationships)
```

## Tables to import

| Import as | From | Grain | Use |
|---|---|---|---|
| `Date` | build with DAX `CALENDAR` (or import `DIM_DATE` via a small view) | day/month | shared date dimension; **mark as Date table** |
| `Trends` | `VW_MONTHLY_COMPLIANCE_TRENDS` | month | executive trend visuals |
| `Market` | `VW_MARKET_PERFORMANCE` | month | market trends |
| `MarketFY` | `VW_MARKET_FISCAL_YEAR` | fiscal year | FY bars + YoY |
| `AlertTypology` | `VW_ALERT_TYPOLOGY_BREAKDOWN` | rule | AML "by rule" |
| `SLA` | `VW_SLA_PERFORMANCE` | priority | STR SLA/aging |
| `AnalystWorkload` | `VW_ANALYST_WORKLOAD` | analyst | STR workload |
| `StatusFunnel` | `VW_STR_STATUS_FUNNEL` | status | STR funnel |
| `PlayerRisk` | `VW_PLAYER_RISK_PROFILE` | player | Player Risk page |
| `ExecKPIs` / `AMLKPIs` / `STRKPIs` | the three `*_SUMMARY` views | one row | KPI cards (no relationships) |

## Recommended relationships

- **`Date[YEAR_MONTH]` → `Trends[YEAR_MONTH]`** (1-to-many, single direction).
- **`Date[YEAR_MONTH]` → `Market[YEAR_MONTH]`** (1-to-many, single direction).
- Everything else is standalone: the `*_SUMMARY` views are single-row (cards, no relationship),
  and `AlertTypology` / `SLA` / `AnalystWorkload` / `StatusFunnel` / `PlayerRisk` are category /
  entity lookups used within their own page.

> **Grain firewall (important):** do **not** relate `Market` to any transaction/alert/case view
> — market is monthly market-wide and must never be blended with per-transaction AML metrics.
> The only cross-domain surface is the executive page, which uses the pre-aggregated one-row
> summary views.

## Modeling housekeeping

- **Mark `Date` as a date table** (enables time-intelligence DAX).
- Hide technical keys (`*_KEY`) from report view; keep business names.
- Set data categories/format: currency for values, percentage for `*_PCT`, whole number for counts.
- Sort `StatusFunnel` by `WORKFLOW_ORDER`, `AlertTypology` by `ALERTS` desc.
- Keep model **Import** (per the connection guide) for speed and low Snowflake cost.

DAX measures are in [`recommended_measures.md`](recommended_measures.md).
