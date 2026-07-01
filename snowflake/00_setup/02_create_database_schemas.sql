/* ============================================================================
   Phase 4 — Setup 02: Database & Schemas
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Creates GAMING_COMPLIANCE_DB and its layered schemas. Run after 01, before 03.

   Layered flow:  RAW -> STAGING -> CORE -> ANALYTICS -> REPORTING
   Cross-cutting: GOVERNANCE (RBAC/policies), UTILITY (control/DQ/sequences)

   Cost-aware: short Time-Travel retention at DB level (raw/staging tables will
   also be TRANSIENT in later phases to avoid Fail-safe storage). Idempotent via
   CREATE ... IF NOT EXISTS. All data is SYNTHETIC.
   ============================================================================ */

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS GAMING_COMPLIANCE_DB
    COMMENT = 'Gaming compliance & risk intelligence platform. Synthetic data only.';

-- Cost-aware Time Travel (short retention for a demo; raise for real audit needs).
ALTER DATABASE GAMING_COMPLIANCE_DB SET DATA_RETENTION_TIME_IN_DAYS = 1;

USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- Layered schemas (one per architectural responsibility) --------------- */
CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Landing: source-faithful copies of loaded files + load metadata. No transforms.';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'Cleanse: typed, cleaned, standardized data; preserves source traceability.';

CREATE SCHEMA IF NOT EXISTS CORE
    COMMENT = 'Curate: conformed dimensional model (DIM_* + FACT_TRANSACTIONS + FACT_MARKET_PERFORMANCE).';

CREATE SCHEMA IF NOT EXISTS ANALYTICS
    COMMENT = 'Derive: AML rules, risk scoring, STR workflow -> FACT_AML_ALERTS, FACT_STR_CASES + analytics.';

CREATE SCHEMA IF NOT EXISTS REPORTING
    COMMENT = 'Serve: BI-ready VW_* views. The only layer BI tools read.';

CREATE SCHEMA IF NOT EXISTS GOVERNANCE
    COMMENT = 'Cross-cutting: masking / row-access policies, classification, audit helpers.';

CREATE SCHEMA IF NOT EXISTS UTILITY
    COMMENT = 'Cross-cutting: sequences / surrogate-key helpers, load-control tables, DQ results.';

-- Drop the auto-created PUBLIC schema to keep the namespace intentional (optional).
DROP SCHEMA IF EXISTS PUBLIC;

SHOW SCHEMAS IN DATABASE GAMING_COMPLIANCE_DB;
