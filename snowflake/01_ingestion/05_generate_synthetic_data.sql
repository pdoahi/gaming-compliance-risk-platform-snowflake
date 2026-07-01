/* ============================================================================
   Phase 15 — Ingestion 05: Synthetic Data Generator (in-database)
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   PURPOSE
   -------
   Populate the RAW landing tables with fully SYNTHETIC data using pure SQL
   (GENERATOR / SEQ4 / deterministic arithmetic) — NO external files required.

   This is the frictionless alternative to the file-based load in
   04_load_data_examples.sql: run this once and the whole pipeline
   (STAGING -> CORE -> AML -> STR -> REPORTING) has data to flow through, so a
   reviewer can build the entire platform in a fresh trial account without
   preparing or uploading any CSVs.

   The data is deliberately shaped so the 11 AML typologies in
   04_aml_rules/02_generate_aml_alerts.sql actually fire — otherwise every
   downstream layer would be empty. Each block below notes the rule(s) it feeds:
       R01 large (>=10k)          R07 daily spike (>=5x median)
       R02 structuring [9k,10k)   R08 dormant reactivation
       R03 rapid in/out (6h)      R09 high-risk customer (>=3k)
       R04 high velocity (>=8/d)  R10 counterparty concentration
       R05 repeated sub-threshold R11 sanctions / watchlist
       R06 high-risk method (>=5k)

   All values are FABRICATED. No real players, accounts, amounts, or market
   figures; no credentials or secrets. Amounts are illustrative only.

   Run AFTER 03_create_raw_tables.sql. INSERT OVERWRITE = idempotent re-run.
   Uses WH_INGESTION. Then continue at 02_staging.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_INGESTION;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA RAW;

-- One batch id for this synthetic run (mirrors the file-load convention).
SET LOAD_BATCH_ID = 'SYNTH_' || TO_VARCHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');

/* ============================================================================
   1) TRANSACTIONS  ->  RAW.RAW_TRANSACTIONS
   400 synthetic accounts (one player each) over 2023-2024, plus targeted
   "bad-actor" cohorts that trip specific typologies.
   ============================================================================ */
INSERT OVERWRITE INTO RAW.RAW_TRANSACTIONS
    (TRANSACTION_ID, TXN_TIMESTAMP, PLAYER_ID, ACCOUNT_ID, COUNTERPARTY_ACCOUNT_ID,
     TRANSACTION_TYPE, PAYMENT_FORMAT, CURRENCY, AMOUNT, IS_HIGH_RISK_METHOD,
     SANCTIONS_FLAG, IS_LAUNDERING,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
WITH
/* -- account population + deterministic risk "profile" flags ---------------- */
acct AS (
    SELECT SEQ4() AS an FROM TABLE(GENERATOR(ROWCOUNT => 400))          -- an = 0..399
),
prof AS (
    SELECT an,
           'P' || LPAD(an + 1, 5, '0')  AS player_id,
           'A' || LPAD(an + 1, 5, '0')  AS account_id,
           (MOD(an, 10) = 0)  AS is_struct,       -- ~40 accounts -> R02/R05
           (MOD(an, 17) = 0)  AS is_burst,        -- ~24 accounts -> R04/R05
           (MOD(an, 13) = 0)  AS is_rapid,        -- ~31 accounts -> R03
           (MOD(an, 29) = 0)  AS is_conc,         -- ~14 accounts -> R10
           (MOD(an, 23) = 0)  AS is_sanctioned,   -- ~18 accounts -> R11
           (MOD(an, 7)  = 0)  AS is_hrm           -- ~58 accounts -> R06
    FROM acct
),
n12 AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 12))),
n8  AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 8))),
n5  AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 5))),
n4  AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 4))),
n2  AS (SELECT SEQ4() AS n FROM TABLE(GENERATOR(ROWCOUNT => 2))),

