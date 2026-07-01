/* ============================================================================
   Phase 7 — Core 04: Load Facts
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Loads the source-derived facts from STAGING, resolving surrogate keys via
   dimension lookups:
     FACT_TRANSACTIONS      <- STG_TRANSACTIONS (valid rows)
     FACT_MARKET_PERFORMANCE<- STG_MARKET_PERFORMANCE (valid rows) + MoM growth

   FACT_AML_ALERTS is populated in Phase 8; FACT_STR_CASES in Phase 9. The
   player -> account -> transaction -> alert -> case lineage is preserved through
   the surrogate FKs. Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- FACT_TRANSACTIONS : resolve DATE/PLAYER/ACCOUNT/COUNTERPARTY keys ----- */
INSERT OVERWRITE INTO CORE.FACT_TRANSACTIONS
    (TRANSACTION_ID, DATE_KEY, PLAYER_KEY, ACCOUNT_KEY, COUNTERPARTY_ACCOUNT_KEY,
     TRANSACTION_TIMESTAMP, TRANSACTION_TYPE, PAYMENT_FORMAT, CURRENCY, AMOUNT,
     AMOUNT_CAD, IS_HIGH_RISK_METHOD, SOURCE_SYSTEM, LOAD_BATCH_ID)
SELECT
    s.TRANSACTION_ID,
    s.DATE_KEY,
    dp.PLAYER_KEY,
    da.ACCOUNT_KEY,
    dca.ACCOUNT_KEY                           AS COUNTERPARTY_ACCOUNT_KEY,  -- NULL if external party
    s.TXN_TIMESTAMP,
    s.TRANSACTION_TYPE,
    s.PAYMENT_FORMAT,
    s.CURRENCY,
    s.AMOUNT,
    s.AMOUNT                                  AS AMOUNT_CAD,                 -- synthetic data is CAD-normalized
    s.IS_HIGH_RISK_METHOD,
    'SYNTHETIC',
    s.LOAD_BATCH_ID
FROM STAGING.STG_TRANSACTIONS s
JOIN      CORE.DIM_PLAYER  dp  ON dp.PLAYER_ID  = s.PLAYER_ID
JOIN      CORE.DIM_ACCOUNT da  ON da.ACCOUNT_ID = s.ACCOUNT_ID
LEFT JOIN CORE.DIM_ACCOUNT dca ON dca.ACCOUNT_ID = s.COUNTERPARTY_ACCOUNT_ID
WHERE s.IS_VALID;

/* ---- FACT_MARKET_PERFORMANCE : monthly grain; MoM growth via LAG ----------- */
INSERT OVERWRITE INTO CORE.FACT_MARKET_PERFORMANCE
    (DATE_KEY, YEAR_MONTH, FISCAL_YEAR_QUARTER, TOTAL_WAGERS, TOTAL_GGR,
     ACTIVE_ACCOUNTS, GGR_PER_ACTIVE, HOLD_PCT, MOM_GGR_GROWTH_PCT,
     SOURCE_SYSTEM, LOAD_BATCH_ID)
SELECT
    m.DATE_KEY,
    m.YEAR_MONTH,
    m.FISCAL_YEAR_QUARTER,
    m.TOTAL_WAGERS,
    m.TOTAL_GGR,
    m.ACTIVE_ACCOUNTS,
    m.GGR_PER_ACTIVE,
    m.HOLD_PCT,
    ROUND( (m.TOTAL_GGR - LAG(m.TOTAL_GGR) OVER (ORDER BY m.MONTH_START_DATE))
           / NULLIF(LAG(m.TOTAL_GGR) OVER (ORDER BY m.MONTH_START_DATE), 0) * 100, 2) AS MOM_GGR_GROWTH_PCT,
    'SYNTHETIC',
    m.LOAD_BATCH_ID
FROM STAGING.STG_MARKET_PERFORMANCE m
WHERE m.IS_VALID;

/* ============================================================================
   Fact-load validation
   ============================================================================ */

/* Row counts. */
SELECT 'FACT_TRANSACTIONS'       AS FACT, COUNT(*) AS ROWS FROM CORE.FACT_TRANSACTIONS
UNION ALL SELECT 'FACT_MARKET_PERFORMANCE', COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE;

/* FK integrity: no transaction should reference a missing dimension row. */
SELECT
    SUM(IFF(dd.DATE_KEY   IS NULL, 1, 0)) AS ORPHAN_DATE,
    SUM(IFF(dp.PLAYER_KEY IS NULL, 1, 0)) AS ORPHAN_PLAYER,
    SUM(IFF(da.ACCOUNT_KEY IS NULL, 1, 0)) AS ORPHAN_ACCOUNT
FROM CORE.FACT_TRANSACTIONS f
LEFT JOIN CORE.DIM_DATE    dd ON dd.DATE_KEY   = f.DATE_KEY
LEFT JOIN CORE.DIM_PLAYER  dp ON dp.PLAYER_KEY = f.PLAYER_KEY
LEFT JOIN CORE.DIM_ACCOUNT da ON da.ACCOUNT_KEY = f.ACCOUNT_KEY;

/* Grain firewall: market fact must be unique per month (one row per DATE_KEY). */
SELECT COUNT(*) AS MONTHS, COUNT(DISTINCT DATE_KEY) AS DISTINCT_MONTHS,
       IFF(COUNT(*) = COUNT(DISTINCT DATE_KEY), 'OK: monthly grain', 'ERROR: duplicate months') AS GRAIN_CHECK
FROM CORE.FACT_MARKET_PERFORMANCE;

/* Lineage spot check: a transaction resolves to its player and account. */
SELECT f.TRANSACTION_ID, dp.PLAYER_ID, da.ACCOUNT_ID, f.TRANSACTION_TYPE, f.AMOUNT
FROM CORE.FACT_TRANSACTIONS f
JOIN CORE.DIM_PLAYER  dp ON dp.PLAYER_KEY  = f.PLAYER_KEY
JOIN CORE.DIM_ACCOUNT da ON da.ACCOUNT_KEY = f.ACCOUNT_KEY
LIMIT 5;
