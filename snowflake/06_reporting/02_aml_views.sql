/* ============================================================================
   Phase 10 — Reporting 02: AML Views
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   BI-ready AML monitoring views (REPORTING) over CORE.FACT_AML_ALERTS.
   Read by BI_REPORTING / COMPLIANCE_ANALYST. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA REPORTING;

/* ---- VW_AML_MONITORING_SUMMARY : one-row AML KPIs --------------------------
   Grain: 1 row (whole-program AML KPI snapshot; no fan-out).                  */
CREATE OR REPLACE VIEW REPORTING.VW_AML_MONITORING_SUMMARY AS
SELECT
    COUNT(*)                                                   AS TOTAL_ALERTS,
    SUM(IFF(a.IS_ESCALATED, 1, 0))                             AS ESCALATED_ALERTS,
    ROUND(100.0 * SUM(IFF(a.IS_ESCALATED, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS ESCALATION_RATE_PCT,
    ROUND(AVG(a.RISK_SCORE), 1)                                AS AVG_RISK_SCORE,
    SUM(IFF(a.SEVERITY = 'Critical', 1, 0))                    AS CRITICAL_ALERTS,
    SUM(IFF(at.RULE_CODE = 'R11', 1, 0))                       AS SANCTIONS_HITS,
    COUNT(DISTINCT IFF(a.IS_ESCALATED, a.ACCOUNT_KEY, NULL))   AS HIGH_RISK_ACCOUNTS,
    COUNT(DISTINCT a.ALERT_TYPE_KEY)                           AS RULES_FIRING
FROM CORE.FACT_AML_ALERTS a
JOIN CORE.DIM_ALERT_TYPE at ON at.ALERT_TYPE_KEY = a.ALERT_TYPE_KEY;

/* ---- VW_ALERT_TYPOLOGY_BREAKDOWN : per-rule detail -------------------------
   Grain: 1 row per alert typology (rule R01–R11). LEFT JOIN keeps zero-alert
   rules so every rule is represented.                                         */
CREATE OR REPLACE VIEW REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN AS
SELECT
    at.RULE_CODE,
    at.RULE_NAME,
    at.TYPOLOGY,
    at.DEFAULT_SEVERITY,
    COUNT(a.ALERT_KEY)                            AS ALERTS,
    SUM(IFF(a.IS_ESCALATED, 1, 0))                AS ESCALATED,
    ROUND(AVG(a.RISK_SCORE), 1)                   AS AVG_RISK_SCORE,
    ROUND(100.0 * COUNT(a.ALERT_KEY)
          / NULLIF(SUM(COUNT(a.ALERT_KEY)) OVER (), 0), 1) AS PCT_OF_ALERTS
FROM CORE.DIM_ALERT_TYPE at
LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_TYPE_KEY = at.ALERT_TYPE_KEY
GROUP BY at.RULE_CODE, at.RULE_NAME, at.TYPOLOGY, at.DEFAULT_SEVERITY
ORDER BY ALERTS DESC;
