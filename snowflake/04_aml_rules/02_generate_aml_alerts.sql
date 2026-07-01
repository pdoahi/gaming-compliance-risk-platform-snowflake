/* ============================================================================
   Phase 8 — AML 02: Generate AML Alerts
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Runs the 11 rule typologies over CORE.FACT_TRANSACTIONS, unions the matches
   (one row per transaction x rule), resolves keys, and inserts into
   CORE.FACT_AML_ALERTS with the rule's BASE_RISK_SCORE and DEFAULT_SEVERITY.
   Final scoring / severity / escalation is applied in 03_alert_scoring_logic.sql.

   Each rule is small and explainable; thresholds live in the WHERE/HAVING clauses.
   Run after 01 (seed). Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

INSERT OVERWRITE INTO CORE.FACT_AML_ALERTS
    (ALERT_ID, TRANSACTION_KEY, ALERT_TYPE_KEY, PLAYER_KEY, ACCOUNT_KEY, DATE_KEY,
     STATUS_KEY, ALERT_TIMESTAMP, SEVERITY, RISK_SCORE, IS_ESCALATED,
     ALERT_DESCRIPTION, SOURCE_SYSTEM, LOAD_BATCH_ID)
WITH tx AS (
    SELECT * FROM CORE.FACT_TRANSACTIONS
),
/* R01 Large transaction (>= 10,000) */
r01 AS (SELECT TRANSACTION_KEY, 1 AS ALERT_TYPE_KEY FROM tx WHERE AMOUNT >= 10000),
/* R02 Structuring: >=3 in [9000,10000) per account */
r02 AS (
    SELECT TRANSACTION_KEY, 2 AS ALERT_TYPE_KEY FROM (
        SELECT TRANSACTION_KEY, COUNT(*) OVER (PARTITION BY ACCOUNT_KEY) AS c
        FROM tx WHERE AMOUNT >= 9000 AND AMOUNT < 10000)
    WHERE c >= 3),
/* R03 Rapid movement: deposit then >=90% withdrawal within 6h */
r03 AS (
    SELECT w.TRANSACTION_KEY, 3 AS ALERT_TYPE_KEY
    FROM tx d JOIN tx w
      ON w.ACCOUNT_KEY = d.ACCOUNT_KEY
     AND d.TRANSACTION_TYPE = 'Deposit' AND w.TRANSACTION_TYPE = 'Withdrawal'
     AND w.TRANSACTION_TIMESTAMP >  d.TRANSACTION_TIMESTAMP
     AND w.TRANSACTION_TIMESTAMP <= DATEADD(hour, 6, d.TRANSACTION_TIMESTAMP)
     AND w.AMOUNT >= 0.90 * d.AMOUNT),
/* R04 High velocity: >=8 txns per account per day */
r04 AS (
    SELECT TRANSACTION_KEY, 4 AS ALERT_TYPE_KEY FROM (
        SELECT TRANSACTION_KEY, COUNT(*) OVER (PARTITION BY ACCOUNT_KEY, DATE_KEY) AS c FROM tx)
    WHERE c >= 8),
/* R05 Repeated sub-threshold: >=5 txns <10,000 per account per day */
r05 AS (
    SELECT TRANSACTION_KEY, 5 AS ALERT_TYPE_KEY FROM (
        SELECT TRANSACTION_KEY, COUNT(*) OVER (PARTITION BY ACCOUNT_KEY, DATE_KEY) AS c
        FROM tx WHERE AMOUNT < 10000)
    WHERE c >= 5),
/* R06 High-risk payment method (Crypto/Prepaid) >= 5,000 */
r06 AS (SELECT TRANSACTION_KEY, 6 AS ALERT_TYPE_KEY FROM tx
        WHERE PAYMENT_FORMAT IN ('Crypto', 'Prepaid Card') AND AMOUNT >= 5000),
/* R07 Unusual spike: daily total >= 5x account median (and >= 5,000) */
r07 AS (
    WITH daily AS (SELECT ACCOUNT_KEY, DATE_KEY, SUM(AMOUNT) AS DAY_TOTAL FROM tx GROUP BY 1, 2),
         med   AS (SELECT DISTINCT ACCOUNT_KEY,
                          PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY DAY_TOTAL)
                              OVER (PARTITION BY ACCOUNT_KEY) AS MED_DAY
                   FROM daily)
    SELECT t.TRANSACTION_KEY, 7 AS ALERT_TYPE_KEY
    FROM tx t
    JOIN daily d ON d.ACCOUNT_KEY = t.ACCOUNT_KEY AND d.DATE_KEY = t.DATE_KEY
    JOIN med   m ON m.ACCOUNT_KEY = t.ACCOUNT_KEY
    WHERE d.DAY_TOTAL >= 5000 AND m.MED_DAY > 0 AND d.DAY_TOTAL >= 5 * m.MED_DAY),
