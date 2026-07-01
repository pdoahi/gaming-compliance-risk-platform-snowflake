/* ============================================================================
   Phase 11 — Data Quality 01: Standing DQ Check Suite
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   The reusable data-quality suite covering every layer: STAGING, CORE, AML, STR,
   MARKET, REPORTING. Each check returns LAYER, CHECK_NAME, STATUS ('PASS'/'FAIL'/
   'REVIEW'), and a DETAIL value. Run in a worksheet and scan STATUS.

   NOTE: Author-only in this repo — must be EXECUTED in your Snowflake account after
   loading the synthetic data. Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- STAGING: rows that failed staging DQ (kept + flagged, not dropped) ---- */
SELECT 'STAGING' AS LAYER, 'staging invalid rows' AS CHECK_NAME,
       IFF(SUM(IFF(IS_VALID, 0, 1)) = 0, 'PASS', 'REVIEW') AS STATUS,
       SUM(IFF(IS_VALID, 0, 1))||' invalid of '||COUNT(*) AS DETAIL
FROM STAGING.STG_TRANSACTIONS;

-- Breakdown of any staging DQ issues (informational).
SELECT 'STAGING' AS LAYER, 'staging DQ issue breakdown' AS CHECK_NAME, DQ_ISSUES, COUNT(*) AS ROWS
FROM STAGING.STG_TRANSACTIONS WHERE NOT IS_VALID GROUP BY DQ_ISSUES ORDER BY ROWS DESC;

/* ---- CORE: keys, duplicates, amounts, dates, relationships ---------------- */
SELECT 'CORE' AS LAYER, 'C dup transaction ids' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS DETAIL
FROM (SELECT TRANSACTION_ID FROM CORE.FACT_TRANSACTIONS GROUP BY TRANSACTION_ID HAVING COUNT(*) > 1)
UNION ALL SELECT 'CORE','C null player id on txn', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_TRANSACTIONS WHERE PLAYER_KEY IS NULL
UNION ALL SELECT 'CORE','C missing account relationship', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_ACCOUNT a ON a.ACCOUNT_KEY = f.ACCOUNT_KEY WHERE a.ACCOUNT_KEY IS NULL
UNION ALL SELECT 'CORE','C negative transaction amount', IFF(COUNT(*) = 0,'PASS','REVIEW'), COUNT(*) FROM CORE.FACT_TRANSACTIONS WHERE AMOUNT < 0
UNION ALL SELECT 'CORE','C invalid txn date key', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_DATE d ON d.DATE_KEY = f.DATE_KEY WHERE d.DATE_KEY IS NULL;

/* ---- AML: alert integrity ------------------------------------------------- */
SELECT 'AML' AS LAYER, 'C dup alert ids' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS DETAIL
FROM (SELECT ALERT_ID FROM CORE.FACT_AML_ALERTS GROUP BY ALERT_ID HAVING COUNT(*) > 1)
UNION ALL SELECT 'AML','alerts without transactions', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY = a.TRANSACTION_KEY WHERE t.TRANSACTION_KEY IS NULL
UNION ALL SELECT 'AML','alerts null risk score', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE RISK_SCORE IS NULL
UNION ALL SELECT 'AML','alerts null alert type', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE ALERT_TYPE_KEY IS NULL
UNION ALL SELECT 'AML','escalation flag populated', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED IS NULL;

/* ---- STR: case integrity + SLA logic -------------------------------------- */
SELECT 'STR' AS LAYER, 'C dup case ids' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS DETAIL
FROM (SELECT CASE_ID FROM CORE.FACT_STR_CASES GROUP BY CASE_ID HAVING COUNT(*) > 1)
UNION ALL SELECT 'STR','STR cases without alerts', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY WHERE a.ALERT_KEY IS NULL
UNION ALL SELECT 'STR','invalid case duration (<0 or close<open)', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_STR_CASES WHERE INVESTIGATION_DAYS < 0 OR (CLOSE_DATE_KEY IS NOT NULL AND CLOSE_DATE_KEY < OPEN_DATE_KEY)
UNION ALL SELECT 'STR','SLA logic consistent', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_STR_CASES WHERE SLA_BREACHED <> (INVESTIGATION_DAYS > SLA_DAYS)
UNION ALL SELECT 'STR','STR submitted flag populated', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_STR_CASES WHERE STR_SUBMITTED_FLAG IS NULL;

/* ---- MARKET: continuity + sign -------------------------------------------- */
SELECT 'MARKET' AS LAYER, 'market months missing (gap>1)' AS CHECK_NAME,
       IFF(MAX(GAP) IS NULL OR MAX(GAP) <= 1,'PASS','REVIEW') AS STATUS, 'max gap = '||COALESCE(MAX(GAP),0) AS DETAIL
FROM (SELECT DATEDIFF('month', LAG(TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) OVER (ORDER BY YEAR_MONTH),
                      TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) AS GAP FROM CORE.FACT_MARKET_PERFORMANCE)
UNION ALL SELECT 'MARKET','negative wagers/GGR', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
    FROM CORE.FACT_MARKET_PERFORMANCE WHERE TOTAL_WAGERS < 0 OR TOTAL_GGR < 0;

/* ---- REPORTING: view availability ----------------------------------------- */
SELECT 'REPORTING' AS LAYER, 'reporting views present (>=11)' AS CHECK_NAME,
       IFF(COUNT(*) >= 11,'PASS','FAIL') AS STATUS, COUNT(*)||' views' AS DETAIL
FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA = 'REPORTING' AND TABLE_NAME LIKE 'VW_%';
