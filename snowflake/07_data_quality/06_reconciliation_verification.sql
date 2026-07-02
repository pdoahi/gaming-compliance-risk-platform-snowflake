/* ============================================================================
   Reconciliation Verification — one-shot, single-grid consolidation
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Consolidates the R1–R8 reconciliations (02_reconciliation_queries.sql) and the
   key integrity checks (01_data_quality_checks.sql) into ONE result grid of
   labelled checks with ACTUAL and STATUS — so the whole validation framework can
   be run and reviewed (and pasted) in a single query.

   Reads only; changes nothing. Role DATA_ENGINEER, warehouse WH_TRANSFORM.
   Run AFTER the platform is built and loaded. Every row should be PASS
   (occasional REVIEW is acceptable and explained in docs/validation_framework.md).
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

WITH m AS (
    SELECT
        (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS)                     AS stg_total,
        (SELECT COUNT(*) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID)      AS stg_valid,
        (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS)                       AS core_txn,
        (SELECT ROUND(SUM(AMOUNT),2) FROM STAGING.STG_TRANSACTIONS WHERE IS_VALID) AS stg_value,
        (SELECT ROUND(SUM(AMOUNT),2) FROM CORE.FACT_TRANSACTIONS)           AS core_value,
        (SELECT COUNT(*) FROM STAGING.STG_MARKET_PERFORMANCE WHERE IS_VALID) AS stg_mkt,
        (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE)                 AS core_mkt,
        (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)                         AS core_alerts,
        (SELECT TOTAL_ALERTS FROM REPORTING.VW_AML_MONITORING_SUMMARY)      AS view_alerts,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)                          AS core_cases,
        (SELECT TOTAL_CASES FROM REPORTING.VW_STR_WORKFLOW_SUMMARY)         AS view_cases,
        (SELECT ROUND(SUM(TOTAL_GGR),0) FROM CORE.FACT_MARKET_PERFORMANCE)  AS core_ggr,
        (SELECT ROUND(SUM(TOTAL_GGR),0) FROM REPORTING.VW_MARKET_PERFORMANCE) AS view_ggr,
        (SELECT COUNT(DISTINCT TRANSACTION_KEY) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED) AS esc_txns,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES c JOIN CORE.FACT_AML_ALERTS a
                ON a.ALERT_KEY = c.ALERT_KEY WHERE a.IS_ESCALATED = FALSE)  AS cases_non_esc,
        (SELECT TOTAL_TRANSACTIONS FROM REPORTING.VW_EXECUTIVE_OVERVIEW)    AS exec_txn,
        (SELECT AML_ALERTS FROM REPORTING.VW_EXECUTIVE_OVERVIEW)            AS exec_alerts,
        (SELECT TOTAL_CASES FROM REPORTING.VW_EXECUTIVE_OVERVIEW)           AS exec_cases,
        (SELECT COUNT(*) FROM (SELECT TRANSACTION_ID FROM CORE.FACT_TRANSACTIONS GROUP BY TRANSACTION_ID HAVING COUNT(*)>1)) AS dup_txn,
        (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS WHERE PLAYER_KEY IS NULL) AS null_player,
        (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS f LEFT JOIN CORE.DIM_DATE d ON d.DATE_KEY=f.DATE_KEY WHERE d.DATE_KEY IS NULL) AS bad_date,
        (SELECT COUNT(*) FROM (SELECT ALERT_ID FROM CORE.FACT_AML_ALERTS GROUP BY ALERT_ID HAVING COUNT(*)>1)) AS dup_alert,
        (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS a LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY=a.TRANSACTION_KEY WHERE t.TRANSACTION_KEY IS NULL) AS orphan_alert,
        (SELECT COUNT(*) FROM (SELECT CASE_ID FROM CORE.FACT_STR_CASES GROUP BY CASE_ID HAVING COUNT(*)>1)) AS dup_case,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES c LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY=c.ALERT_KEY WHERE a.ALERT_KEY IS NULL) AS case_no_alert,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES WHERE INVESTIGATION_DAYS<0 OR (CLOSE_DATE_KEY IS NOT NULL AND CLOSE_DATE_KEY<OPEN_DATE_KEY)) AS bad_dur,
        (SELECT COUNT(*) FROM CORE.FACT_STR_CASES WHERE SLA_BREACHED <> (INVESTIGATION_DAYS > SLA_DAYS)) AS sla_incon,
        (SELECT COALESCE(MAX(GAP),0) FROM (SELECT DATEDIFF('month',
                LAG(TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) OVER (ORDER BY YEAR_MONTH),
                TO_DATE(YEAR_MONTH||'-01','YYYY-MM-DD')) AS GAP FROM CORE.FACT_MARKET_PERFORMANCE)) AS mkt_gap,
        (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE WHERE TOTAL_WAGERS<0 OR TOTAL_GGR<0) AS mkt_neg,
        (SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA='REPORTING' AND TABLE_NAME LIKE 'VW_%') AS rpt_views
)
SELECT ORD, CATEGORY, CHECK_NAME, ACTUAL, STATUS FROM (
    SELECT 1 AS ORD,'Recon' AS CATEGORY,'R1 txn STG_valid = CORE' AS CHECK_NAME, stg_valid||' = '||core_txn AS ACTUAL, IFF(stg_valid=core_txn,'PASS','REVIEW') AS STATUS FROM m
    UNION ALL SELECT 2,'Recon','R2 market STG_valid = CORE', stg_mkt||' = '||core_mkt, IFF(stg_mkt=core_mkt,'PASS','REVIEW') FROM m
    UNION ALL SELECT 3,'Recon','R3 txn value STG = CORE', TO_VARCHAR(stg_value)||' = '||TO_VARCHAR(core_value), IFF(stg_value=core_value,'PASS','REVIEW') FROM m
    UNION ALL SELECT 4,'Recon','R4 alerts CORE = AML view', core_alerts||' = '||view_alerts, IFF(core_alerts=view_alerts,'PASS','FAIL') FROM m
    UNION ALL SELECT 5,'Recon','R5 cases CORE = STR view', core_cases||' = '||view_cases, IFF(core_cases=view_cases,'PASS','FAIL') FROM m
    UNION ALL SELECT 6,'Recon','R6 GGR CORE = market view', TO_VARCHAR(core_ggr)||' = '||TO_VARCHAR(view_ggr), IFF(core_ggr=view_ggr,'PASS','FAIL') FROM m
    UNION ALL SELECT 7,'Recon','R7 cases<=esc txns & 0 non-esc', core_cases||' <= '||esc_txns||' ; non-esc='||cases_non_esc, IFF(cases_non_esc=0 AND core_cases<=esc_txns,'PASS','FAIL') FROM m
    UNION ALL SELECT 8,'Recon','R8 exec view ties to facts', 'txn '||exec_txn||'/'||core_txn||' alert '||exec_alerts||'/'||core_alerts||' case '||exec_cases||'/'||core_cases, IFF(exec_txn=core_txn AND exec_alerts=core_alerts AND exec_cases=core_cases,'PASS','FAIL') FROM m
    UNION ALL SELECT 9,'DQ','Staging invalid rows', TO_VARCHAR(stg_total-stg_valid), IFF(stg_total=stg_valid,'PASS','REVIEW') FROM m
    UNION ALL SELECT 10,'DQ','Dup transaction ids', TO_VARCHAR(dup_txn), IFF(dup_txn=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 11,'DQ','Null player key on txn', TO_VARCHAR(null_player), IFF(null_player=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 12,'DQ','Txn orphan date key', TO_VARCHAR(bad_date), IFF(bad_date=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 13,'DQ','Dup alert ids', TO_VARCHAR(dup_alert), IFF(dup_alert=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 14,'DQ','Alerts without transactions', TO_VARCHAR(orphan_alert), IFF(orphan_alert=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 15,'DQ','Dup case ids', TO_VARCHAR(dup_case), IFF(dup_case=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 16,'DQ','Cases without alerts', TO_VARCHAR(case_no_alert), IFF(case_no_alert=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 17,'DQ','Invalid case duration', TO_VARCHAR(bad_dur), IFF(bad_dur=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 18,'DQ','SLA logic consistent (violations)', TO_VARCHAR(sla_incon), IFF(sla_incon=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 19,'DQ','Market month gaps (max)', TO_VARCHAR(mkt_gap), IFF(mkt_gap<=1,'PASS','REVIEW') FROM m
    UNION ALL SELECT 20,'DQ','Market negative wagers/GGR', TO_VARCHAR(mkt_neg), IFF(mkt_neg=0,'PASS','FAIL') FROM m
    UNION ALL SELECT 21,'DQ','Reporting views present', TO_VARCHAR(rpt_views)||' views', IFF(rpt_views>=11,'PASS','FAIL') FROM m
)
ORDER BY ORD;
