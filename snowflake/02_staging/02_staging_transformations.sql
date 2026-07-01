/* ============================================================================
   Phase 6 — Staging 02: Transformations (RAW -> STAGING)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Reads RAW, applies cleansing/standardization, and loads the typed STG tables.
   What each transform does:
     - Standardize column names  (model-aligned)
     - Cast data types           (TRY_TO_* so a bad value -> NULL, never fails)
     - Validate dates            (TRY_TO_TIMESTAMP / TRY_TO_DATE + DQ flag)
     - Normalize categories      (INITCAP/UPPER + canonical mapping)
     - Clean nulls               (TRIM + NULLIF empty)
     - Data-quality flags        (IS_VALID + DQ_ISSUES list)
     - Preserve source traceability (LOAD_BATCH_ID / SOURCE_FILE_NAME / FILE_ROW_NUMBER / LOADED_AT)

   INSERT OVERWRITE = full refresh from RAW (idempotent re-run). Uses WH_TRANSFORM.
   Run after 01_create_staging_tables.sql. Data is SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA STAGING;

/* ---- Transactions --------------------------------------------------------- */
INSERT OVERWRITE INTO STAGING.STG_TRANSACTIONS
    (TRANSACTION_ID, TXN_TIMESTAMP, TXN_DATE, DATE_KEY, PLAYER_ID, ACCOUNT_ID,
     COUNTERPARTY_ACCOUNT_ID, TRANSACTION_TYPE, PAYMENT_FORMAT, CURRENCY, AMOUNT,
     IS_HIGH_RISK_METHOD, SANCTIONS_FLAG, IS_LAUNDERING, IS_VALID, DQ_ISSUES,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT)
WITH cleaned AS (
    SELECT
        NULLIF(TRIM(TRANSACTION_ID), '')                       AS TRANSACTION_ID,
        TRY_TO_TIMESTAMP_NTZ(TRIM(TXN_TIMESTAMP))              AS TXN_TIMESTAMP,
        NULLIF(TRIM(PLAYER_ID), '')                            AS PLAYER_ID,
        NULLIF(TRIM(ACCOUNT_ID), '')                           AS ACCOUNT_ID,
        NULLIF(TRIM(COUNTERPARTY_ACCOUNT_ID), '')              AS COUNTERPARTY_ACCOUNT_ID,
        CASE UPPER(TRIM(TRANSACTION_TYPE))                     -- normalize category
             WHEN 'DEPOSIT'    THEN 'Deposit'
             WHEN 'D'          THEN 'Deposit'
             WHEN 'WITHDRAWAL' THEN 'Withdrawal'
             WHEN 'WITHDRAW'   THEN 'Withdrawal'
             WHEN 'W'          THEN 'Withdrawal'
             ELSE INITCAP(TRIM(TRANSACTION_TYPE)) END          AS TRANSACTION_TYPE,
        INITCAP(TRIM(PAYMENT_FORMAT))                          AS PAYMENT_FORMAT,
        UPPER(TRIM(CURRENCY))                                  AS CURRENCY,
        TRY_TO_DECIMAL(TRIM(AMOUNT), 18, 2)                    AS AMOUNT,
        TRY_TO_BOOLEAN(TRIM(IS_HIGH_RISK_METHOD))              AS IS_HIGH_RISK_METHOD,
        TRY_TO_BOOLEAN(TRIM(SANCTIONS_FLAG))                   AS SANCTIONS_FLAG,
        TRY_TO_BOOLEAN(TRIM(IS_LAUNDERING))                    AS IS_LAUNDERING,
        LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
    FROM RAW.RAW_TRANSACTIONS
),
flagged AS (
    SELECT c.*,
        ARRAY_CONSTRUCT_COMPACT(                               -- collect DQ issues (NULLs dropped)
            IFF(TRANSACTION_ID IS NULL,                    'MISSING_TRANSACTION_ID', NULL),
            IFF(TXN_TIMESTAMP  IS NULL,                    'INVALID_TIMESTAMP',      NULL),
            IFF(PLAYER_ID      IS NULL,                    'MISSING_PLAYER_ID',      NULL),
            IFF(AMOUNT         IS NULL,                    'NON_NUMERIC_AMOUNT',     NULL),
            IFF(AMOUNT < 0,                                'NEGATIVE_AMOUNT',        NULL),
            IFF(TRANSACTION_TYPE NOT IN ('Deposit','Withdrawal'), 'UNKNOWN_TXN_TYPE', NULL)
        ) AS ISSUES
    FROM cleaned c
)
SELECT
    TRANSACTION_ID,
    TXN_TIMESTAMP,
    TO_DATE(TXN_TIMESTAMP)                                     AS TXN_DATE,
    TO_NUMBER(TO_CHAR(TO_DATE(TXN_TIMESTAMP), 'YYYYMMDD'))     AS DATE_KEY,
    PLAYER_ID, ACCOUNT_ID, COUNTERPARTY_ACCOUNT_ID, TRANSACTION_TYPE,
    PAYMENT_FORMAT, CURRENCY, AMOUNT, IS_HIGH_RISK_METHOD, SANCTIONS_FLAG, IS_LAUNDERING,
    (ARRAY_SIZE(ISSUES) = 0)                                   AS IS_VALID,
    NULLIF(ARRAY_TO_STRING(ISSUES, '; '), '')                 AS DQ_ISSUES,
    LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