/* -- (a) base activity: 12 varied txns per account -------------------------- */
/*    Wide amount spread naturally produces R01 (>=10k), R09 (>=3k) and, over  */
/*    scattered dates, some R08 dormant-reactivation gaps.                     */
base AS (
    SELECT
        'TB' || LPAD(p.an, 5, '0') || LPAD(x.n, 2, '0')                     AS transaction_id,
        DATEADD(second, MOD((p.an * 7 + x.n * 13) * 97, 86400),
            DATEADD(day, MOD(p.an * 37 + x.n * 61, 700), DATE '2023-01-01')) AS ts,
        p.player_id, p.account_id,
        CASE WHEN MOD(x.n, 3) = 0
             THEN 'A' || LPAD(MOD(p.an * 31 + x.n, 400) + 1, 5, '0') END     AS cp,
        IFF(MOD(x.n, 2) = 0, 'Deposit', 'Withdrawal')                        AS ttype,
        CASE WHEN p.is_hrm AND (25 + MOD((p.an * 53 + x.n * 29) * 17, 12000)) >= 5000
             THEN IFF(MOD(x.n, 2) = 0, 'Crypto', 'Prepaid Card')             -- R06
             ELSE CASE MOD(x.n, 5)
                    WHEN 0 THEN 'Credit Card'  WHEN 1 THEN 'Debit Card'
                    WHEN 2 THEN 'E-Wallet'     WHEN 3 THEN 'Bank Transfer'
                    ELSE 'Interac' END
        END                                                                  AS pf,
        25 + MOD((p.an * 53 + x.n * 29) * 17, 12000)                         AS amt,
        p.is_sanctioned                                                      AS sanctions_bool,
        (p.is_sanctioned AND MOD(x.n, 4) = 0)                                AS is_ml
    FROM prof p CROSS JOIN n12 x
),
/* -- (b) structuring: 5 deposits in [9000,10000) on ONE day -> R02 (+R05) ---- */
struct AS (
    SELECT
        'TS' || LPAD(p.an, 5, '0') || LPAD(x.n, 2, '0')                     AS transaction_id,
        DATEADD(hour, x.n * 3, DATEADD(day, MOD(p.an * 37, 690), DATE '2023-03-01')) AS ts,
        p.player_id, p.account_id, CAST(NULL AS VARCHAR)                     AS cp,
        'Deposit'                                                            AS ttype,
        'E-Wallet'                                                           AS pf,
        9000 + MOD(p.an * 17 + x.n * 7, 999)                                 AS amt,
        p.is_sanctioned                                                      AS sanctions_bool,
        TRUE                                                                 AS is_ml
    FROM prof p CROSS JOIN n5 x
    WHERE p.is_struct
),
/* -- (c) high velocity: 8 txns on ONE day -> R04 (+R05, +R07 spike) --------- */
burst AS (
    SELECT
        'TV' || LPAD(p.an, 5, '0') || LPAD(x.n, 2, '0')                     AS transaction_id,
        DATEADD(hour, x.n * 2, DATEADD(day, MOD(p.an * 41, 680), DATE '2023-06-01')) AS ts,
        p.player_id, p.account_id, CAST(NULL AS VARCHAR)                     AS cp,
        IFF(MOD(x.n, 2) = 0, 'Deposit', 'Withdrawal')                        AS ttype,
        'Credit Card'                                                        AS pf,
        1000 + MOD(p.an * 23 + x.n * 11, 3000)                               AS amt,
        p.is_sanctioned                                                      AS sanctions_bool,
        TRUE                                                                 AS is_ml
    FROM prof p CROSS JOIN n8 x
    WHERE p.is_burst
),
/* -- (d) rapid movement: deposit then 95% withdrawal +2h -> R03 ------------- */
rapid AS (
    SELECT
        'TR' || LPAD(p.an, 5, '0') || LPAD(x.n, 2, '0')                     AS transaction_id,
        DATEADD(hour, x.n * 2, DATEADD(day, MOD(p.an * 53, 670), DATE '2023-09-01')) AS ts,
        p.player_id, p.account_id, CAST(NULL AS VARCHAR)                     AS cp,
        IFF(x.n = 0, 'Deposit', 'Withdrawal')                               AS ttype,
        'Interac'                                                            AS pf,
        IFF(x.n = 0, 8000 + MOD(p.an * 13, 4000),
                     ROUND((8000 + MOD(p.an * 13, 4000)) * 0.95))            AS amt,
        p.is_sanctioned                                                      AS sanctions_bool,
        TRUE                                                                 AS is_ml
    FROM prof p CROSS JOIN n2 x
    WHERE p.is_rapid
),
/* -- (e) counterparty concentration: 4 x 6,000 to same payee -> R10 --------- */
conc AS (
    SELECT
        'TC' || LPAD(p.an, 5, '0') || LPAD(x.n, 2, '0')                     AS transaction_id,
        DATEADD(hour, x.n * 30, DATEADD(day, MOD(p.an * 29, 660), DATE '2023-11-01')) AS ts,  -- TIMESTAMP; ~4 days apart
        p.player_id, p.account_id, 'A99999'                                  AS cp,
        'Withdrawal'                                                         AS ttype,
        'Bank Transfer'                                                      AS pf,
        6000                                                                 AS amt,
        p.is_sanctioned                                                      AS sanctions_bool,
        TRUE                                                                 AS is_ml
    FROM prof p CROSS JOIN n4 x
    WHERE p.is_conc
),
all_txns AS (
    SELECT * FROM base
    UNION ALL SELECT * FROM struct
    UNION ALL SELECT * FROM burst
    UNION ALL SELECT * FROM rapid
    UNION ALL SELECT * FROM conc
)
SELECT
    transaction_id,
    TO_CHAR(ts, 'YYYY-MM-DD HH24:MI:SS')                              AS txn_timestamp,   -- text -> STAGING casts
    player_id,
    account_id,
    cp,
    ttype,
    pf,
    'CAD'                                                             AS currency,
    TO_VARCHAR(amt)                                                  AS amount,
    IFF(pf IN ('Crypto', 'Prepaid Card'), 'true', 'false')          AS is_high_risk_method,
    IFF(sanctions_bool, 'true', 'false')                            AS sanctions_flag,
    IFF(is_ml, 'true', 'false')                                     AS is_laundering,
    $LOAD_BATCH_ID                                                   AS load_batch_id,
    'synthetic_generator.sql'                                        AS source_file_name,
    ROW_NUMBER() OVER (ORDER BY transaction_id)                     AS file_row_number
