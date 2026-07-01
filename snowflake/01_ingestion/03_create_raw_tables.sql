/* ============================================================================
   Phase 5 — Ingestion 03: RAW Landing Tables
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Source-faithful landing tables. Design principles:
     - Columns land as VARCHAR (raw text) so a bad value never fails the load;
       typing/cleansing happens in STAGING (Phase 6). RAW preserves the source.
     - Every table carries load metadata:
         LOAD_BATCH_ID    which load produced the row
         SOURCE_FILE_NAME which file it came from  (METADATA$FILENAME)
         FILE_ROW_NUMBER  its row within that file (METADATA$FILE_ROW_NUMBER)
         LOADED_AT        when it landed            (defaults to load time)
     - TRANSIENT tables: RAW is always rebuildable from source, so we skip
       Fail-safe to save storage cost (cost-aware, per the architecture).

   Run after 01 (formats) and 02 (stage). All data is SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA RAW;

/* ---- RAW_TRANSACTIONS : one row per source transaction extract row --------- */
CREATE OR REPLACE TRANSIENT TABLE RAW.RAW_TRANSACTIONS (
    TRANSACTION_ID            VARCHAR,
    TXN_TIMESTAMP             VARCHAR,
    PLAYER_ID                 VARCHAR,
    ACCOUNT_ID                VARCHAR,
    COUNTERPARTY_ACCOUNT_ID   VARCHAR,
    TRANSACTION_TYPE          VARCHAR,          -- Deposit / Withdrawal
    PAYMENT_FORMAT            VARCHAR,
    CURRENCY                  VARCHAR,
    AMOUNT                    VARCHAR,          -- kept as text in RAW; cast in STAGING
    IS_HIGH_RISK_METHOD       VARCHAR,
    SANCTIONS_FLAG            VARCHAR,          -- synthetic watchlist flag
    IS_LAUNDERING             VARCHAR,          -- synthetic ground-truth label (for validation)
    -- load metadata --
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'RAW landing of synthetic transaction extracts. Source-faithful (VARCHAR) + load metadata.';

/* ---- RAW_MARKET_PERFORMANCE : one row per source monthly market row -------- */
CREATE OR REPLACE TRANSIENT TABLE RAW.RAW_MARKET_PERFORMANCE (
    FISCAL_YEAR_QUARTER       VARCHAR,
    YEAR_MONTH                VARCHAR,
    CASH_WAGERS_M             VARCHAR,
    NAGGR_M                   VARCHAR,
    ACTIVE_ACCOUNTS_K         VARCHAR,
    ARPPA                     VARCHAR,
    -- load metadata --
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'RAW landing of synthetic monthly market/GGR figures. Source-faithful + load metadata.';

/* ---- RAW_MARKET_BY_PRODUCT : monthly x product (supports product-mix reporting) */
CREATE OR REPLACE TRANSIENT TABLE RAW.RAW_MARKET_BY_PRODUCT (
    YEAR_MONTH                VARCHAR,
    PRODUCT_CATEGORY          VARCHAR,
    CASH_WAGERS_M             VARCHAR,
    NAGGR_M                   VARCHAR,
    WAGER_SHARE               VARCHAR,
    GGR_SHARE                 VARCHAR,
    -- load metadata --
    LOAD_BATCH_ID             VARCHAR,
    SOURCE_FILE_NAME          VARCHAR,
    FILE_ROW_NUMBER           NUMBER,
    LOADED_AT                 TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'RAW landing of synthetic monthly market split by product category.';

SHOW TABLES IN SCHEMA RAW;