FROM flagged;

/* ---- Market performance (scale $M -> absolute; derive HOLD_PCT) ------------ */
INSERT OVERWRITE INTO STAGING.STG_MARKET_PERFORMANCE
    (YEAR_MONTH, MONTH_START_DATE, DATE_KEY, FISCAL_YEAR_QUARTER, TOTAL_WAGERS,
     TOTAL_GGR, ACTIVE_ACCOUNTS, GGR_PER_ACTIVE, HOLD_PCT, IS_VALID, DQ_ISSUES,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT)
WITH cleaned AS (
    SELECT
        NULLIF(TRIM(YEAR_MONTH), '')                          AS YEAR_MONTH,
        TRY_TO_DATE(TRIM(YEAR_MONTH) || '-01', 'YYYY-MM-DD')  AS MONTH_START_DATE,
        NULLIF(TRIM(FISCAL_YEAR_QUARTER), '')                 AS FISCAL_YEAR_QUARTER,
        TRY_TO_DECIMAL(TRIM(CASH_WAGERS_M), 18, 4) * 1000000  AS TOTAL_WAGERS,
        TRY_TO_DECIMAL(TRIM(NAGGR_M), 18, 4)       * 1000000  AS TOTAL_GGR,
        TRY_TO_NUMBER(TRIM(ACTIVE_ACCOUNTS_K))     * 1000     AS ACTIVE_ACCOUNTS,
        TRY_TO_DECIMAL(TRIM(ARPPA), 12, 2)                    AS GGR_PER_ACTIVE,
        LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
    FROM RAW.RAW_MARKET_PERFORMANCE
),
flagged AS (
    SELECT c.*,
        ARRAY_CONSTRUCT_COMPACT(
            IFF(MONTH_START_DATE IS NULL,                 'INVALID_YEAR_MONTH', NULL),
            IFF(TOTAL_WAGERS IS NULL,                     'NON_NUMERIC_WAGERS', NULL),
            IFF(TOTAL_GGR    IS NULL,                     'NON_NUMERIC_GGR',    NULL),
            IFF(TOTAL_WAGERS < 0 OR TOTAL_GGR < 0,        'NEGATIVE_VALUE',     NULL)
        ) AS ISSUES
    FROM cleaned c
)
SELECT
    YEAR_MONTH, MONTH_START_DATE,
    TO_NUMBER(TO_CHAR(MONTH_START_DATE, 'YYYYMMDD'))          AS DATE_KEY,
    FISCAL_YEAR_QUARTER, TOTAL_WAGERS, TOTAL_GGR, ACTIVE_ACCOUNTS, GGR_PER_ACTIVE,
    ROUND(TOTAL_GGR / NULLIF(TOTAL_WAGERS, 0) * 100, 2)       AS HOLD_PCT,
    (ARRAY_SIZE(ISSUES) = 0)                                  AS IS_VALID,
    NULLIF(ARRAY_TO_STRING(ISSUES, '; '), '')                AS DQ_ISSUES,
    LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
