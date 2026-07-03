/* ============================================================================
   Phase 13 — Automation 01: Streams (OPTIONAL)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   *** OPTIONAL layer. *** Streams enable INCREMENTAL processing — a stream tracks
   the rows added to a table since it was last consumed, so downstream steps only
   touch new data (cheaper than reprocessing everything).

   Example: a stream over FACT_TRANSACTIONS so AML rules can run only on NEW
   transactions instead of the whole table.

   COST NOTE: streams themselves are (almost) free — they store offsets, not
   data — but the TASKS that consume them (02_tasks.sql) use a warehouse. Keep the
   consuming task infrequent and gated on SYSTEM$STREAM_HAS_DATA.

   Run after the core model. Uses WH_TRANSFORM. SYNTHETIC data; no secrets.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- Stream on new transactions (append-only view of inserts) ------------- */
CREATE OR REPLACE STREAM CORE.STRM_NEW_TRANSACTIONS
    ON TABLE CORE.FACT_TRANSACTIONS
    APPEND_ONLY = TRUE
    COMMENT = 'Captures newly inserted transactions for incremental AML processing.';

/* ---- Inspect what the stream currently holds ------------------------------ */
-- Only rows inserted since the last time a DML consumed this stream.
SELECT TRANSACTION_KEY, PLAYER_KEY, ACCOUNT_KEY, AMOUNT, TRANSACTION_TYPE, METADATA$ACTION
FROM CORE.STRM_NEW_TRANSACTIONS
WHERE METADATA$ACTION = 'INSERT';

-- Is there anything to process? (used by the task's WHEN clause)
SELECT SYSTEM$STREAM_HAS_DATA('CORE.STRM_NEW_TRANSACTIONS') AS STREAM_HAS_DATA;

/* ---- Illustrative incremental alert generation (R01 large txn) -------------
   Consuming the stream in a DML statement advances its offset (rows won't be
   seen again). This inserts alerts ONLY for new transactions >= 10,000 — the
   incremental version of the full-table generator in 04_aml_rules/02.          */
-- INSERT INTO CORE.FACT_AML_ALERTS
--     (ALERT_ID, TRANSACTION_KEY, ALERT_TYPE_KEY, PLAYER_KEY, ACCOUNT_KEY, DATE_KEY,
--      STATUS_KEY, ALERT_TIMESTAMP, SEVERITY, RISK_SCORE, IS_ESCALATED,
--      ALERT_DESCRIPTION, SOURCE_SYSTEM, LOAD_BATCH_ID)
-- SELECT
--     'ALRT-' || LPAD(s.TRANSACTION_KEY, 9, '0') || '-R01',
--     s.TRANSACTION_KEY, 1, s.PLAYER_KEY, s.ACCOUNT_KEY, s.DATE_KEY,
--     1, s.TRANSACTION_TIMESTAMP, 'High', 70, FALSE,
--     'R01: Large Transaction (incremental)', 'AML_ENGINE_STREAM', s.LOAD_BATCH_ID
-- FROM CORE.STRM_NEW_TRANSACTIONS s
-- WHERE s.METADATA$ACTION = 'INSERT' AND s.AMOUNT >= 10000;

SHOW STREAMS IN SCHEMA CORE;
