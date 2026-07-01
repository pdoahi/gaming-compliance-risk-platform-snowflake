/* ============================================================================
   Phase 7 — Core 02: Fact Tables
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Four fact tables (fact constellation). Surrogate PKs (IDENTITY), degenerate
   business keys (*_ID), foreign keys to conformed dimensions (informational),
   and audit columns. Grains match docs/data_model.md.

   Load ownership:
     FACT_TRANSACTIONS, FACT_MARKET_PERFORMANCE -> loaded here (Phase 7, 04_load_facts)
     FACT_AML_ALERTS                            -> populated in Phase 8 (AML rules)
     FACT_STR_CASES                             -> populated in Phase 9 (STR workflow)

   Run after 01_create_dimensions.sql. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- FACT_TRANSACTIONS : grain = one row per transaction ------------------- */
CREATE OR REPLACE TABLE CORE.FACT_TRANSACTIONS (
    TRANSACTION_KEY           NUMBER IDENTITY(1,1) PRIMARY KEY,
    TRANSACTION_ID            VARCHAR(50) NOT NULL,          -- degenerate business key
    DATE_KEY                  NUMBER(8),
    PLAYER_KEY                NUMBER,
    ACCOUNT_KEY               NUMBER,
    COUNTERPARTY_ACCOUNT_KEY  NUMBER,                        -- role-playing (nullable/external)
    TRANSACTION_TIMESTAMP     TIMESTAMP_NTZ,
    TRANSACTION_TYPE          VARCHAR(20),
    PAYMENT_FORMAT            VARCHAR(30),
    CURRENCY                  VARCHAR(3),
    AMOUNT                    NUMBER(18,2),                  -- additive
    AMOUNT_CAD                NUMBER(18,2),                  -- additive
    IS_HIGH_RISK_METHOD       BOOLEAN,
    SOURCE_SYSTEM             VARCHAR(30),
    LOAD_BATCH_ID             VARCHAR(50),
    CREATED_AT                TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_TXN_DATE    FOREIGN KEY (DATE_KEY)    REFERENCES CORE.DIM_DATE (DATE_KEY),
    CONSTRAINT FK_TXN_PLAYER  FOREIGN KEY (PLAYER_KEY)  REFERENCES CORE.DIM_PLAYER (PLAYER_KEY),
    CONSTRAINT FK_TXN_ACCOUNT FOREIGN KEY (ACCOUNT_KEY) REFERENCES CORE.DIM_ACCOUNT (ACCOUNT_KEY)
) COMMENT = 'Transaction fact. Grain: one row per transaction.';

/* ---- FACT_AML_ALERTS : grain = one row per (transaction x rule) match ------ */
CREATE OR REPLACE TABLE CORE.FACT_AML_ALERTS (
    ALERT_KEY          NUMBER IDENTITY(1,1) PRIMARY KEY,
    ALERT_ID           VARCHAR(50) NOT NULL,
    TRANSACTION_KEY    NUMBER,
    ALERT_TYPE_KEY     NUMBER(4),
    PLAYER_KEY         NUMBER,
    ACCOUNT_KEY        NUMBER,
    DATE_KEY           NUMBER(8),
    STATUS_KEY         NUMBER(3),
    ALERT_TIMESTAMP    TIMESTAMP_NTZ,
    SEVERITY           VARCHAR(10),
    RISK_SCORE         NUMBER(3),                            -- non-additive
    IS_ESCALATED       BOOLEAN,
    ALERT_DESCRIPTION  VARCHAR(300),
    SOURCE_SYSTEM      VARCHAR(30),
    LOAD_BATCH_ID      VARCHAR(50),
    CREATED_AT         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_ALERT_TXN    FOREIGN KEY (TRANSACTION_KEY) REFERENCES CORE.FACT_TRANSACTIONS (TRANSACTION_KEY),
    CONSTRAINT FK_ALERT_TYPE   FOREIGN KEY (ALERT_TYPE_KEY)  REFERENCES CORE.DIM_ALERT_TYPE (ALERT_TYPE_KEY),
    CONSTRAINT FK_ALERT_STATUS FOREIGN KEY (STATUS_KEY)      REFERENCES CORE.DIM_STATUS (STATUS_KEY),
    CONSTRAINT FK_ALERT_PLAYER FOREIGN KEY (PLAYER_KEY)      REFERENCES CORE.DIM_PLAYER (PLAYER_KEY)
) COMMENT = 'AML alert fact (populated in Phase 8). Grain: one row per transaction x rule match.';

