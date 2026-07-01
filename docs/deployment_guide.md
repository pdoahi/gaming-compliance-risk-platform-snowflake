# Deployment Guide

> **Phase 15 deliverable.** A step-by-step runbook for building the entire platform in a
> Snowflake account of your own. Everything here uses **synthetic data**; no real
> credentials, secrets, or production information are required or included.

This guide takes you from an empty Snowflake account to a fully populated compliance
warehouse with BI-ready reporting views, running the SQL **in numbered order**. It is
written for someone new to Snowflake.

---

## 1. Prerequisites

- A **Snowflake account** — a [free 30-day trial](https://signup.snowflake.com/) is enough
  (this project is sized for XSMALL/SMALL warehouses and small synthetic volumes).
- Access to a SQL client: **Snowsight** (the Snowflake web UI, recommended) or the
  `snowsql` CLI. No local install is required for Snowsight.
- The ability to use elevated roles for setup — the trial's initial user has
  `ACCOUNTADMIN`, which is all you need to create the custom roles below.
- **Python 3.9+** only if you want to run the optional Snowpark example (Phase 13); not
  needed for the core build.

You do **not** need to prepare or upload any data files — script
[`01_ingestion/05_generate_synthetic_data.sql`](../snowflake/01_ingestion/05_generate_synthetic_data.sql)
generates the synthetic dataset directly inside Snowflake.

---

## 2. How the scripts are organized

All SQL lives under [`../snowflake/`](../snowflake) in numbered layers. Run the folders in
order; within a folder, run files in numeric order.

| Order | Folder | What it builds | Runs as | Warehouse |
|---|---|---|---|---|
| 00 | `00_setup/` | Warehouses, database, schemas, roles & grants | `SYSADMIN` / `SECURITYADMIN` | — (DDL) |
| 01 | `01_ingestion/` | File formats, stage, RAW tables, **synthetic data** | `DATA_ENGINEER` | `WH_INGESTION` |
| 02 | `02_staging/` | Typed/cleaned STAGING tables + transforms | `DATA_ENGINEER` | `WH_TRANSFORM` |
| 03 | `03_core_model/` | Dimensions + facts (create & load) | `DATA_ENGINEER` | `WH_TRANSFORM` |
| 04 | `04_aml_rules/` | Alert-type seed, AML alert generation, scoring | `DATA_ENGINEER` | `WH_TRANSFORM` |
| 05 | `05_str_workflow/` | STR case generation + SLA logic | `DATA_ENGINEER` | `WH_TRANSFORM` |
| 06 | `06_reporting/` | BI-ready reporting views | `DATA_ENGINEER` | — (views) |
| 07 | `07_data_quality/` | DQ, reconciliation, phase validation | `DATA_ENGINEER` | `WH_TRANSFORM` / `WH_REPORTING` |
| 08 | `08_automation/` | Streams & Tasks *(optional)* | `DATA_ENGINEER` | `WH_TRANSFORM` |
| 09 | `09_snowpark/` | Snowpark Python example *(optional)* | — | `WH_DATA_SCIENCE` |
| 10 | `10_powerbi/` | Power BI connection guide, model, measures *(docs)* | — | `WH_REPORTING` |

Each script sets its own `USE ROLE` / `USE WAREHOUSE` / `USE SCHEMA` context at the top, so
you can paste a whole file into a Snowsight worksheet and **Run All**.

> **Governance timing.** `00_setup/04_governance_policies.sql` applies masking / row-access
> policies and Time Travel to the CORE tables, so it must run **after** the core model exists
> (Phase 03). Run 00_setup files 01–03 first, then come back to 04 after step 5 below. It
> runs as `ACCOUNTADMIN`.

---

## 3. Step-by-step

### Step 0 — Open a worksheet
Sign in to Snowsight → **Projects → Worksheets → + Worksheet**. Set the role to
`ACCOUNTADMIN` for setup.

### Step 1 — Platform setup (`00_setup/`)
Run, in order:
1. `01_create_warehouses.sql` — 4 cost-aware warehouses (`AUTO_SUSPEND = 60s`).
2. `02_create_database_schemas.sql` — `GAMING_COMPLIANCE_DB` + 7 schemas.
3. `03_create_roles_grants.sql` — 6 least-privilege roles and their grants.

> After this step, **grant the custom roles to your user** so you can assume them, e.g.:
> ```sql
> GRANT ROLE DATA_ENGINEER  TO USER <your_user>;
> GRANT ROLE BI_REPORTING   TO USER <your_user>;
> ```
> (`03_create_roles_grants.sql` grants the roles to `SYSADMIN`; granting them to your user
> too lets you `USE ROLE` them directly.)

### Step 2 — Ingestion + synthetic data (`01_ingestion/`)
1. `01_create_file_formats.sql`
2. `02_create_stages.sql`
3. `03_create_raw_tables.sql`
4. **`05_generate_synthetic_data.sql`** — populates the RAW tables (no files needed).

> `04_load_data_examples.sql` is the **file-based alternative** (`COPY INTO` from staged
> CSVs). Use it only if you want to demonstrate real file ingestion — otherwise skip it in
> favour of the generator in step 4. Don't run both; each is a full load of RAW.

### Step 3 — Staging (`02_staging/`)
1. `01_create_staging_tables.sql`
2. `02_staging_transformations.sql` — casts, cleans, flags DQ. The end-of-file checks should
   show rows with **0 invalid** on the synthetic data.

### Step 4 — Core model (`03_core_model/`)
Run `01` → `02` → `03` → `04`. This generates `DIM_DATE`, derives `DIM_PLAYER` / `DIM_ACCOUNT`
from staging, seeds the other dimensions, and loads `FACT_TRANSACTIONS` and
`FACT_MARKET_PERFORMANCE`.

### Step 5 — Governance (`00_setup/04_governance_policies.sql`)
Now that CORE tables exist, run this as `ACCOUNTADMIN` to apply tags, the `MP_IDENTIFIER`
masking policy, the `RAP_REGION` row-access policy, and extended Time Travel. *(Optional but
recommended — it's part of the governance story.)*

### Step 6 — AML rules (`04_aml_rules/`)
Run `01` → `02` → `03`. `02` runs the 11 typologies over `FACT_TRANSACTIONS` into
`FACT_AML_ALERTS`; `03` applies scoring, severity, and escalation. The synthetic data is
shaped so **every rule fires** — the end-of-file summary lists alert counts per rule.

### Step 7 — STR workflow (`05_str_workflow/`)
Run `01` → `02`. Escalated alerts become `FACT_STR_CASES`; SLA logic sets priorities,
investigation days, and breach flags.

### Step 8 — Reporting views (`06_reporting/`)
Run `01`–`05` to create the 11 `REPORTING.VW_*` views that serve BI.

### Step 9 — Validate (`07_data_quality/`)
Run the DQ, reconciliation (`R1`–`R8`), and phase-validation scripts. These are **read-only
checks**; review their output rather than expecting a single pass/fail.

### Step 10 — Optional extras
- `08_automation/` — create the stream & (suspended) task. Leave the task suspended unless you
  want scheduled compute; see the folder README for cost cautions.
- `09_snowpark/` — run `aml_risk_scoring_example.py` from a Snowpark-enabled Python env; it
  connects **by named connection / environment variable**, never hard-coded credentials.

### Step 11 — Connect Power BI (`10_powerbi/`)
Follow [`../snowflake/10_powerbi/snowflake_powerbi_connection_guide.md`](../snowflake/10_powerbi/snowflake_powerbi_connection_guide.md):
connect Power BI Desktop with the `BI_REPORTING` role and `WH_REPORTING`, import the `VW_*`
views, and build the model/measures from the same folder.

---

## 4. Verify the build

Quick smoke test after Step 8 (run under a role that can read `REPORTING`):

```sql
USE WAREHOUSE WH_REPORTING;
SELECT * FROM GAMING_COMPLIANCE_DB.REPORTING.VW_EXECUTIVE_OVERVIEW;          -- one KPI row
SELECT * FROM GAMING_COMPLIANCE_DB.REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN;    -- 11 rules, all > 0
SELECT * FROM GAMING_COMPLIANCE_DB.REPORTING.VW_STR_WORKFLOW_SUMMARY;        -- cases + SLA
SELECT * FROM GAMING_COMPLIANCE_DB.REPORTING.VW_MARKET_FISCAL_YEAR;          -- FY GGR + YoY
```

Expected orders of magnitude on the default generator: **~5,300 transactions**, **36 market
months**, alerts across **all 11 typologies**, and a populated STR case backlog.

---

## 5. Idempotency & re-runs

- Table loads use `CREATE OR REPLACE` / `INSERT OVERWRITE`, so re-running a script rebuilds
  that object cleanly. To rebuild everything, re-run from `01_ingestion/05` downward.
- The generator is **deterministic** (fixed arithmetic on `SEQ4()`), so the same data is
  produced every time — reconciliation numbers are stable across rebuilds.

---

## 6. Cost management (trial-friendly)

- All warehouses are `XSMALL` with `AUTO_SUSPEND = 60s` and `AUTO_RESUME = TRUE` — you pay
  only while a query runs.
- The optional resource monitor (`RM_GAMING_COMPLIANCE`) caps credits if you enable it in
  `00_setup/01_create_warehouses.sql`.
- Keep the automation **task suspended** unless you're specifically demonstrating scheduled
  refresh — a running task consumes credits on its schedule.
- Use **Import** (not DirectQuery) in Power BI so the warehouse runs only on refresh.

---

## 7. Teardown

To remove everything (careful — irreversible):

```sql
USE ROLE ACCOUNTADMIN;
DROP DATABASE IF EXISTS GAMING_COMPLIANCE_DB;
DROP WAREHOUSE IF EXISTS WH_INGESTION;
DROP WAREHOUSE IF EXISTS WH_TRANSFORM;
DROP WAREHOUSE IF EXISTS WH_REPORTING;
DROP WAREHOUSE IF EXISTS WH_DATA_SCIENCE;
-- Optional: DROP ROLE for PLATFORM_OWNER, DATA_ENGINEER, COMPLIANCE_ANALYST,
--           COMPLIANCE_MANAGER, BI_REPORTING, READ_ONLY_AUDITOR;
```

Because RAW/STAGING tables are `TRANSIENT` and warehouses auto-suspend, an idle trial account
accrues effectively no compute cost even before teardown.

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Object ... does not exist` on a `USE SCHEMA` | Ran a layer out of order | Run folders 00 → 10 in sequence |
| `Insufficient privileges` | Custom role not granted to your user | `GRANT ROLE <role> TO USER <you>` (Step 1) |
| Reporting views empty | Ran views before loading facts / alerts | Re-run Steps 2–8 in order |
| Governance script errors on missing table | Ran `00_setup/04` before the core model | Run it after Step 4 |
| AML alerts missing a rule | Used a custom dataset without those patterns | Use the provided generator, or add matching rows |

---

> **Reminder:** this project has been authored and statically reviewed but not executed by the
> author against a live Snowflake account. When you run it, the end-of-file validation queries
> in each script are the source of truth — read their output. See
> [`portfolio_limitations.md`](portfolio_limitations.md).
