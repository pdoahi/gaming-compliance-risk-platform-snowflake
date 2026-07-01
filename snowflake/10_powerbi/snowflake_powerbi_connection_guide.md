# Power BI ↔ Snowflake Connection Guide

> **Phase 14 deliverable.** How to connect Power BI Desktop to the platform's Snowflake
> reporting layer. Synthetic data only; **no credentials appear in this repo** — you supply
> your own account context.

## Prerequisites

- **Power BI Desktop** (free).
- A Snowflake account with the platform built (Phases 1–10) and the reporting views created.
- A role that can read `REPORTING` — use **`BI_REPORTING`** (least-privilege; reporting views only).
- The **`WH_REPORTING`** warehouse (XSMALL, auto-suspend).

## Connect (Power BI Desktop)

1. **Home → Get Data → Snowflake.**
2. Fill in:
   | Field | Value |
   |---|---|
   | **Server** | `<your_account>.snowflakecomputing.com` (your account URL) |
   | **Warehouse** | `WH_REPORTING` |
   | **(Advanced) Database** | `GAMING_COMPLIANCE_DB` |
   | **(Advanced) Role** | `BI_REPORTING` |
3. **Data Connectivity mode:** choose **Import** (recommended — see below).
4. **Sign in** with your Snowflake credentials — use **SSO / Microsoft Entra / browser auth**
   where possible. Power BI stores credentials in its own credential manager; **never** put
   them in a file or this repo.
5. In the Navigator, expand `GAMING_COMPLIANCE_DB` → `REPORTING` and select the `VW_*` views
   you need (below), then **Load**.

## Which objects to import (REPORTING only)

Power BI reads **only the `REPORTING` schema** (enforced by the `BI_REPORTING` grants). Import:

| View | Feeds |
|---|---|
| `VW_EXECUTIVE_OVERVIEW` | Executive cards (one row) |
| `VW_MONTHLY_COMPLIANCE_TRENDS` | Executive trend lines (by month) |
| `VW_AML_MONITORING_SUMMARY` | AML cards (one row) |
| `VW_ALERT_TYPOLOGY_BREAKDOWN` | AML "alerts by rule" |
| `VW_STR_WORKFLOW_SUMMARY` | STR cards (one row) |
| `VW_SLA_PERFORMANCE` | STR SLA / aging by priority |
| `VW_ANALYST_WORKLOAD` | STR analyst workload |
| `VW_STR_STATUS_FUNNEL` | STR pipeline funnel |
| `VW_MARKET_PERFORMANCE` | Market monthly trends |
| `VW_MARKET_FISCAL_YEAR` | Market fiscal-year + YoY |
| `VW_PLAYER_RISK_PROFILE` | Player Risk page |

## Import vs DirectQuery

**Recommendation: Import** for this project.

| | Import (recommended here) | DirectQuery |
|---|---|---|
| Data | Cached in the .pbix; refresh on demand | Live query to Snowflake per interaction |
| Speed | Fast (in-memory) | Depends on warehouse; slower |
| Cost | Warehouse runs only on refresh | Warehouse runs on **every** visual interaction 💲 |
| Best for | Small/synthetic data (this project), best performance | Very large data, near-real-time needs, or when data can't be cached |

The synthetic dataset is small, so **Import** gives the best performance at the lowest
Snowflake compute cost. Switch to DirectQuery only if you need live data or the volume outgrows
Import.

## Refresh & cost notes

- On refresh, `WH_REPORTING` auto-resumes, runs the queries, then auto-suspends (60s) — you pay
  only for the refresh.
- Schedule refresh in the Power BI Service if you publish; keep it as infrequent as the use case
  allows.

## Security

- Credentials live in Power BI's credential store / your identity provider — **not** in the model
  or this repo.
- Row-level security and identifier masking are enforced **in Snowflake** (Phase 12) for direct
  access; because Power BI reads the reporting views under `BI_REPORTING`, it sees exactly the
  serving layer intended for BI.
