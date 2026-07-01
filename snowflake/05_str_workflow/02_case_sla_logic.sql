/* ============================================================================
   Phase 9 — STR 02: SLA Logic
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Calculates the SLA fields on CORE.FACT_STR_CASES:
     SLA_DAYS           target by priority (Critical 5 / High 10 / Medium 15 / Low 20)
     INVESTIGATION_DAYS closed: open->close ; open: open->simulation "as-of" date
     SLA_BREACHED       INVESTIGATION_DAYS > SLA_DAYS

   Open-case age uses a simulation as-of date (latest known case date + 3 days) so
   ages are realistic within the synthetic window rather than relative to the wall
   clock. Run after 01. Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

-- Simulation "today": a few days after the latest known case date.
SET SIM_ASOF = (
    SELECT DATEADD(day, 3, MAX(TO_DATE(TO_CHAR(COALESCE(CLOSE_DATE_KEY, OPEN_DATE_KEY)), 'YYYYMMDD')))
    FROM CORE.FACT_STR_CASES
);

/* ---- SLA target by priority ----------------------------------------------- */
UPDATE CORE.FACT_STR_CASES
SET SLA_DAYS = CASE CASE_PRIORITY
                   WHEN 'Critical' THEN 5
                   WHEN 'High'     THEN 10
                   WHEN 'Medium'   THEN 15
                   ELSE 20 END;

/* ---- Investigation duration (closed: real span; open: age to as-of) -------- */
UPDATE CORE.FACT_STR_CASES
SET INVESTIGATION_DAYS = DATEDIFF(
        day,
        TO_DATE(TO_CHAR(OPEN_DATE_KEY), 'YYYYMMDD'),
        COALESCE(TO_DATE(TO_CHAR(CLOSE_DATE_KEY), 'YYYYMMDD'), $SIM_ASOF));

/* ---- SLA breach flag ------------------------------------------------------- */
UPDATE CORE.FACT_STR_CASES
SET SLA_BREACHED = (INVESTIGATION_DAYS > SLA_DAYS);

/* ============================================================================
   STR workflow validation / KPIs
   ============================================================================ */

-- Pipeline funnel (New -> Closed).
SELECT s.WORKFLOW_ORDER, s.STATUS_NAME, COUNT(*) AS CASES
FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY
GROUP BY s.WORKFLOW_ORDER, s.STATUS_NAME ORDER BY s.WORKFLOW_ORDER;

-- Program KPIs: backlog, STR conversion, avg investigation days, SLA compliance.
SELECT
    COUNT(*)                                                          AS TOTAL_CASES,
    SUM(IFF(s.IS_TERMINAL, 0, 1))                                     AS OPEN_BACKLOG,
    SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0))                              AS STRS_FILED,
    ROUND(100.0 * SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS STR_CONVERSION_PCT,
    ROUND(AVG(IFF(s.IS_TERMINAL, c.INVESTIGATION_DAYS, NULL)), 1)     AS AVG_INV_DAYS_CLOSED,
    ROUND(100.0 * SUM(IFF(s.IS_TERMINAL AND NOT c.SLA_BREACHED, 1, 0))
          / NULLIF(SUM(IFF(s.IS_TERMINAL, 1, 0)), 0), 1)             AS SLA_COMPLIANCE_PCT
FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY;

-- Analyst workload.
SELECT an.ANALYST_ID, an.ANALYST_NAME, an.TEAM,
       COUNT(*)                          AS TOTAL_CASES,
       SUM(IFF(s.IS_TERMINAL, 0, 1))     AS OPEN_CASES,
       SUM(IFF(c.STR_SUBMITTED_FLAG,1,0)) AS STRS_FILED,
       SUM(IFF(c.SLA_BREACHED,1,0))       AS SLA_BREACHES
FROM CORE.FACT_STR_CASES c
JOIN CORE.DIM_ANALYST an ON an.ANALYST_KEY = c.ANALYST_KEY
JOIN CORE.DIM_STATUS  s  ON s.STATUS_KEY   = c.STATUS_KEY
GROUP BY an.ANALYST_ID, an.ANALYST_NAME, an.TEAM
ORDER BY TOTAL_CASES DESC;

-- Integrity: every case links to an alert (no orphans).
SELECT COUNT(*) AS ORPHAN_CASES
FROM CORE.FACT_STR_CASES c
LEFT JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY
WHERE a.ALERT_KEY IS NULL;
