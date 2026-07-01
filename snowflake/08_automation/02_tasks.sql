/* ============================================================================
   Phase 13 — Automation 02: Tasks (OPTIONAL)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   *** OPTIONAL layer. *** Tasks run SQL on a schedule (or on demand). Paired with
   the stream from 01, a task can process only new transactions — scheduled,
   hands-off incremental AML alerting.

   💲 COST NOTE: each task RUN uses a warehouse and bills compute. To stay cheap:
     - gate on WHEN SYSTEM$STREAM_HAS_DATA(...) so empty runs cost nothing,
     - use an infrequent SCHEDULE,
     - keep the warehouse XSMALL with AUTO_SUSPEND,
     - tasks are created SUSPENDED — only RESUME when you actually want them running,
       and SUSPEND again when done.

   Creating tasks needs CREATE TASK (granted to DATA_ENGINEER); RESUME needs the
   account-level EXECUTE TASK privilege (grant via ACCOUNTADMIN). SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA ANALYTICS;

/* ---- Task: incremental alert generation from the stream ------------------- */
CREATE OR REPLACE TASK ANALYTICS.TSK_INCREMENTAL_ALERTS
    WAREHOUSE = WH_TRANSFORM
    SCHEDULE  = 'USING CRON 0 * * * * UTC'          -- hourly; tune to your needs
    WHEN SYSTEM$STREAM_HAS_DATA('CORE.STRM_NEW_TRANSACTIONS')   -- skip (free) when no new data
    COMMENT = 'OPTIONAL: incrementally flags large new transactions. Suspended by default.'
AS
    INSERT INTO CORE.FACT_AML_ALERTS
        (ALERT_ID, TRANSACTION_KEY, ALERT_TYPE_KEY, PLAYER_KEY, ACCOUNT_KEY, DATE_KEY,
         STATUS_KEY, ALERT_TIMESTAMP, SEVERITY, RISK_SCORE, IS_ESCALATED,
         ALERT_DESCRIPTION, SOURCE_SYSTEM, LOAD_BATCH_ID)
    SELECT
        'ALRT-' || LPAD(s.TRANSACTION_KEY, 9, '0') || '-R01',
        s.TRANSACTION_KEY, 1, s.PLAYER_KEY, s.ACCOUNT_KEY, s.DATE_KEY,
        1, s.TRANSACTION_TIMESTAMP, 'High', 70, FALSE,
        'R01: Large Transaction (incremental)', 'AML_ENGINE_STREAM', s.LOAD_BATCH_ID
    FROM CORE.STRM_NEW_TRANSACTIONS s
    WHERE s.METADATA$ACTION = 'INSERT' AND s.AMOUNT >= 10000;

/* ---- Enable / disable (opt-in) -------------------------------------------- */
-- Tasks are created SUSPENDED. To run it you must resume it (needs EXECUTE TASK):
--   USE ROLE ACCOUNTADMIN;
--   GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ENGINEER;   -- one-time
--   USE ROLE DATA_ENGINEER;
--   ALTER TASK ANALYTICS.TSK_INCREMENTAL_ALERTS RESUME;
-- Stop billing when you're done:
--   ALTER TASK ANALYTICS.TSK_INCREMENTAL_ALERTS SUSPEND;
-- Run once immediately (for testing):
--   EXECUTE TASK ANALYTICS.TSK_INCREMENTAL_ALERTS;

SHOW TASKS IN SCHEMA ANALYTICS;