/* R08 Dormant reactivation: gap >=30 days then >= 5,000 */
r08 AS (
    SELECT TRANSACTION_KEY, 8 AS ALERT_TYPE_KEY FROM (
        SELECT TRANSACTION_KEY, AMOUNT, TRANSACTION_TIMESTAMP,
               LAG(TRANSACTION_TIMESTAMP) OVER (PARTITION BY ACCOUNT_KEY ORDER BY TRANSACTION_TIMESTAMP) AS PREV_TS
        FROM tx)
    WHERE PREV_TS IS NOT NULL AND DATEDIFF(day, PREV_TS, TRANSACTION_TIMESTAMP) >= 30 AND AMOUNT >= 5000),
/* R09 High-risk player/account (>= 3,000 by High-risk customer) */
r09 AS (
    SELECT t.TRANSACTION_KEY, 9 AS ALERT_TYPE_KEY
    FROM tx t
    JOIN CORE.DIM_PLAYER  p ON p.PLAYER_KEY  = t.PLAYER_KEY
    LEFT JOIN CORE.DIM_ACCOUNT a ON a.ACCOUNT_KEY = t.ACCOUNT_KEY
    WHERE (p.KYC_RISK_LEVEL = 'High' OR a.ACCOUNT_RISK_RATING = 'High') AND t.AMOUNT >= 3000),
/* R10 Counterparty concentration: >=4 txns totalling >=20,000 to same payee */
r10 AS (
    SELECT TRANSACTION_KEY, 10 AS ALERT_TYPE_KEY FROM (
        SELECT TRANSACTION_KEY,
               COUNT(*)    OVER (PARTITION BY ACCOUNT_KEY, COUNTERPARTY_ACCOUNT_KEY) AS PC,
               SUM(AMOUNT) OVER (PARTITION BY ACCOUNT_KEY, COUNTERPARTY_ACCOUNT_KEY) AS PS
        FROM tx WHERE COUNTERPARTY_ACCOUNT_KEY IS NOT NULL)
    WHERE PC >= 4 AND PS >= 20000),
/* R11 Sanctions / watchlist: any transaction by a watchlisted player (mandatory) */
r11 AS (
    SELECT t.TRANSACTION_KEY, 11 AS ALERT_TYPE_KEY
    FROM tx t JOIN CORE.DIM_PLAYER p ON p.PLAYER_KEY = t.PLAYER_KEY
    WHERE p.WATCHLIST_FLAG = TRUE),
matches AS (
    SELECT * FROM r01 UNION ALL SELECT * FROM r02 UNION ALL SELECT * FROM r03
    UNION ALL SELECT * FROM r04 UNION ALL SELECT * FROM r05 UNION ALL SELECT * FROM r06
    UNION ALL SELECT * FROM r07 UNION ALL SELECT * FROM r08 UNION ALL SELECT * FROM r09
    UNION ALL SELECT * FROM r10 UNION ALL SELECT * FROM r11
)
SELECT
    'ALRT-' || LPAD(m.TRANSACTION_KEY, 9, '0') || '-R' || LPAD(m.ALERT_TYPE_KEY, 2, '0') AS ALERT_ID,
    m.TRANSACTION_KEY,
    m.ALERT_TYPE_KEY,
    t.PLAYER_KEY,
    t.ACCOUNT_KEY,
    t.DATE_KEY,
    1                                                   AS STATUS_KEY,     -- 'New'
    t.TRANSACTION_TIMESTAMP                             AS ALERT_TIMESTAMP,
    at.DEFAULT_SEVERITY                                 AS SEVERITY,       -- refined in scoring (03)
    at.BASE_RISK_SCORE                                  AS RISK_SCORE,     -- base; modifiers in scoring (03)
    FALSE                                               AS IS_ESCALATED,   -- set in scoring (03)
    at.RULE_CODE || ': ' || at.RULE_NAME                AS ALERT_DESCRIPTION,
    'AML_ENGINE'                                        AS SOURCE_SYSTEM,
    t.LOAD_BATCH_ID
FROM matches m
JOIN CORE.FACT_TRANSACTIONS t  ON t.TRANSACTION_KEY = m.TRANSACTION_KEY
JOIN CORE.DIM_ALERT_TYPE    at ON at.ALERT_TYPE_KEY = m.ALERT_TYPE_KEY;

-- Alerts by rule (sanity view of what fired).
SELECT at.RULE_CODE, at.RULE_NAME, COUNT(*) AS ALERTS
FROM CORE.FACT_AML_ALERTS a JOIN CORE.DIM_ALERT_TYPE at ON at.ALERT_TYPE_KEY = a.ALERT_TYPE_KEY
GROUP BY at.RULE_CODE, at.RULE_NAME ORDER BY at.RULE_CODE;
