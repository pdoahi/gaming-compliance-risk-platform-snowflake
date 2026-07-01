/* ============================================================================
   Phase 4 — Setup 01: Virtual Warehouses
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Creates four workload-isolated, COST-AWARE virtual warehouses and an optional
   resource monitor. Run order: 01 (this) -> 02 (db/schemas) -> 03 (roles/grants).

   Cost control by design:
     - XSMALL by default (SMALL only for heavier transform runs, then scale back)
     - AUTO_SUSPEND = 60s  -> release compute quickly when idle
     - AUTO_RESUME = TRUE  -> spin up on demand
     - INITIALLY_SUSPENDED -> never bill for idle compute at creation
     - STATEMENT_TIMEOUT    -> guard against runaway queries
   Infrastructure uses CREATE ... IF NOT EXISTS (non-destructive & idempotent);
   data objects use CREATE OR REPLACE in later phases.

   NOTE: All data in this project is SYNTHETIC. No credentials or secrets appear
   in any script — you supply your own account context.
   ============================================================================ */

-- Warehouses are owned by SYSADMIN (standard Snowflake role hierarchy).
USE ROLE SYSADMIN;

/* ---- WH_INGESTION : COPY INTO loads into RAW (bursty, short-lived) --------- */
CREATE WAREHOUSE IF NOT EXISTS WH_INGESTION
    WAREHOUSE_SIZE               = 'XSMALL'
    AUTO_SUSPEND                 = 60
    AUTO_RESUME                  = TRUE
    INITIALLY_SUSPENDED          = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 3600
    COMMENT = 'Ingestion: file staging + COPY INTO RAW. Suspends between loads.';

/* ---- WH_TRANSFORM : STAGING/CORE/ANALYTICS ELT (main workhorse) ------------ */
CREATE WAREHOUSE IF NOT EXISTS WH_TRANSFORM
    WAREHOUSE_SIZE               = 'XSMALL'   -- scale to SMALL only for heavy runs (see ALTER below)
    AUTO_SUSPEND                 = 60
    AUTO_RESUME                  = TRUE
    INITIALLY_SUSPENDED          = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 3600
    COMMENT = 'Transform: STAGING, CORE model, AML/STR logic. Main ELT compute.';
-- Temporarily scale up for a heavy batch, then scale back down:
--   ALTER WAREHOUSE WH_TRANSFORM SET WAREHOUSE_SIZE = 'SMALL';
--   ALTER WAREHOUSE WH_TRANSFORM SET WAREHOUSE_SIZE = 'XSMALL';

/* ---- WH_REPORTING : reporting views / Power BI (read-mostly) --------------- */
CREATE WAREHOUSE IF NOT EXISTS WH_REPORTING
    WAREHOUSE_SIZE               = 'XSMALL'
    AUTO_SUSPEND                 = 60
    AUTO_RESUME                  = TRUE
    INITIALLY_SUSPENDED          = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 1800
    COMMENT = 'Reporting: REPORTING-schema views for Power BI / analysts. Multi-cluster is a future option if concurrency grows.';

/* ---- WH_DATA_SCIENCE : Snowpark / notebooks (optional, off by default) ----- */
CREATE WAREHOUSE IF NOT EXISTS WH_DATA_SCIENCE
    WAREHOUSE_SIZE               = 'XSMALL'
    AUTO_SUSPEND                 = 60
    AUTO_RESUME                  = TRUE
    INITIALLY_SUSPENDED          = TRUE
    STATEMENT_TIMEOUT_IN_SECONDS = 3600
    COMMENT = 'Data science: optional Snowpark risk-scoring / feature work (Phase 13).';

/* ---- OPTIONAL: account resource monitor (hard cost cap) --------------------
   Requires ACCOUNTADMIN. Caps monthly credits and suspends warehouses if the
   quota is exceeded. Tune CREDIT_QUOTA to your account; values here are a
   conservative demo cap. Comment out if you do not want a monitor.            */
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS RM_GAMING_COMPLIANCE
    WITH CREDIT_QUOTA    = 20            -- ~monthly demo budget (credits)
         FREQUENCY       = MONTHLY
         START_TIMESTAMP = IMMEDIATELY
         TRIGGERS ON 80  PERCENT DO NOTIFY
                  ON 100 PERCENT DO SUSPEND
                  ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE WH_INGESTION    SET RESOURCE_MONITOR = RM_GAMING_COMPLIANCE;
ALTER WAREHOUSE WH_TRANSFORM    SET RESOURCE_MONITOR = RM_GAMING_COMPLIANCE;
ALTER WAREHOUSE WH_REPORTING    SET RESOURCE_MONITOR = RM_GAMING_COMPLIANCE;
ALTER WAREHOUSE WH_DATA_SCIENCE SET RESOURCE_MONITOR = RM_GAMING_COMPLIANCE;

-- Return to a safe default role for the next script.
USE ROLE SYSADMIN;

SHOW WAREHOUSES LIKE 'WH_%';
