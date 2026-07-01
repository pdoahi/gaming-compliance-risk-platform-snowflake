/* ============================================================================
   Phase 5 — Ingestion 02: Internal Stages
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   An internal named stage where synthetic source files are uploaded (PUT) and
   loaded (COPY INTO) into RAW. One stage with per-source subfolders keeps the
   landing area tidy. Run after 01 (file formats).

   Internal stage = Snowflake-managed storage (no external cloud creds needed) —
   keeps this portfolio project self-contained and secret-free.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA RAW;

CREATE OR REPLACE STAGE RAW.STG_LANDING
    FILE_FORMAT = RAW.FF_CSV_STD
    DIRECTORY   = (ENABLE = TRUE)             -- directory table: list/track staged files
    COMMENT     = 'Internal landing stage. Upload synthetic files here, then COPY INTO RAW.';

/* Suggested folder convention within the stage:
     @RAW.STG_LANDING/transactions/     -> RAW_TRANSACTIONS
     @RAW.STG_LANDING/market/           -> RAW_MARKET_PERFORMANCE
     @RAW.STG_LANDING/market_product/   -> RAW_MARKET_BY_PRODUCT
     @RAW.STG_LANDING/reference/        -> optional JSON reference data

   Upload files from a SnowSQL / client session with PUT (client-side command):
     PUT file://.../data/raw/transactions_synthetic.csv        @RAW.STG_LANDING/transactions/    AUTO_COMPRESS=TRUE;
     PUT file://.../data/raw/market_monthly_synthetic.csv      @RAW.STG_LANDING/market/          AUTO_COMPRESS=TRUE;
     PUT file://.../data/raw/market_by_product_synthetic.csv   @RAW.STG_LANDING/market_product/  AUTO_COMPRESS=TRUE;
*/

-- Inspect the stage (after uploading files):
LIST @RAW.STG_LANDING;
SHOW STAGES IN SCHEMA RAW;
