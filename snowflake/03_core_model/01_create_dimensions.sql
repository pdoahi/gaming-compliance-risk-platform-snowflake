/* ============================================================================
   Phase 7 — Core 01: Dimension Tables
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Conformed dimensions in the CORE schema (permanent tables — curated, Time
   Travel is useful here). Surrogate keys via NUMBER IDENTITY where the business
   key is external; explicit keys for small reference dims. PK/UNIQUE constraints
   are declared (informational in Snowflake but valuable for docs + BI tools).
   Audit columns added where useful. Current-state (SCD Type 1) per the data
   model; SCD Type 2 is the documented future enhancement.

   Run after STAGING is loaded. Loads are in 03_load_dimensions.sql. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- DIM_DATE : conformed calendar (smart key YYYYMMDD) -------------------- */
CREATE OR REPLACE TABLE CORE.DIM_DATE (
    DATE_KEY          NUMBER(8)   NOT NULL PRIMARY KEY,
    FULL_DATE         DATE        NOT NULL,
    DAY               NUMBER(2),
    MONTH             NUMBER(2),
    MONTH_NAME        VARCHAR(9),
    QUARTER           NUMBER(1),
    YEAR              NUMBER(4),
    YEAR_MONTH        VARCHAR(7),
    DAY_OF_WEEK       NUMBER(1),
    DAY_NAME          VARCHAR(9),
    IS_WEEKEND        BOOLEAN,
    FISCAL_YEAR       NUMBER(4),
    FISCAL_QUARTER    VARCHAR(6),
    MONTH_START_DATE  DATE,
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Conformed date dimension (role-played by all facts).';

/* ---- DIM_PLAYER : the monitored customer (SCD1; KYC/risk = SCD2 candidates)  */
CREATE OR REPLACE TABLE CORE.DIM_PLAYER (
    PLAYER_KEY          NUMBER IDENTITY(1,1) PRIMARY KEY,
    PLAYER_ID           VARCHAR(50) NOT NULL UNIQUE,
    REGISTRATION_DATE   DATE,
    REGION_CODE         VARCHAR(10),
    KYC_STATUS          VARCHAR(20),          -- SCD2 candidate
    KYC_RISK_LEVEL      VARCHAR(10),          -- SCD2 candidate
    PEP_FLAG            BOOLEAN,
    WATCHLIST_FLAG      BOOLEAN,
    SELF_EXCLUSION_FLAG BOOLEAN,
    PLAYER_STATUS       VARCHAR(20),
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT          TIMESTAMP_NTZ,
    SOURCE_SYSTEM       VARCHAR(30),
    LOAD_BATCH_ID       VARCHAR(50)
) COMMENT = 'Player dimension (current state). KYC_STATUS/KYC_RISK_LEVEL are SCD Type 2 candidates.';

/* ---- DIM_ACCOUNT : a wallet/account owned by a player --------------------- */
CREATE OR REPLACE TABLE CORE.DIM_ACCOUNT (
    ACCOUNT_KEY            NUMBER IDENTITY(1,1) PRIMARY KEY,
    ACCOUNT_ID             VARCHAR(50) NOT NULL UNIQUE,
    PLAYER_KEY             NUMBER,
    ACCOUNT_TYPE           VARCHAR(20),
    CURRENCY               VARCHAR(3),
    OPEN_DATE              DATE,
    ACCOUNT_STATUS         VARCHAR(20),        -- SCD2 candidate
    ACCOUNT_RISK_RATING    VARCHAR(10),        -- SCD2 candidate
    PRIMARY_FUNDING_METHOD VARCHAR(30),
    CREATED_AT             TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    UPDATED_AT             TIMESTAMP_NTZ,
    SOURCE_SYSTEM          VARCHAR(30),
    LOAD_BATCH_ID          VARCHAR(50),
    CONSTRAINT FK_ACCOUNT_PLAYER FOREIGN KEY (PLAYER_KEY) REFERENCES CORE.DIM_PLAYER (PLAYER_KEY)
) COMMENT = 'Account dimension (current state). ACCOUNT_STATUS/ACCOUNT_RISK_RATING are SCD2 candidates.';

/* ---- DIM_ALERT_TYPE : AML rule/typology catalog (seeded in Phase 8) -------- */
CREATE OR REPLACE TABLE CORE.DIM_ALERT_TYPE (
    ALERT_TYPE_KEY        NUMBER(4) NOT NULL PRIMARY KEY,
    RULE_CODE             VARCHAR(10) NOT NULL,
    RULE_NAME             VARCHAR(80),
    TYPOLOGY              VARCHAR(50),
    DESCRIPTION           VARCHAR(300),
    BASE_RISK_SCORE       NUMBER(3),
    DEFAULT_SEVERITY      VARCHAR(10),
    REGULATORY_REFERENCE  VARCHAR(80),
    IS_ACTIVE             BOOLEAN,
    CREATED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'AML alert-type / rule catalog. Populated by Phase 8 (04_aml_rules/01_alert_type_seed_data.sql).';

/* ---- DIM_STATUS : workflow status for alerts & cases ---------------------- */
CREATE OR REPLACE TABLE CORE.DIM_STATUS (
    STATUS_KEY        NUMBER(3) NOT NULL PRIMARY KEY,
    STATUS_CODE       VARCHAR(20) NOT NULL,
    STATUS_NAME       VARCHAR(40),
    STATUS_CATEGORY   VARCHAR(20),            -- Open / Closed
    WORKFLOW_ORDER    NUMBER(2),
    IS_TERMINAL       BOOLEAN,
    APPLIES_TO        VARCHAR(20),            -- ALERT / CASE / BOTH
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Workflow status dimension (reference).';

/* ---- DIM_ANALYST : compliance analysts (synthetic) ------------------------ */
CREATE OR REPLACE TABLE CORE.DIM_ANALYST (
    ANALYST_KEY       NUMBER IDENTITY(1,1) PRIMARY KEY,
    ANALYST_ID        VARCHAR(20) NOT NULL UNIQUE,
    ANALYST_NAME      VARCHAR(80),
    TEAM              VARCHAR(40),
    SENIORITY         VARCHAR(20),
    ACTIVE_FLAG       BOOLEAN,
    SOURCE_SYSTEM     VARCHAR(30),
    CREATED_AT        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
) COMMENT = 'Analyst dimension (synthetic compliance team).';

SHOW TABLES IN SCHEMA CORE;
