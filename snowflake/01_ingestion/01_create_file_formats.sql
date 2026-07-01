/* ============================================================================
   Phase 5 — Ingestion 01: File Formats
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Reusable, named file formats used by stages + COPY INTO. Created in the RAW
   schema so every ingestion object references one canonical definition.

   Run order (Phase 5): 01 (this) -> 02 stages -> 03 raw tables -> 04 load examples.
   All data is SYNTHETIC; no credentials/secrets.
   ============================================================================ */

USE ROLE DATA_ENGINEER;                       -- least-privilege builder role (Phase 4)
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA RAW;

/* ---- Standard CSV: the synthetic source extracts (headered, quoted) -------- */
CREATE OR REPLACE FILE FORMAT RAW.FF_CSV_STD
    TYPE                         = CSV
    FIELD_DELIMITER              = ','
    RECORD_DELIMITER             = '\n'
    SKIP_HEADER                  = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    TRIM_SPACE                   = TRUE
    NULL_IF                      = ('', 'NULL', 'null', 'NA')
    EMPTY_FIELD_AS_NULL          = TRUE
    ENCODING                     = 'UTF8'
    ERROR_ON_COLUMN_COUNT_MISMATCH = TRUE
    COMMENT = 'Reusable standard CSV format for RAW landing of synthetic extracts.';

/* ---- Optional JSON: for semi-structured reference data (e.g. watchlists) --- */
CREATE OR REPLACE FILE FORMAT RAW.FF_JSON_STD
    TYPE              = JSON
    STRIP_OUTER_ARRAY = TRUE
    COMMENT = 'Reusable JSON format for optional semi-structured reference data.';

SHOW FILE FORMATS IN SCHEMA RAW;
