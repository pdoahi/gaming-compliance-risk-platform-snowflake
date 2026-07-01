/* ============================================================================
   Phase 6 — Staging 01: Staging Tables (typed)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Typed, cleaned versions of the RAW landing tables. Compared to RAW:
     - proper Snowflake data types (TIMESTAMP/DATE/NUMBER/BOOLEAN)
     - standardized, model-aligned column names
     - derived helper columns (TXN_DATE, DATE_KEY, MONTH_START_DATE)
     - data-quality columns (IS_VALID, DQ_ISSUES)
   Source traceability is preserved (LOAD_BATCH_ID, SOURCE_FILE_NAME,
   FILE_ROW_NUMBER, LOADED_AT carried through; STAGED_AT added).

   TRANSIENT (rebuildable from RAW). Run after RAW load. Transformations that
   populate these tables are in 02_staging_transformations.sql. Data is SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA STAGING;

/* ---- STG_TRANSACTIONS ------------------------------------------------------ */
CREATE OR REPLACE TRANSIENT TABLE STAGING.STG_TRANSACTIONS (
    TRANSACTION_ID            VARCHAR,
    TXN_TIMESTAMP             TIMESTAMP_NTZ,
    TXN_DATE                  DATE,
    DATE_KEY                  NUMBER(8),
    PLAYER_ID                 VARCHAR,
    ACCOUNT_ID                VARCHAR,
    COUNTERPARTY_ACCOUNT_ID   VARCHAR,
    TRANSACTION_TYPE          VARCHAR,          -- normalized: Deposit / Withdrawal
    PAYMENT_FORMAT            VARCHAR,          -- normalized (INITCAP)
    CURRENCY                  VARCHAR(3),       -- normalized (UPPER)
    AMOUNT                    NUMBER(18,2),
    IS_HIGH_RISK_METHOD       BOOLEAN,
    SANCTIONS_FLAG            BOOLEAN,
    IS_LAUNDERING             BOOLEAN,          -- synthetic ground-truth label
    -- data quality --
    IS_VALID                  BOOLEAN,
    DQ_ISSUES                 VARCHAR,          -- '; '-joined failed-check labels (NULL if clean)
    -- source traceability --
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ,
    STAGED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Typed/cleaned transactions from RAW. Preserves source traceability + DQ flags.';

/* ---- STG_MARKET_PERFORMANCE ----------------------------------------------- */
CREATE OR REPLACE TRANSIENT TABLE STAGING.STG_MARKET_PERFORMANCE (
    YEAR_MONTH                VARCHAR(7),
    MONTH_START_DATE          DATE,
    DATE_KEY                  NUMBER(8),
    FISCAL_YEAR_QUARTER       VARCHAR,
    TOTAL_WAGERS              NUMBER(18,2),     -- CASH_WAGERS_M * 1,000,000
    TOTAL_GGR                 NUMBER(18,2),     -- NAGGR_M * 1,000,000
    ACTIVE_ACCOUNTS           NUMBER,           -- ACTIVE_ACCOUNTS_K * 1,000
    GGR_PER_ACTIVE            NUMBER(12,2),
    HOLD_PCT                  NUMBER(5,2),      -- derived: GGR / wagers * 100
    IS_VALID                  BOOLEAN,
    DQ_ISSUES                 VARCHAR,
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ,
    STAGED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Typed/cleaned monthly market/GGR from RAW. Amounts scaled to absolute currency.';

/* ---- STG_MARKET_BY_PRODUCT ------------------------------------------------ */
CREATE OR REPLACE TRANSIENT TABLE STAGING.STG_MARKET_BY_PRODUCT (
    YEAR_MONTH                VARCHAR(7),
    MONTH_START_DATE          DATE,
    DATE_KEY                  NUMBER(8),
    PRODUCT_CATEGORY          VARCHAR,          -- normalized (UPPER)
    TOTAL_WAGERS              NUMBER(18,2),
    TOTAL_GGR                 NUMBER(18,2),
    WAGER_SHARE               NUMBER(6,4),
    GGR_SHARE                 NUMBER(6,4),
    IS_VALID                  BOOLEAN,
    DQ_ISSUES                 VARCHAR,
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ,
    STAGED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Typed/cleaned monthly market split by product category.';

SHOW TABLES IN SCHEMA STAGING;
