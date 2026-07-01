/* ============================================================================
   Phase 10 — Reporting 03: STR Workflow Views
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   BI-ready STR workflow views (REPORTING) over CORE.FACT_STR_CASES.
   Read by BI_REPORTING / COMPLIANCE_ANALYST / COMPLIANCE_MANAGER. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA REPORTING;

/* ---- VW_STR_WORKFLOW_SUMMARY : one-row program KPIs ------------------------
   Grain: 1 row (whole-program STR KPI snapshot; no fan-out).                  */
CREATE OR REPLACE VIEW REPORTING.VW_STR_WORKFLOW_SUMMARY AS
SELECT
    COUNT(*)                                                     AS TOTAL_CASES,
    SUM(IFF(s.IS_TERMINAL, 0, 1))                                AS OPEN_BACKLOG,
    SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0))                         AS STRS_FILED,
    ROUND(100.0 * SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS STR_CONVERSION_PCT,
    ROUND(AVG(IFF(s.IS_TERMINAL, c.INVESTIGATION_DAYS, NULL)), 1) AS AVG_INVESTIGATION_DAYS_CLOSED,
    ROUND(100.0 * SUM(IFF(s.IS_TERMINAL AND NOT c.SLA_BREACHED, 1, 0))
          / NULLIF(SUM(IFF(s.IS_TERMINAL, 1, 0)), 0), 1)         AS SLA_COMPLIANCE_PCT
FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY;

/* ---- VW_SLA_PERFORMANCE : SLA + aging by priority -------------------------
   Grain: 1 row per case priority (Critical/High/Medium/Low).                 */
CREATE OR REPLACE VIEW REPORTING.VW_SLA_PERFORMANCE AS
SELECT
    c.CASE_PRIORITY,
    COUNT(*)                                                     AS CASES,
    MAX(c.SLA_DAYS)                                              AS SLA_TARGET_DAYS,
    SUM(IFF(c.SLA_BREACHED, 1, 0))                               AS SLA_BREACHES,
    ROUND(100.0 * SUM(IFF(s.IS_TERMINAL AND NOT c.SLA_BREACHED, 1, 0))
          / NULLIF(SUM(IFF(s.IS_TERMINAL, 1, 0)), 0), 1)         AS SLA_COMPLIANCE_PCT,
    SUM(IFF(NOT s.IS_TERMINAL AND c.INVESTIGATION_DAYS <= 7,  1, 0)) AS OPEN_0_7,
    SUM(IFF(NOT s.IS_TERMINAL AND c.INVESTIGATION_DAYS BETWEEN 8 AND 14,  1, 0)) AS OPEN_8_14,
    SUM(IFF(NOT s.IS_TERMINAL AND c.INVESTIGATION_DAYS BETWEEN 15 AND 30, 1, 0)) AS OPEN_15_30,
    SUM(IFF(NOT s.IS_TERMINAL AND c.INVESTIGATION_DAYS > 30, 1, 0))  AS OPEN_30_PLUS
FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY
GROUP BY c.CASE_PRIORITY
ORDER BY SLA_TARGET_DAYS;

/* ---- VW_ANALYST_WORKLOAD : per-analyst load -------------------------------
   Grain: 1 row per analyst.                                                  */
CREATE OR REPLACE VIEW REPORTING.VW_ANALYST_WORKLOAD AS
SELECT
    an.ANALYST_ID, an.ANALYST_NAME, an.TEAM, an.SENIORITY,
    COUNT(*)                                        AS TOTAL_CASES,
    SUM(IFF(s.IS_TERMINAL, 0, 1))                   AS OPEN_CASES,
    SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0))            AS STRS_FILED,
    SUM(IFF(c.SLA_BREACHED, 1, 0))                  AS SLA_BREACHES,
    ROUND(AVG(IFF(s.IS_TERMINAL, c.INVESTIGATION_DAYS, NULL)), 1) AS AVG_INVESTIGATION_DAYS
FROM CORE.FACT_STR_CASES c
JOIN CORE.DIM_ANALYST an ON an.ANALYST_KEY = c.ANALYST_KEY
JOIN CORE.DIM_STATUS  s  ON s.STATUS_KEY   = c.STATUS_KEY
GROUP BY an.ANALYST_ID, an.ANALYST_NAME, an.TEAM, an.SENIORITY
ORDER BY TOTAL_CASES DESC;

/* ---- VW_STR_STATUS_FUNNEL : pipeline funnel -------------------------------
   Grain: 1 row per workflow status (ordered by WORKFLOW_ORDER).             */
CREATE OR REPLACE VIEW REPORTING.VW_STR_STATUS_FUNNEL AS
SELECT s.WORKFLOW_ORDER, s.STATUS_NAME, s.STATUS_CATEGORY, COUNT(*) AS CASES
FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY
GROUP BY s.WORKFLOW_ORDER, s.STATUS_NAME, s.STATUS_CATEGORY
ORDER BY s.WORKFLOW_ORDER;
