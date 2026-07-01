/* ============================================================================
   Phase 10 — Reporting 05: Player Risk Views
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Per-player risk profile (REPORTING). Transaction, alert, and case metrics are
   each pre-aggregated to PLAYER grain in separate CTEs, THEN left-joined to
   DIM_PLAYER — so there is no fan-out / grain duplication (joining the raw facts
   directly would multiply rows). Read by COMPLIANCE_ANALYST / MANAGER. SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA REPORTING;

/* ---- VW_PLAYER_RISK_PROFILE : one row per player -------------------------- */
CREATE OR REPLACE VIEW REPORTING.VW_PLAYER_RISK_PROFILE AS
WITH tx AS (
    SELECT PLAYER_KEY, COUNT(*) AS TXN_COUNT, SUM(AMOUNT) AS TXN_VOLUME
    FROM CORE.FACT_TRANSACTIONS GROUP BY PLAYER_KEY
),
al AS (
    SELECT PLAYER_KEY, COUNT(*) AS ALERT_COUNT,
           SUM(IFF(IS_ESCALATED, 1, 0)) AS ESCALATED_ALERTS,
           MAX(RISK_SCORE) AS MAX_RISK_SCORE,
           TO_DATE(MAX(ALERT_TIMESTAMP)) AS LAST_ALERT_DATE
    FROM CORE.FACT_AML_ALERTS GROUP BY PLAYER_KEY
),
cs AS (
    SELECT PLAYER_KEY, COUNT(*) AS CASE_COUNT, SUM(IFF(STR_SUBMITTED_FLAG, 1, 0)) AS STRS_FILED
    FROM CORE.FACT_STR_CASES GROUP BY PLAYER_KEY
)
SELECT
    p.PLAYER_ID,
    p.REGION_CODE,
    p.KYC_STATUS,
    p.KYC_RISK_LEVEL,
    p.PEP_FLAG,
    p.WATCHLIST_FLAG,
    p.SELF_EXCLUSION_FLAG,
    p.PLAYER_STATUS,
    COALESCE(tx.TXN_COUNT, 0)         AS TXN_COUNT,
    COALESCE(tx.TXN_VOLUME, 0)        AS TXN_VOLUME,
    COALESCE(al.ALERT_COUNT, 0)       AS ALERT_COUNT,
    COALESCE(al.ESCALATED_ALERTS, 0)  AS ESCALATED_ALERTS,
    COALESCE(al.MAX_RISK_SCORE, 0)    AS MAX_RISK_SCORE,
    al.LAST_ALERT_DATE                AS LAST_ALERT_DATE,
    COALESCE(cs.CASE_COUNT, 0)        AS CASE_COUNT,
    COALESCE(cs.STRS_FILED, 0)        AS STRS_FILED,
    /* a simple, explainable composite risk band for triage */
    CASE
        WHEN p.WATCHLIST_FLAG OR COALESCE(al.MAX_RISK_SCORE, 0) >= 90 THEN 'Critical'
        WHEN p.KYC_RISK_LEVEL = 'High' OR COALESCE(al.ESCALATED_ALERTS, 0) > 0 THEN 'High'
        WHEN COALESCE(al.ALERT_COUNT, 0) > 0 OR p.PEP_FLAG THEN 'Medium'
        ELSE 'Low'
    END AS COMPOSITE_RISK_BAND
FROM CORE.DIM_PLAYER p
LEFT JOIN tx ON tx.PLAYER_KEY = p.PLAYER_KEY
LEFT JOIN al ON al.PLAYER_KEY = p.PLAYER_KEY
LEFT JOIN cs ON cs.PLAYER_KEY = p.PLAYER_KEY;