FROM all_txns;

/* ============================================================================
   2) MONTHLY MARKET PERFORMANCE  ->  RAW.RAW_MARKET_PERFORMANCE
   36 months (2022-01 .. 2024-12). Units follow the source contract: $M for
   wagers/GGR, K for active accounts (STAGING scales up). Hold ~7.8%.
   The 2022 rows exist so VW_MARKET_FISCAL_YEAR has a prior year for YoY.
   ============================================================================ */
INSERT OVERWRITE INTO RAW.RAW_MARKET_PERFORMANCE
    (FISCAL_YEAR_QUARTER, YEAR_MONTH, CASH_WAGERS_M, NAGGR_M, ACTIVE_ACCOUNTS_K, ARPPA,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
WITH mth AS (
    SELECT SEQ4() AS m FROM TABLE(GENERATOR(ROWCOUNT => 36))                -- 0..35
),
calc AS (
    SELECT m,
           2022 + FLOOR(m / 12)                                     AS yr,
           MOD(m, 12) + 1                                           AS mon,
           420 + 8 * m + MOD(m * 37, 40)                            AS wagers_m       -- $M
    FROM mth
),
enriched AS (
    SELECT
        m, yr, mon, wagers_m,
        yr + IFF(mon >= 4, 1, 0)                                    AS fy,             -- Apr fiscal
        CASE WHEN mon IN (4,5,6) THEN 1 WHEN mon IN (7,8,9) THEN 2
             WHEN mon IN (10,11,12) THEN 3 ELSE 4 END               AS fq,
        ROUND(wagers_m * 0.078, 2)                                  AS naggr_m,        -- ~7.8% hold
        850 + 5 * m                                                 AS active_k
    FROM calc
)
SELECT
    'FY' || fy || '-Q' || fq                                        AS fiscal_year_quarter,
    yr || '-' || LPAD(mon, 2, '0')                                  AS year_month,
    TO_VARCHAR(wagers_m)                                            AS cash_wagers_m,
    TO_VARCHAR(naggr_m)                                             AS naggr_m,
    TO_VARCHAR(active_k)                                            AS active_accounts_k,
    TO_VARCHAR(ROUND(naggr_m * 1000.0 / active_k, 2))              AS arppa,           -- $ / active
    $LOAD_BATCH_ID, 'synthetic_generator.sql', m + 1
FROM enriched;

/* ============================================================================
   3) MARKET BY PRODUCT  ->  RAW.RAW_MARKET_BY_PRODUCT
   Each month split across 4 product categories (shares sum to 1.0).
   ============================================================================ */
INSERT OVERWRITE INTO RAW.RAW_MARKET_BY_PRODUCT
    (YEAR_MONTH, PRODUCT_CATEGORY, CASH_WAGERS_M, NAGGR_M, WAGER_SHARE, GGR_SHARE,
     LOAD_BATCH_ID, SOURCE_FILE_NAME, FILE_ROW_NUMBER)
WITH mth AS (
    SELECT SEQ4() AS m FROM TABLE(GENERATOR(ROWCOUNT => 36))
),
month_tot AS (
    SELECT m,
           (2022 + FLOOR(m / 12)) || '-' || LPAD(MOD(m, 12) + 1, 2, '0')   AS year_month,
           (420 + 8 * m + MOD(m * 37, 40))                                 AS wagers_m,
           ROUND((420 + 8 * m + MOD(m * 37, 40)) * 0.078, 2)               AS naggr_m
    FROM mth
),
prod AS (
    SELECT * FROM VALUES
        ('CASINO',         0.55, 0.60),
        ('SPORTS BETTING', 0.30, 0.25),
        ('POKER',          0.07, 0.06),
        ('LIVE DEALER',    0.08, 0.09)
    AS p (product_category, wager_share, ggr_share)
)
SELECT
    t.year_month,
    p.product_category,
    TO_VARCHAR(ROUND(t.wagers_m * p.wager_share, 2))               AS cash_wagers_m,
    TO_VARCHAR(ROUND(t.naggr_m  * p.ggr_share,   2))               AS naggr_m,
    TO_VARCHAR(p.wager_share)                                      AS wager_share,
    TO_VARCHAR(p.ggr_share)                                        AS ggr_share,
    $LOAD_BATCH_ID, 'synthetic_generator.sql',
    ROW_NUMBER() OVER (ORDER BY t.year_month, p.product_category)  AS file_row_number
FROM month_tot t CROSS JOIN prod p;

/* ============================================================================
   4) POST-GENERATION CHECKS
   ============================================================================ */
SELECT 'RAW_TRANSACTIONS'       AS TABLE_NAME, COUNT(*) AS ROWS,
       MIN(TRY_TO_TIMESTAMP_NTZ(TXN_TIMESTAMP)) AS MIN_TS,
       MAX(TRY_TO_TIMESTAMP_NTZ(TXN_TIMESTAMP)) AS MAX_TS
FROM RAW.RAW_TRANSACTIONS
UNION ALL
SELECT 'RAW_MARKET_PERFORMANCE', COUNT(*), NULL, NULL FROM RAW.RAW_MARKET_PERFORMANCE
UNION ALL
SELECT 'RAW_MARKET_BY_PRODUCT',  COUNT(*), NULL, NULL FROM RAW.RAW_MARKET_BY_PRODUCT;

-- Expected magnitudes: ~5,300 transactions, 36 market months, 144 product rows.
-- Sanity on the synthetic ground-truth label + high-risk methods:
SELECT
    SUM(IFF(IS_LAUNDERING   = 'true', 1, 0)) AS LAUNDERING_ROWS,
    SUM(IFF(SANCTIONS_FLAG  = 'true', 1, 0)) AS SANCTIONS_ROWS,
    SUM(IFF(IS_HIGH_RISK_METHOD = 'true', 1, 0)) AS HIGH_RISK_METHOD_ROWS,
    SUM(IFF(TRY_TO_DECIMAL(AMOUNT, 18, 2) >= 10000, 1, 0)) AS LARGE_TXNS
FROM RAW.RAW_TRANSACTIONS;
