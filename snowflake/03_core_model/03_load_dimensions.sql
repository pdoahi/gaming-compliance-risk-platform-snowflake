/* ============================================================================
   Phase 7 — Core 03: Load Dimensions
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Populates the conformed dimensions:
     DIM_DATE     generated calendar (2021-2028)
     DIM_STATUS   5-stage workflow (reference seed)
     DIM_ANALYST  synthetic compliance team (reference seed)
     DIM_PLAYER   distinct players from STAGING + deterministic synthetic KYC/risk
     DIM_ACCOUNT  distinct accounts from STAGING + owning player + derived attributes
   (DIM_ALERT_TYPE is seeded in Phase 8.)

   Player/account descriptive attributes come from a KYC/customer master in a real
   deployment; here they are synthesized DETERMINISTICALLY from the id via HASH()
   so the pipeline is self-contained and reproducible. Uses WH_TRANSFORM. SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- DIM_DATE : generate ~8 years of calendar rows ------------------------ */
INSERT OVERWRITE INTO CORE.DIM_DATE
    (DATE_KEY, FULL_DATE, DAY, MONTH, MONTH_NAME, QUARTER, YEAR, YEAR_MONTH,
     DAY_OF_WEEK, DAY_NAME, IS_WEEKEND, FISCAL_YEAR, FISCAL_QUARTER, MONTH_START_DATE)
WITH gen AS (
    SELECT DATEADD(day, SEQ4(), DATE '2021-01-01') AS FULL_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 2922))          -- 2021-01-01 .. ~2028-12
),
calc AS (
    SELECT FULL_DATE,
           YEAR(FULL_DATE)                              AS Y,
           MONTH(FULL_DATE)                             AS M,
           YEAR(FULL_DATE) + IFF(MONTH(FULL_DATE) >= 4, 1, 0) AS FY,     -- April fiscal start
           FLOOR(MOD(MONTH(FULL_DATE) - 4 + 12, 12) / 3) + 1  AS FQ
    FROM gen
)
SELECT
    TO_NUMBER(TO_CHAR(FULL_DATE, 'YYYYMMDD')),
    FULL_DATE,
    DAY(FULL_DATE), M, MONTHNAME(FULL_DATE), QUARTER(FULL_DATE), Y,
    TO_CHAR(FULL_DATE, 'YYYY-MM'),
    DAYOFWEEK(FULL_DATE), DAYNAME(FULL_DATE),
    (DAYOFWEEK(FULL_DATE) IN (0, 6)),
    FY,
    'FY' || LPAD(MOD(FY, 100), 2, '0') || 'Q' || FQ,
    DATE_TRUNC('month', FULL_DATE)
FROM calc;

/* ---- DIM_STATUS : the 5-stage STR/alert workflow (reference) --------------- */
INSERT OVERWRITE INTO CORE.DIM_STATUS
    (STATUS_KEY, STATUS_CODE, STATUS_NAME, STATUS_CATEGORY, WORKFLOW_ORDER, IS_TERMINAL, APPLIES_TO)
VALUES
    (1, 'NEW',     'New',           'Open',   1, FALSE, 'BOTH'),
    (2, 'REVIEW',  'Under Review',  'Open',   2, FALSE, 'BOTH'),
    (3, 'ESC',     'Escalated',     'Open',   3, FALSE, 'BOTH'),
    (4, 'STR_SUB', 'STR Submitted', 'Open',   4, FALSE, 'CASE'),
    (5, 'CLOSED',  'Closed',        'Closed', 5, TRUE,  'BOTH');

/* ---- DIM_ANALYST : synthetic compliance team ------------------------------ */
INSERT OVERWRITE INTO CORE.DIM_ANALYST
    (ANALYST_ID, ANALYST_NAME, TEAM, SENIORITY, ACTIVE_FLAG, SOURCE_SYSTEM)
VALUES
    ('AN-001', 'Alex Rivera (synthetic)', 'AML Ops',        'Junior', TRUE, 'SYNTHETIC'),
    ('AN-003', 'Sam Okafor (synthetic)',  'Investigations', 'Lead',   TRUE, 'SYNTHETIC'),
    ('AN-007', 'Jordan Vale (synthetic)', 'Investigations', 'Senior', TRUE, 'SYNTHETIC'),
    ('AN-011', 'Priya Anand (synthetic)', 'AML Ops',        'Junior', TRUE, 'SYNTHETIC'),
    ('AN-014', 'Mei Lin (synthetic)',     'Investigations', 'Senior', TRUE, 'SYNTHETIC'),
    ('AN-021', 'Tomas Berg (synthetic)',  'QA',             'Lead',   TRUE, 'SYNTHETIC');

/* ---- DIM_PLAYER : distinct players + deterministic synthetic attributes ---- */
INSERT OVERWRITE INTO CORE.DIM_PLAYER
    (PLAYER_ID, REGISTRATION_DATE, REGION_CODE, KYC_STATUS, KYC_RISK_LEVEL,
     PEP_FLAG, WATCHLIST_FLAG, SELF_EXCLUSION_FLAG, PLAYER_STATUS, SOURCE_SYSTEM, LOAD_BATCH_ID)
