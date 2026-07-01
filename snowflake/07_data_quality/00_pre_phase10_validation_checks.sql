/* ============================================================================
   Pre-Phase-10 Validation Checkpoint  (run BEFORE relying on reporting views)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Confirms Phases 1-9 produced a model that the Phase 10 reporting views can sit
   on. Grouped by area. Each check returns CHECK_NAME, STATUS ('PASS'/'FAIL'/
   'REVIEW'), and a DETAIL value. Run the whole file in a Snowflake worksheet and
   scan the STATUS column.

   NOTE: This script must be EXECUTED in your own Snowflake account after loading
   the synthetic data — it is not run in this repo. Uses WH_TRANSFORM. SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ============================================================================
   A. REPOSITORY / OBJECT READINESS
   ============================================================================ */
-- A1: required schemas exist (expect 7)
SELECT 'A1 schemas exist' AS CHECK_NAME,
       IFF(COUNT(*) = 7, 'PASS', 'FAIL') AS STATUS,
       LISTAGG(SCHEMA_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('RAW','STAGING','CORE','ANALYTICS','REPORTING','GOVERNANCE','UTILITY');

-- A2: required CORE dimensions exist (expect 6)
SELECT 'A2 dimensions exist' AS CHECK_NAME,
       IFF(COUNT(*) = 6, 'PASS', 'FAIL') AS STATUS, LISTAGG(TABLE_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORE'
  AND TABLE_NAME IN ('DIM_DATE','DIM_PLAYER','DIM_ACCOUNT','DIM_ALERT_TYPE','DIM_STATUS','DIM_ANALYST');

-- A3: required CORE facts exist (expect 4)
SELECT 'A3 facts exist' AS CHECK_NAME,
       IFF(COUNT(*) = 4, 'PASS', 'FAIL') AS STATUS, LISTAGG(TABLE_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'CORE'
  AND TABLE_NAME IN ('FACT_TRANSACTIONS','FACT_AML_ALERTS','FACT_STR_CASES','FACT_MARKET_PERFORMANCE');

-- A4: RAW + STAGING landing tables exist
SELECT 'A4 raw/staging tables' AS CHECK_NAME,
       IFF(COUNT(*) >= 5, 'PASS', 'REVIEW') AS STATUS, LISTAGG(TABLE_SCHEMA||'.'||TABLE_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('RAW','STAGING') AND TABLE_NAME LIKE ANY ('RAW_%','STG_%');

/* ============================================================================
   B. CORE DATA-MODEL CHECKS (row presence)
   ============================================================================ */
SELECT 'B1 DIM_PLAYER rows'       AS CHECK_NAME, IFF(COUNT(*) > 0, 'PASS','FAIL') AS STATUS, COUNT(*) AS DETAIL FROM CORE.DIM_PLAYER
UNION ALL SELECT 'B2 DIM_ACCOUNT rows',        IFF(COUNT(*) > 0,'PASS','FAIL'), COUNT(*) FROM CORE.DIM_ACCOUNT
UNION ALL SELECT 'B3 FACT_TRANSACTIONS rows',  IFF(COUNT(*) > 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_TRANSACTIONS
UNION ALL SELECT 'B4 FACT_AML_ALERTS rows',    IFF(COUNT(*) > 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS
UNION ALL SELECT 'B5 FACT_MARKET_PERF rows',   IFF(COUNT(*) > 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE
UNION ALL SELECT 'B6 DIM_ALERT_TYPE seeded 11',IFF(COUNT(*) = 11,'PASS','FAIL'), COUNT(*) FROM CORE.DIM_ALERT_TYPE
UNION ALL SELECT 'B7 DIM_STATUS seeded 5',     IFF(COUNT(*) = 5,'PASS','FAIL'), COUNT(*) FROM CORE.DIM_STATUS;

-- B8: STR cases exist IFF escalated alerts exist (conditional presence)
SELECT 'B8 STR cases where escalated alerts exist' AS CHECK_NAME,
       IFF( (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED) = 0
              OR (SELECT COUNT(*) FROM CORE.FACT_STR_CASES) > 0, 'PASS', 'FAIL') AS STATUS,
       (SELECT COUNT(*) FROM CORE.FACT_STR_CASES) AS DETAIL;

/* ============================================================================
   C. RELATIONSHIP CHECKS (no orphans -> expect 0)
   ============================================================================ */
SELECT 'C1 txn -> valid player' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS ORPHANS
FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_PLAYER d ON d.PLAYER_KEY = f.PLAYER_KEY WHERE d.PLAYER_KEY IS NULL
UNION ALL
SELECT 'C2 txn -> valid account', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_ACCOUNT d ON d.ACCOUNT_KEY = f.ACCOUNT_KEY WHERE d.ACCOUNT_KEY IS NULL
UNION ALL
SELECT 'C3 alert -> valid transaction', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY = a.TRANSACTION_KEY WHERE t.TRANSACTION_KEY IS NULL
UNION ALL
SELECT 'C4 alert -> valid player', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.DIM_PLAYER d ON d.PLAYER_KEY = a.PLAYER_KEY WHERE d.PLAYER_KEY IS NULL
UNION ALL
SELECT 'C5 alert -> valid alert type', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.DIM_ALERT_TYPE d ON d.ALERT_TYPE_KEY = a.ALERT_TYPE_KEY WHERE d.ALERT_TYPE_KEY IS NULL
UNION ALL
SELECT 'C6 case -> valid alert', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY WHERE a.ALERT_KEY IS NULL
UNION ALL
SELECT 'C7 case -> valid player', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.DIM_PLAYER d ON d.PLAYER_KEY = c.PLAYER_KEY WHERE d.PLAYER_KEY IS NULL
UNION ALL
SELECT 'C8 case -> valid analyst', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.DIM_ANALYST d ON d.ANALYST_KEY = c.ANALYST_KEY WHERE d.ANALYST_KEY IS NULL
UNION ALL
SELECT 'C9 case/alert -> valid status', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.DIM_STATUS d ON d.STATUS_KEY = c.STATUS_KEY WHERE d.STATUS_KEY IS NULL;

/* ============================================================================
   D. BUSINESS-LOGIC CHECKS
   ============================================================================ */
SELECT 'D1 alerts have alert type'    AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS BAD_ROWS FROM CORE.FACT_AML_ALERTS WHERE ALERT_TYPE_KEY IS NULL
UNION ALL SELECT 'D2 alerts have risk score',     IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE RISK_SCORE IS NULL
UNION ALL SELECT 'D3 escalation flag populated',  IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED IS NULL
UNION ALL SELECT 'D4 SLA target populated',       IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_STR_CASES WHERE SLA_DAYS IS NULL
UNION ALL SELECT 'D5 investigation days set',     IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_STR_CASES WHERE INVESTIGATION_DAYS IS NULL
UNION ALL SELECT 'D6 SLA breach flag populated',  IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_STR_CASES WHERE SLA_BREACHED IS NULL
UNION ALL SELECT 'D7 STR submitted flag set',     IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_STR_CASES WHERE STR_SUBMITTED_FLAG IS NULL;

-- D8: STR cases only from escalated alerts (expect 0 cases sourced from non-escalated alerts)
SELECT 'D8 cases only from escalated alerts' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS BAD_ROWS
FROM CORE.FACT_STR_CASES c JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY
WHERE a.IS_ESCALATED = FALSE;

/* ============================================================================
   E. GRAIN & RECONCILIATION CHECKS
   ============================================================================ */
-- E1-E3: no duplicate business keys (expect 0)
SELECT 'E1 duplicate transaction ids' AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS DUPES
FROM (SELECT TRANSACTION_ID FROM CORE.FACT_TRANSACTIONS GROUP BY TRANSACTION_ID HAVING COUNT(*) > 1)
UNION ALL SELECT 'E2 duplicate alert ids', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM (SELECT ALERT_ID FROM CORE.FACT_AML_ALERTS GROUP BY ALERT_ID HAVING COUNT(*) > 1)
UNION ALL SELECT 'E3 duplicate case ids', IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM (SELECT CASE_ID FROM CORE.FACT_STR_CASES GROUP BY CASE_ID HAVING COUNT(*) > 1);

-- E4: market fact is monthly grain (one row per DATE_KEY)
SELECT 'E4 market monthly grain' AS CHECK_NAME,
       IFF(COUNT(*) = COUNT(DISTINCT DATE_KEY),'PASS','FAIL') AS STATUS,
       COUNT(*)||' rows / '||COUNT(DISTINCT DATE_KEY)||' months' AS DETAIL
FROM CORE.FACT_MARKET_PERFORMANCE;

-- E5: RAW -> STAGING -> CORE transaction row-count reconciliation (informational)
SELECT 'E5 txn row-count reconcile' AS CHECK_NAME,
       IFF( (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID)
              = (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS), 'PASS', 'REVIEW') AS STATUS,
       'RAW='||(SELECT COUNT(*) FROM RAW.RAW_TRANSACTIONS)
       ||' STG_valid='||(SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID)
       ||' CORE='||(SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS) AS DETAIL;

/* ============================================================================
   F. DATA-QUALITY CHECKS
   ============================================================================ */
SELECT 'F1 null transaction id'  AS CHECK_NAME, IFF(COUNT(*) = 0,'PASS','FAIL') AS STATUS, COUNT(*) AS BAD_ROWS FROM CORE.FACT_TRANSACTIONS WHERE TRANSACTION_ID IS NULL
UNION ALL SELECT 'F2 null player key on txn',   IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*) FROM CORE.FACT_TRANSACTIONS WHERE PLAYER_KEY IS NULL
UNION ALL SELECT 'F3 negative transaction amt', IFF(COUNT(*) = 0,'PASS','REVIEW'), COUNT(*) FROM CORE.FACT_TRANSACTIONS WHERE AMOUNT < 0
UNION ALL SELECT 'F4 invalid txn date_key',     IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_DATE d ON d.DATE_KEY = f.DATE_KEY WHERE d.DATE_KEY IS NULL
UNION ALL SELECT 'F5 cases without alerts',     IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY WHERE a.ALERT_KEY IS NULL
UNION ALL SELECT 'F6 alerts without txns',      IFF(COUNT(*) = 0,'PASS','FAIL'), COUNT(*)
FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY = a.TRANSACTION_KEY WHERE t.TRANSACTION_KEY IS NULL;

-- F7: no gaps in market months (continuity of YEAR_MONTH within the series)
SELECT 'F7 market month continuity' AS CHECK_NAME,
       IFF(MAX(GAP) IS NULL OR MAX(GAP) <= 1, 'PASS', 'REVIEW') AS STATUS,
       'max month gap = '||COALESCE(MAX(GAP), 0) AS DETAIL
FROM (
    SELECT DATEDIFF('month',
        LAG(TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) OVER (ORDER BY YEAR_MONTH),
        TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) AS GAP
    FROM CORE.FACT_MARKET_PERFORMANCE
);