FROM flagged;

/* ---- Market by product ---------------------------------------------------- */
INSERT OVERWRITE INTO STAGING.STG_MARKET_BY_PRODUCT
    (YEAR_MONTH, MONTH_START_DATE, DATE_KEY, PRODUCT_CATEGORY, TOTAL_WAGERS,
     TOTAL_GGR, WAGER_SHARE, GGR_SHARE, IS_VALID, DQ_ISSUES,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT)
WITH cleaned AS (
    SELECT
        NULLIF(TRIM(YEAR_MONTH), '')                          AS YEAR_MONTH,
        TRY_TO_DATE(TRIM(YEAR_MONTH) || '-01', 'YYYY-MM-DD')  AS MONTH_START_DATE,
        UPPER(TRIM(PRODUCT_CATEGORY))                         AS PRODUCT_CATEGORY,
        TRY_TO_DECIMAL(TRIM(CASH_WAGERS_M), 18, 4) * 1000000  AS TOTAL_WAGERS,
        TRY_TO_DECIMAL(TRIM(NAGGR_M), 18, 4)       * 1000000  AS TOTAL_GGR,
        TRY_TO_DECIMAL(TRIM(WAGER_SHARE), 6, 4)               AS WAGER_SHARE,
        TRY_TO_DECIMAL(TRIM(GGR_SHARE), 6, 4)                 AS GGR_SHARE,
        LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
    FROM RAW.RAW_MARKET_BY_PRODUCT
),
flagged AS (
    SELECT c.*,
        ARRAY_CONSTRUCT_COMPACT(
            IFF(MONTH_START_DATE IS NULL,      'INVALID_YEAR_MONTH', NULL),
            IFF(PRODUCT_CATEGORY IS NULL,      'MISSING_PRODUCT',    NULL),
            IFF(TOTAL_GGR IS NULL,             'NON_NUMERIC_GGR',    NULL)
        ) AS ISSUES
    FROM cleaned c
)
SELECT
    YEAR_MONTH, MONTH_START_DATE,
    TO_NUMBER(TO_CHAR(MONTH_START_DATE, 'YYYYMMDD'))          AS DATE_KEY,
    PRODUCT_CATEGORY, TOTAL_WAGERS, TOTAL_GGR, WAGER_SHARE, GGR_SHARE,
    (ARRAY_SIZE(ISSUES) = 0)                                  AS IS_VALID,
    NULLIF(ARRAY_TO_STRING(ISSUES, '; '), '')                AS DQ_ISSUES,
    LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER, LOADED_AT
FROM flagged;

/* ---- Staging validation --------------------------------------------------- */
-- Row counts + how many rows failed any DQ check (should be 0 on clean synthetic data).
SELECT 'STG_TRANSACTIONS'       AS TABLE_NAME, COUNT(*) AS ROWS,
       SUM(IFF(IS_VALID, 0, 1)) AS INVALID_ROWS FROM STAGING.STG_TRANSACTIONS
UNION ALL
SELECT 'STG_MARKET_PERFORMANCE', COUNT(*), SUM(IFF(IS_VALID, 0, 1)) FROM STAGING.STG_MARKET_PERFORMANCE
UNION ALL
SELECT 'STG_MARKET_BY_PRODUCT',  COUNT(*), SUM(IFF(IS_VALID, 0, 1)) FROM STAGING.STG_MARKET_BY_PRODUCT;

-- Breakdown of any DQ issues found.
SELECT DQ_ISSUES, COUNT(*) AS ROWS
FROM STAGING.STG_TRANSACTIONS
WHERE NOT IS_VALID
GROUP BY DQ_ISSUES
ORDER BY ROWS DESC;

-- Confirm source traceability survived the transform.
SELECT COUNT(DISTINCT LOAD_BATCH_ID) AS BATCHES, COUNT(DISTINCT SOURCE_FILE_NAME) AS FILES
FROM STAGING.STG_TRANSACTIONS;
