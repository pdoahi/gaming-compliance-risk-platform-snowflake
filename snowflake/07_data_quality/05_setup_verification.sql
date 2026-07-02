/* ============================================================================
   Setup Verification — one-shot post-build health check
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Run this AFTER building the platform (00_setup -> 06_reporting, using the
   01_ingestion/05 synthetic data generator). It returns ONE result grid of
   labelled checks with ACTUAL vs EXPECTED and a PASS/CHECK/FAIL status, so the
   whole build can be verified at a glance (and pasted for review).

   Reads only; changes nothing. Role DATA_ENGINEER, warehouse WH_REPORTING.

   Watch two rows especially (they prove the Phase-15 generator fixes ran):
     - "FACT_MARKET_PERFORMANCE months"  -> must be 36  (0 = old FISCAL bug)
     - "AML typologies firing"           -> must be 11  (10 = old R10 bug)
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_REPORTING;
USE DATABASE GAMING_COMPLIANCE_DB;

WITH c AS (
    SELECT
        (SELECT COUNT(*) FROM GAMING_COMPLIANCE_DB.INFORMATION_SCHEMA.SCHEMATA
           WHERE SCHEMA_NAME IN ('RAW','STAGING','CORE','ANALYTICS','REPORTING','GOVERNANCE','UTILITY')) AS schemas,
        (SELECT COUNT(*) FROM RAW.RAW_TRANSACTIONS)                       AS raw_txn,
        (SELECT COALESCE(SUM(IFF(IS_VALID, 0, 1)), 0)
           FROM STAGING.STG_TRANSACTIONS)                                 AS stg_invalid,
        (SELECT COUNT(*) FROM CORE.DIM_DATE)                              AS dim_date,
        (SELECT COUNT(*) FROM CORE.DIM_PLAYER)                            AS dim_player,
        (SELECT COUNT(*) FROM CORE.DIM_ACCOUNT)                           AS dim_account,
        (SELECT COUNT(*) FROM CORE.DIM_ALERT_TYPE)                        AS dim_alert_type,
        (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS)                     AS fact_txn,
        (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE)               AS fact_mkt,
        (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)                       AS fact_alerts,
        (SELECT COUNT(DISTINCT ALERT_TYPE_KEY) FROM CORE.FACT_AML_ALERTS) AS typologies,
        (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED)    AS escalated,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)                        AS fact_str,
        (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS a
           LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY = a.TRANSACTION_KEY
           WHERE t.TRANSACTION_KEY IS NULL)                               AS orphan_alerts,
        (SELECT COUNT(*) FROM REPORTING.VW_EXECUTIVE_OVERVIEW)            AS vw_exec,
        (SELECT COUNT(*) FROM REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN)      AS vw_typology,
        (SELECT COUNT(*) FROM REPORTING.VW_STR_WORKFLOW_SUMMARY)          AS vw_str,
        (SELECT COUNT(*) FROM REPORTING.VW_MARKET_PERFORMANCE)            AS vw_mkt
)
SELECT ORD, CHECK_NAME, ACTUAL, EXPECTED, STATUS
FROM (
    SELECT 1  AS ORD, 'Schemas present'                      AS CHECK_NAME, TO_VARCHAR(schemas)        AS ACTUAL, '7'        AS EXPECTED, IFF(schemas = 7,        'PASS', 'CHECK') AS STATUS FROM c
    UNION ALL SELECT 2,  'RAW_TRANSACTIONS rows',            TO_VARCHAR(raw_txn),        '~5,300', IFF(raw_txn      > 4000, 'PASS', 'CHECK') FROM c
    UNION ALL SELECT 3,  'STAGING invalid rows (want 0)',    TO_VARCHAR(stg_invalid),    '0',      IFF(stg_invalid  = 0,    'PASS', 'REVIEW') FROM c
    UNION ALL SELECT 4,  'DIM_DATE rows',                    TO_VARCHAR(dim_date),       '2922',   IFF(dim_date     > 2900, 'PASS', 'CHECK') FROM c
    UNION ALL SELECT 5,  'DIM_PLAYER rows',                  TO_VARCHAR(dim_player),     '~400',   IFF(dim_player BETWEEN 300 AND 450, 'PASS', 'CHECK') FROM c
    UNION ALL SELECT 6,  'DIM_ACCOUNT rows',                 TO_VARCHAR(dim_account),    '~400',   IFF(dim_account BETWEEN 300 AND 450, 'PASS', 'CHECK') FROM c
    UNION ALL SELECT 7,  'DIM_ALERT_TYPE rows',              TO_VARCHAR(dim_alert_type), '11',     IFF(dim_alert_type = 11, 'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 8,  'FACT_TRANSACTIONS rows',           TO_VARCHAR(fact_txn),       '~5,300', IFF(fact_txn     > 4000, 'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 9,  'FACT_MARKET_PERFORMANCE months',   TO_VARCHAR(fact_mkt),       '36',     IFF(fact_mkt     = 36,   'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 10, 'FACT_AML_ALERTS rows',             TO_VARCHAR(fact_alerts),    '> 0',    IFF(fact_alerts  > 0,    'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 11, 'AML typologies firing (distinct)', TO_VARCHAR(typologies),     '11',     IFF(typologies   = 11,   'PASS', 'REVIEW') FROM c
    UNION ALL SELECT 12, 'Escalated alerts',                 TO_VARCHAR(escalated),      '> 0',    IFF(escalated    > 0,    'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 13, 'FACT_STR_CASES rows',              TO_VARCHAR(fact_str),       '> 0',    IFF(fact_str     > 0,    'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 14, 'Orphan alerts (want 0)',           TO_VARCHAR(orphan_alerts),  '0',      IFF(orphan_alerts = 0,   'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 15, 'VW_EXECUTIVE_OVERVIEW rows',       TO_VARCHAR(vw_exec),        '1',      IFF(vw_exec      = 1,    'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 16, 'VW_ALERT_TYPOLOGY_BREAKDOWN rows', TO_VARCHAR(vw_typology),    '11',     IFF(vw_typology  = 11,   'PASS', 'CHECK') FROM c
    UNION ALL SELECT 17, 'VW_STR_WORKFLOW_SUMMARY rows',     TO_VARCHAR(vw_str),         '1',      IFF(vw_str       = 1,    'PASS', 'FAIL')  FROM c
    UNION ALL SELECT 18, 'VW_MARKET_PERFORMANCE rows',       TO_VARCHAR(vw_mkt),         '36',     IFF(vw_mkt       = 36,   'PASS', 'FAIL')  FROM c
)
ORDER BY ORD;
