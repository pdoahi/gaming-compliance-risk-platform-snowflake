/* ============================================================================
   Phase 10 — Reporting 01: Executive Views
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   BI-ready views in REPORTING for the Executive Overview dashboard. Views read
   CORE and expose business-friendly names. Each KPI source is pre-aggregated to
   a single row / to month grain BEFORE joining, so there is NO grain duplication
   (market/AML/STR are combined only at aligned aggregate grains).

   Built by DATA_ENGINEER; read by BI_REPORTING. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA REPORTING;

/* ---- VW_EXECUTIVE_OVERVIEW : one-row program + market health --------------- */
CREATE OR REPLACE VIEW REPORTING.VW_EXECUTIVE_OVERVIEW AS
WITH txn AS (   -- transaction totals collapse to one row
    SELECT COUNT(*)      AS TOTAL_TRANSACTIONS,
           SUM(AMOUNT)   AS TOTAL_TRANSACTION_VALUE
    FROM CORE.FACT_TRANSACTIONS
),
mkt AS (        -- market totals collapse to one row
    SELECT SUM(TOTAL_WAGERS)                                      AS TOTAL_WAGERS,
           SUM(TOTAL_GGR)                                         AS TOTAL_GGR,
           ROUND(SUM(TOTAL_GGR) / NULLIF(SUM(TOTAL_WAGERS), 0) * 100, 2) AS HOLD_PCT,
           MAX(ACTIVE_ACCOUNTS)                                  AS LATEST_ACTIVE_ACCOUNTS,
           ROUND(SUM(TOTAL_GGR) / NULLIF(MAX(ACTIVE_ACCOUNTS), 0), 2)    AS GGR_PER_ACTIVE
    FROM CORE.FACT_MARKET_PERFORMANCE
),
aml AS (        -- AML totals collapse to one row
    SELECT COUNT(*)                       AS AML_ALERTS,
           SUM(IFF(IS_ESCALATED, 1, 0))   AS ESCALATED_ALERTS,
           ROUND(AVG(RISK_SCORE), 1)      AS AVG_RISK_SCORE
    FROM CORE.FACT_AML_ALERTS
),
strc AS (       -- STR totals collapse to one row
    SELECT COUNT(*)                                             AS TOTAL_CASES,
           SUM(IFF(s.IS_TERMINAL, 0, 1))                        AS OPEN_INVESTIGATIONS,
           SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0))                 AS STRS_SUBMITTED,
           ROUND(100.0 * SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS STR_CONVERSION_RATE_PCT,
           ROUND(AVG(IFF(s.IS_TERMINAL, c.INVESTIGATION_DAYS, NULL)), 1) AS AVG_INVESTIGATION_DAYS,
           ROUND(100.0 * SUM(IFF(s.IS_TERMINAL AND NOT c.SLA_BREACHED, 1, 0))
                 / NULLIF(SUM(IFF(s.IS_TERMINAL, 1, 0)), 0), 1) AS SLA_COMPLIANCE_PCT
    FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_STATUS s ON s.STATUS_KEY = c.STATUS_KEY
)
SELECT
    txn.TOTAL_TRANSACTIONS, txn.TOTAL_TRANSACTION_VALUE,
    mkt.TOTAL_WAGERS, mkt.TOTAL_GGR, mkt.HOLD_PCT, mkt.LATEST_ACTIVE_ACCOUNTS, mkt.GGR_PER_ACTIVE,
    aml.AML_ALERTS, aml.ESCALATED_ALERTS, aml.AVG_RISK_SCORE,
    ROUND(100.0 * aml.ESCALATED_ALERTS / NULLIF(aml.AML_ALERTS, 0), 1) AS ESCALATION_RATE_PCT,
    strc.TOTAL_CASES, strc.OPEN_INVESTIGATIONS, strc.STRS_SUBMITTED,
    strc.STR_CONVERSION_RATE_PCT, strc.AVG_INVESTIGATION_DAYS, strc.SLA_COMPLIANCE_PCT
FROM txn CROSS JOIN mkt CROSS JOIN aml CROSS JOIN strc;

/* ---- VW_MONTHLY_COMPLIANCE_TRENDS : month-grain time series ---------------- */
CREATE OR REPLACE VIEW REPORTING.VW_MONTHLY_COMPLIANCE_TRENDS AS
WITH alert_m AS (
    SELECT d.YEAR_MONTH, COUNT(*) AS ALERTS, SUM(IFF(a.IS_ESCALATED, 1, 0)) AS ESCALATED_ALERTS
    FROM CORE.FACT_AML_ALERTS a JOIN CORE.DIM_DATE d ON d.DATE_KEY = a.DATE_KEY
    GROUP BY d.YEAR_MONTH
),
case_m AS (
    SELECT d.YEAR_MONTH, COUNT(*) AS CASES, SUM(IFF(c.STR_SUBMITTED_FLAG, 1, 0)) AS STRS_FILED
    FROM CORE.FACT_STR_CASES c JOIN CORE.DIM_DATE d ON d.DATE_KEY = c.OPEN_DATE_KEY
    GROUP BY d.YEAR_MONTH
),
mkt_m AS (
    SELECT YEAR_MONTH, TOTAL_GGR, TOTAL_WAGERS, HOLD_PCT FROM CORE.FACT_MARKET_PERFORMANCE
),
spine AS (
    SELECT YEAR_MONTH FROM mkt_m
    UNION SELECT YEAR_MONTH FROM alert_m
    UNION SELECT YEAR_MONTH FROM case_m
)
SELECT
    s.YEAR_MONTH,
    COALESCE(a.ALERTS, 0)            AS ALERTS,
    COALESCE(a.ESCALATED_ALERTS, 0)  AS ESCALATED_ALERTS,
    COALESCE(c.CASES, 0)             AS STR_CASES,
    COALESCE(c.STRS_FILED, 0)        AS STRS_FILED,
    m.TOTAL_GGR, m.TOTAL_WAGERS, m.HOLD_PCT
FROM spine s
LEFT JOIN alert_m a ON a.YEAR_MONTH = s.YEAR_MONTH
LEFT JOIN case_m  c ON c.YEAR_MONTH = s.YEAR_MONTH
LEFT JOIN mkt_m   m ON m.YEAR_MONTH = s.YEAR_MONTH
ORDER BY s.YEAR_MONTH;