/* ---- FACT_STR_CASES : grain = one row per investigation case --------------- */
CREATE OR REPLACE TABLE CORE.FACT_STR_CASES (
    CASE_KEY            NUMBER IDENTITY(1,1) PRIMARY KEY,
    CASE_ID             VARCHAR(50) NOT NULL,
    ALERT_KEY           NUMBER,
    PLAYER_KEY          NUMBER,
    ANALYST_KEY         NUMBER,
    STATUS_KEY          NUMBER(3),
    OPEN_DATE_KEY       NUMBER(8),
    CLOSE_DATE_KEY      NUMBER(8),                           -- nullable
    CASE_PRIORITY       VARCHAR(10),
    SLA_DAYS            NUMBER(3),                           -- non-additive target
    INVESTIGATION_DAYS  NUMBER(4),                           -- semi-additive
    SLA_BREACHED        BOOLEAN,                             -- additive (count)
    STR_SUBMITTED_FLAG  BOOLEAN,                             -- additive (count)
    CLOSURE_REASON      VARCHAR(60),
    SOURCE_SYSTEM       VARCHAR(30),
    LOAD_BATCH_ID       VARCHAR(50),
    CREATED_AT          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_CASE_ALERT   FOREIGN KEY (ALERT_KEY)     REFERENCES CORE.FACT_AML_ALERTS (ALERT_KEY),
    CONSTRAINT FK_CASE_ANALYST FOREIGN KEY (ANALYST_KEY)   REFERENCES CORE.DIM_ANALYST (ANALYST_KEY),
    CONSTRAINT FK_CASE_STATUS  FOREIGN KEY (STATUS_KEY)    REFERENCES CORE.DIM_STATUS (STATUS_KEY),
    CONSTRAINT FK_CASE_PLAYER  FOREIGN KEY (PLAYER_KEY)    REFERENCES CORE.DIM_PLAYER (PLAYER_KEY)
) COMMENT = 'STR case fact (populated in Phase 9). Grain: one row per investigation case.';

/* ---- FACT_MARKET_PERFORMANCE : grain = one row per month (grain firewall) -- */
CREATE OR REPLACE TABLE CORE.FACT_MARKET_PERFORMANCE (
    MARKET_PERF_KEY      NUMBER IDENTITY(1,1) PRIMARY KEY,
    DATE_KEY             NUMBER(8),                          -- ONLY dimension link
    YEAR_MONTH           VARCHAR(7),
    FISCAL_YEAR_QUARTER  VARCHAR(6),
    TOTAL_WAGERS         NUMBER(18,2),                       -- additive over time
    TOTAL_GGR            NUMBER(18,2),                       -- additive over time
    ACTIVE_ACCOUNTS      NUMBER(12),                         -- semi-additive
    GGR_PER_ACTIVE       NUMBER(12,2),                       -- non-additive ratio
    HOLD_PCT             NUMBER(5,2),                        -- non-additive ratio
    MOM_GGR_GROWTH_PCT   NUMBER(6,2),                        -- non-additive
    SOURCE_SYSTEM        VARCHAR(30),
    LOAD_BATCH_ID        VARCHAR(50),
    CREATED_AT           TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT FK_MKT_DATE FOREIGN KEY (DATE_KEY) REFERENCES CORE.DIM_DATE (DATE_KEY)
) COMMENT = 'Market/GGR fact. Grain: one row per month. Joins ONLY DIM_DATE (grain firewall).';

SHOW TABLES IN SCHEMA CORE;
