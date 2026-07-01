/* ============================================================================
   Phase 10 — Reporting 04: Market / GGR Views
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   BI-ready market views (REPORTING) over CORE.FACT_MARKET_PERFORMANCE. Kept at
   the MONTHLY market grain and NEVER joined to transaction/alert/case facts
   (grain firewall) — so market metrics are never blended with per-transaction
   AML metrics. Read by BI_REPORTING / finance. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA REPORTING;

/* ---- VW_MARKET_PERFORMANCE : monthly market series ------------------------ */
CREATE OR REPLACE VIEW REPORTING.VW_MARKET_PERFORMANCE AS
SELECT
    m.YEAR_MONTH,
    m.FISCAL_YEAR_QUARTER,
    d.FISCAL_YEAR,
    ROUND(m.TOTAL_WAGERS / 1e9, 2)     AS TOTAL_WAGERS_B,
    ROUND(m.TOTAL_GGR   / 1e9, 3)      AS TOTAL_GGR_B,
    m.TOTAL_WAGERS,
    m.TOTAL_GGR,
    m.ACTIVE_ACCOUNTS,
    m.GGR_PER_ACTIVE,
    m.HOLD_PCT,
    m.MOM_GGR_GROWTH_PCT
FROM CORE.FACT_MARKET_PERFORMANCE m
JOIN CORE.DIM_DATE d ON d.DATE_KEY = m.DATE_KEY
ORDER BY m.YEAR_MONTH;

/* ---- VW_MARKET_FISCAL_YEAR : fiscal-year rollup with YoY ------------------- */
CREATE OR REPLACE VIEW REPORTING.VW_MARKET_FISCAL_YEAR AS
WITH fy AS (
    SELECT d.FISCAL_YEAR,
           SUM(m.TOTAL_WAGERS)                                   AS TOTAL_WAGERS,
           SUM(m.TOTAL_GGR)                                      AS TOTAL_GGR,
           ROUND(SUM(m.TOTAL_GGR) / NULLIF(SUM(m.TOTAL_WAGERS), 0) * 100, 2) AS HOLD_PCT,
           ROUND(AVG(m.ACTIVE_ACCOUNTS), 0)                      AS AVG_ACTIVE_ACCOUNTS
    FROM CORE.FACT_MARKET_PERFORMANCE m
    JOIN CORE.DIM_DATE d ON d.DATE_KEY = m.DATE_KEY
    GROUP BY d.FISCAL_YEAR
)
SELECT
    FISCAL_YEAR,
    ROUND(TOTAL_WAGERS / 1e9, 2) AS TOTAL_WAGERS_B,
    ROUND(TOTAL_GGR   / 1e9, 3)  AS TOTAL_GGR_B,
    HOLD_PCT,
    AVG_ACTIVE_ACCOUNTS,
    ROUND(100.0 * (TOTAL_GGR - LAG(TOTAL_GGR) OVER (ORDER BY FISCAL_YEAR))
          / NULLIF(LAG(TOTAL_GGR) OVER (ORDER BY FISCAL_YEAR), 0), 1) AS GGR_YOY_PCT
FROM fy
ORDER BY FISCAL_YEAR;
