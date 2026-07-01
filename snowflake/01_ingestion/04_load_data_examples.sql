/* ============================================================================
   Phase 5 — Ingestion 04: Load Examples (COPY INTO)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Loads staged synthetic files into the RAW tables, capturing load metadata via
   Snowflake stage metadata columns:
     METADATA$FILENAME        -> SOURCE_FILE_NAME
     METADATA$FILE_ROW_NUMBER -> FILE_ROW_NUMBER
   and a per-run LOAD_BATCH_ID from a session variable. LOADED_AT uses the table
   default (load time).

   Prereqs: 01 formats, 02 stage (+ files uploaded via PUT), 03 raw tables.
   All data is SYNTHETIC; no credentials/secrets. Uses WH_INGESTION.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_INGESTION;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA RAW;

-- One batch id shared across the loads in this run.
SET LOAD_BATCH_ID = 'BATCH_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');

/* Expected source layouts (synthetic generator output):
   transactions:  TRANSACTION_ID, TXN_TIMESTAMP, PLAYER_ID, ACCOUNT_ID,
                  COUNTERPARTY_ACCOUNT_ID, TRANSACTION_TYPE, PAYMENT_FORMAT,
                  CURRENCY, AMOUNT, IS_HIGH_RISK_METHOD, SANCTIONS_FLAG, IS_LAUNDERING
   market:        FISCAL_YEAR_QUARTER, YEAR_MONTH, CASH_WAGERS_M, NAGGR_M,
                  ACTIVE_ACCOUNTS_K, ARPPA
   market_product:YEAR_MONTH, PRODUCT_CATEGORY, CASH_WAGERS_M, NAGGR_M,
                  WAGER_SHARE, GGR_SHARE
   Tip: add VALIDATION_MODE = 'RETURN_ERRORS' to a COPY to dry-run before loading. */

/* ---- Load transactions ---------------------------------------------------- */
COPY INTO RAW.RAW_TRANSACTIONS
    (TRANSACTION_ID, TXN_TIMESTAMP, PLAYER_ID, ACCOUNT_ID, COUNTERPARTY_ACCOUNT_ID,
     TRANSACTION_TYPE, PAYMENT_FORMAT, CURRENCY, AMOUNT, IS_HIGH_RISK_METHOD,
     SANCTIONS_FLAG, IS_LAUNDERING,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
           $LOAD_BATCH_ID, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER
    FROM @RAW.STG_LANDING/transactions/
)
FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV_STD)
ON_ERROR    = 'ABORT_STATEMENT'
PURGE       = FALSE;

/* ---- Load monthly market performance -------------------------------------- */
COPY INTO RAW.RAW_MARKET_PERFORMANCE
    (FISCAL_YEAR_QUARTER, YEAR_MONTH, CASH_WAGERS_M, NAGGR_M, ACTIVE_ACCOUNTS_K, ARPPA,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
FROM (
    SELECT $1, $2, $3, $4, $5, $6,
           $LOAD_BATCH_ID, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER
    FROM @RAW.STG_LANDING/market/
)
FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV_STD)
ON_ERROR    = 'ABORT_STATEMENT'
PURGE       = FALSE;

/* ---- Load market by product ----------------------------------------------- */
COPY INTO RAW.RAW_MARKET_BY_PRODUCT
    (YEAR_MONTH, PRODUCT_CATEGORY, CASH_WAGERS_M, NAGGR_M, WAGER_SHARE, GGR_SHARE,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
FROM (
    SELECT $1, $2, $3, $4, $5, $6,
           $LOAD_BATCH_ID, METADATA$FILENAME, METADATA$FILE_ROW_NUMBER
    FROM @RAW.STG_LANDING/market_product/
)
FILE_FORMAT = (FORMAT_NAME = RAW.FF_CSV_STD)
ON_ERROR    = 'ABORT_STATEMENT'
PURGE       = FALSE;

/* ---- Post-load validation ------------------------------------------------- */
-- Row counts + metadata populated + one batch id per run.
SELECT 'RAW_TRANSACTIONS'       AS TABLE_NAME, COUNT(*) AS ROWS,
       COUNT(DISTINCT SOURCE_FILE_NAME) AS FILES,
       COUNT(DISTINCT LOAD_BATCH_ID)    AS BATCHES,
       MAX(LOADED_AT)                   AS LAST_LOADED
FROM RAW.RAW_TRANSACTIONS
UNION ALL
SELECT 'RAW_MARKET_PERFORMANCE', COUNT(*), COUNT(DISTINCT SOURCE_FILE_NAME),
       COUNT(DISTINCT LOAD_BATCH_ID), MAX(LOADED_AT) FROM RAW.RAW_MARKET_PERFORMANCE
UNION ALL
SELECT 'RAW_MARKET_BY_PRODUCT',  COUNT(*), COUNT(DISTINCT SOURCE_FILE_NAME),
       COUNT(DISTINCT LOAD_BATCH_ID), MAX(LOADED_AT) FROM RAW.RAW_MARKET_BY_PRODUCT;

-- Sample rows (confirm source-faithful landing + metadata).
SELECT * FROM RAW.RAW_TRANSACTIONS LIMIT 5;

-- Load audit via COPY history (last 1 day).
SELECT FILE_NAME, ROW_COUNT, ROW_PARSED, ERROR_COUNT, STATUS, LAST_LOAD_TIME
FROM TABLE(INFORMATION_SCHEMA.COPY_HISTORY(
        TABLE_NAME  => 'RAW.RAW_TRANSACTIONS',
        START_TIME  => DATEADD('day', -1, CURRENT_TIMESTAMP())));