WITH p AS (
    SELECT PLAYER_ID,
           MIN(TXN_DATE)                              AS FIRST_TXN,
           BOOLOR_AGG(COALESCE(SANCTIONS_FLAG, FALSE)) AS ANY_SANCTION,
           MAX(LOAD_BATCH_ID)                          AS LOAD_BATCH_ID
    FROM STAGING.STG_TRANSACTIONS
    WHERE PLAYER_ID IS NOT NULL AND IS_VALID
    GROUP BY PLAYER_ID
)
SELECT
    PLAYER_ID,
    FIRST_TXN,
    'REGION-' || CHR(65 + MOD(ABS(HASH(PLAYER_ID)), 4))                     AS REGION_CODE,
    CASE WHEN MOD(ABS(HASH(PLAYER_ID, 1)), 100) < 80 THEN 'Verified'
         WHEN MOD(ABS(HASH(PLAYER_ID, 1)), 100) < 95 THEN 'Pending'
         ELSE 'Failed' END                                                 AS KYC_STATUS,
    CASE WHEN ANY_SANCTION THEN 'High'
         WHEN MOD(ABS(HASH(PLAYER_ID, 2)), 100) < 70 THEN 'Low'
         WHEN MOD(ABS(HASH(PLAYER_ID, 2)), 100) < 92 THEN 'Medium'
         ELSE 'High' END                                                   AS KYC_RISK_LEVEL,
    (MOD(ABS(HASH(PLAYER_ID, 3)), 100) < 3)                                AS PEP_FLAG,
    ANY_SANCTION                                                           AS WATCHLIST_FLAG,
    (MOD(ABS(HASH(PLAYER_ID, 4)), 100) < 5)                                AS SELF_EXCLUSION_FLAG,
    CASE WHEN MOD(ABS(HASH(PLAYER_ID, 5)), 100) < 90 THEN 'Active'
         WHEN MOD(ABS(HASH(PLAYER_ID, 5)), 100) < 97 THEN 'Suspended'
         ELSE 'Closed' END                                                 AS PLAYER_STATUS,
    'SYNTHETIC',
    LOAD_BATCH_ID
FROM p;

/* ---- DIM_ACCOUNT : distinct accounts + owning player + derived attributes -- */
INSERT OVERWRITE INTO CORE.DIM_ACCOUNT
    (ACCOUNT_ID, PLAYER_KEY, ACCOUNT_TYPE, CURRENCY, OPEN_DATE, ACCOUNT_STATUS,
     ACCOUNT_RISK_RATING, PRIMARY_FUNDING_METHOD, SOURCE_SYSTEM, LOAD_BATCH_ID)
WITH a AS (
    SELECT ACCOUNT_ID,
           ANY_VALUE(PLAYER_ID)   AS PLAYER_ID,          -- one owning player per account
           MODE(PAYMENT_FORMAT)   AS PRIMARY_FUNDING_METHOD,
           MODE(CURRENCY)         AS CURRENCY,
           MIN(TXN_DATE)          AS OPEN_DATE,
           MAX(LOAD_BATCH_ID)     AS LOAD_BATCH_ID
    FROM STAGING.STG_TRANSACTIONS
    WHERE ACCOUNT_ID IS NOT NULL AND IS_VALID
    GROUP BY ACCOUNT_ID
)
SELECT
    a.ACCOUNT_ID,
    dp.PLAYER_KEY,
    CASE WHEN MOD(ABS(HASH(a.ACCOUNT_ID)), 100) < 85 THEN 'Standard' ELSE 'VIP' END AS ACCOUNT_TYPE,
    COALESCE(a.CURRENCY, 'CAD'),
    a.OPEN_DATE,
    CASE WHEN MOD(ABS(HASH(a.ACCOUNT_ID, 1)), 100) < 92 THEN 'Active'
         WHEN MOD(ABS(HASH(a.ACCOUNT_ID, 1)), 100) < 98 THEN 'Dormant'
         ELSE 'Frozen' END                                                          AS ACCOUNT_STATUS,
    CASE WHEN MOD(ABS(HASH(a.ACCOUNT_ID, 2)), 100) < 72 THEN 'Low'
         WHEN MOD(ABS(HASH(a.ACCOUNT_ID, 2)), 100) < 93 THEN 'Medium'
         ELSE 'High' END                                                            AS ACCOUNT_RISK_RATING,
    a.PRIMARY_FUNDING_METHOD,
    'SYNTHETIC',
    a.LOAD_BATCH_ID
FROM a
JOIN CORE.DIM_PLAYER dp ON dp.PLAYER_ID = a.PLAYER_ID;

/* ---- Dimension load validation -------------------------------------------- */
SELECT 'DIM_DATE'    AS DIMENSION, COUNT(*) AS ROWS FROM CORE.DIM_DATE
UNION ALL SELECT 'DIM_STATUS',  COUNT(*) FROM CORE.DIM_STATUS
UNION ALL SELECT 'DIM_ANALYST', COUNT(*) FROM CORE.DIM_ANALYST
UNION ALL SELECT 'DIM_PLAYER',  COUNT(*) FROM CORE.DIM_PLAYER
UNION ALL SELECT 'DIM_ACCOUNT', COUNT(*) FROM CORE.DIM_ACCOUNT;
