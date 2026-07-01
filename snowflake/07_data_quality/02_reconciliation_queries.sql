/* ============================================================================
   Phase 11 — Data Quality 02: Reconciliation Queries
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Confirms data flows through the layers without unexpected loss or inflation:
   RAW -> STAGING -> CORE -> AML -> STR -> REPORTING. Each query shows the counts/
   values side by side with a STATUS. Easy to run: one worksheet, top to bottom.

   NOTE: Must be EXECUTED in your Snowflake account. Uses WH_TRANSFORM. SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- R1: Transaction row counts across layers ----------------------------- */
-- Expect: RAW >= STG_total; STG_valid = CORE (invalid rows are flagged out of CORE).
SELECT 'R1 transactions RAW->STAGING->CORE' AS RECONCILIATION,
       (SELECT COUNT(*) FROM RAW.RAW_TRANSACTIONS)                         AS RAW_ROWS,
       (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS)                     AS STG_ROWS,
       (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID)      AS STG_VALID,
       (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS)                       AS CORE_ROWS,
       IFF( (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID)
            = (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS), 'PASS', 'REVIEW') AS STATUS;

/* ---- R2: Market row counts across layers ---------------------------------- */
SELECT 'R2 market RAW->STAGING->CORE' AS RECONCILIATION,
       (SELECT COUNT(*) FROM RAW.RAW_MARKET_PERFORMANCE)                    AS RAW_ROWS,
       (SELECT COUNT(*) FROM STAGING.STG_MARKET_PERFORMANCE WHERE IS_VALID) AS STG_VALID,
       (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE)                  AS CORE_ROWS,
       IFF( (SELECT COUNT(*) FROM STAGING.STG_MARKET_PERFORMANCE WHERE IS_VALID)
            = (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE), 'PASS', 'REVIEW') AS STATUS;

/* ---- R3: Transaction value reconciliation (STAGING valid vs CORE) ---------- */
SELECT 'R3 transaction value STAGING vs CORE' AS RECONCILIATION,
       ROUND((SELECT SUM(AMOUNT) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID), 2) AS STG_VALUE,
       ROUND((SELECT SUM(AMOUNT) FROM CORE.FACT_TRANSACTIONS), 2)                  AS CORE_VALUE,
       IFF( ROUND((SELECT SUM(AMOUNT) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID), 2)
            = ROUND((SELECT SUM(AMOUNT) FROM CORE.FACT_TRANSACTIONS), 2), 'PASS', 'REVIEW') AS STATUS;

/* ---- R4: AML alerts CORE vs reporting view -------------------------------- */
SELECT 'R4 AML alerts CORE vs VW_AML_MONITORING_SUMMARY' AS RECONCILIATION,
       (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)                          AS CORE_ALERTS,
       (SELECT TOTAL_ALERTS FROM REPORTING.VW_AML_MONITORING_SUMMARY)       AS VIEW_ALERTS,
       IFF( (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)
            = (SELECT TOTAL_ALERTS FROM REPORTING.VW_AML_MONITORING_SUMMARY), 'PASS', 'FAIL') AS STATUS;

/* ---- R5: STR cases CORE vs reporting view --------------------------------- */
SELECT 'R5 STR cases CORE vs VW_STR_WORKFLOW_SUMMARY' AS RECONCILIATION,
       (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)                           AS CORE_CASES,
       (SELECT TOTAL_CASES FROM REPORTING.VW_STR_WORKFLOW_SUMMARY)          AS VIEW_CASES,
       IFF( (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)
            = (SELECT TOTAL_CASES FROM REPORTING.VW_STR_WORKFLOW_SUMMARY), 'PASS', 'FAIL') AS STATUS;

/* ---- R6: Market GGR CORE vs reporting view -------------------------------- */
SELECT 'R6 market GGR CORE vs VW_MARKET_PERFORMANCE' AS RECONCILIATION,
       ROUND((SELECT SUM(TOTAL_GGR) FROM CORE.FACT_MARKET_PERFORMANCE), 0)  AS CORE_GGR,
       ROUND((SELECT SUM(TOTAL_GGR) FROM REPORTING.VW_MARKET_PERFORMANCE), 0) AS VIEW_GGR,
       IFF( ROUND((SELECT SUM(TOTAL_GGR) FROM CORE.FACT_MARKET_PERFORMANCE), 0)
            = ROUND((SELECT SUM(TOTAL_GGR) FROM REPORTING.VW_MARKET_PERFORMANCE), 0), 'PASS', 'FAIL') AS STATUS;

/* ---- R7: STR cases originate only from escalated alerts ------------------- */
-- Cases <= distinct escalated transactions; and 0 cases from non-escalated alerts.
SELECT 'R7 cases vs escalated alerts' AS RECONCILIATION,
       (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)                           AS TOTAL_CASES,
       (SELECT COUNT(DISTINCT TRANSACTION_KEY) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED) AS ESCALATED_TXNS,
       (SELECT COUNT(*) FROM CORE.FACT_STR_CASES c JOIN CORE.FACT_AML_ALERTS a
               ON a.ALERT_KEY = c.ALERT_KEY WHERE a.IS_ESCALATED = FALSE)   AS CASES_FROM_NON_ESCALATED,
       IFF( (SELECT COUNT(*) FROM CORE.FACT_STR_CASES c JOIN CORE.FACT_AML_ALERTS a
                    ON a.ALERT_KEY = c.ALERT_KEY WHERE a.IS_ESCALATED = FALSE) = 0
            AND (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)
                <= (SELECT COUNT(DISTINCT TRANSACTION_KEY) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED),
            'PASS', 'FAIL') AS STATUS;

/* ---- R8: Executive one-row view ties to the facts ------------------------- */
SELECT 'R8 executive view vs facts' AS RECONCILIATION,
       IFF( (SELECT TOTAL_TRANSACTIONS FROM REPORTING.VW_EXECUTIVE_OVERVIEW) = (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS)
        AND (SELECT AML_ALERTS         FROM REPORTING.VW_EXECUTIVE_OVERVIEW) = (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)
        AND (SELECT TOTAL_CASES        FROM REPORTING.VW_EXECUTIVE_OVERVIEW) = (SELECT COUNT(*) FROM CORE.FACT_STR_CASES),
            'PASS', 'FAIL') AS STATUS,
       'txn/alert/case totals reconcile' AS DETAIL;
