/* ============================================================================
   Detection Performance — AML rule engine vs. synthetic ground truth
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Scores the rule engine against the synthetic `IS_LAUNDERING` label the data
   generator injects, using a transaction-level confusion matrix:
     - A transaction is FLAGGED if the AML engine raised >= 1 alert on it.
     - It is POSITIVE (ground truth) if `STG_TRANSACTIONS.IS_LAUNDERING = TRUE`.
   Then reports Recall, Precision, F1 and Accuracy — the same headline metrics the
   analyst/Python version reports, computed here in pure SQL.

   NOTE — OPTIMISTIC BY CONSTRUCTION: the synthetic laundering patterns are the very
   patterns the rules target, so these figures show the rules detect their intended
   typologies — they are NOT expected production performance. On real, unlabelled,
   messier data both recall and precision would be lower and thresholds would need
   recalibration. (This mirrors the caveat in the analyst version.)

   Reads only. Role DATA_ENGINEER, warehouse WH_TRANSFORM. Synthetic data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- 1) Headline metrics (confusion matrix + Recall / Precision / F1) ------ */
WITH labelled AS (
    SELECT
        t.TRANSACTION_KEY,
        s.IS_LAUNDERING                                   AS IS_LAUNDERING,     -- ground truth
        IFF(a.TRANSACTION_KEY IS NOT NULL, TRUE, FALSE)   AS FLAGGED            -- engine raised an alert
    FROM CORE.FACT_TRANSACTIONS t
    JOIN STAGING.STG_TRANSACTIONS s
      ON s.TRANSACTION_ID = t.TRANSACTION_ID AND s.IS_VALID
    LEFT JOIN (SELECT DISTINCT TRANSACTION_KEY FROM CORE.FACT_AML_ALERTS) a
      ON a.TRANSACTION_KEY = t.TRANSACTION_KEY
),
cm AS (
    SELECT
        SUM(IFF(IS_LAUNDERING     AND FLAGGED,     1, 0)) AS TP,
        SUM(IFF(NOT IS_LAUNDERING AND FLAGGED,     1, 0)) AS FP,
        SUM(IFF(IS_LAUNDERING     AND NOT FLAGGED, 1, 0)) AS FN,
        SUM(IFF(NOT IS_LAUNDERING AND NOT FLAGGED, 1, 0)) AS TN
    FROM labelled
)
SELECT
    TP, FP, FN, TN,
    (TP + FP + FN + TN)                                    AS TOTAL_TXNS,
    ROUND(100.0 * TP / NULLIF(TP + FN, 0), 1)              AS RECALL_PCT,     -- of true laundering, % flagged
    ROUND(100.0 * TP / NULLIF(TP + FP, 0), 1)              AS PRECISION_PCT,  -- of flagged, % truly laundering
    ROUND(2.0  * TP / NULLIF(2 * TP + FP + FN, 0), 3)      AS F1,
    ROUND(100.0 * (TP + TN) / NULLIF(TP + FP + FN + TN, 0), 1) AS ACCURACY_PCT
FROM cm;

/* ---- 2) Flag rate by ground-truth class (sanity + separation) ------------- */
-- Laundering transactions should be flagged at a far higher rate than clean ones.
SELECT
    IFF(s.IS_LAUNDERING, 'Laundering (positive)', 'Clean (negative)') AS CLASS,
    COUNT(*)                                                          AS TXNS,
    SUM(IFF(a.TRANSACTION_KEY IS NOT NULL, 1, 0))                     AS FLAGGED,
    ROUND(100.0 * SUM(IFF(a.TRANSACTION_KEY IS NOT NULL, 1, 0)) / NULLIF(COUNT(*), 0), 1) AS FLAG_RATE_PCT
FROM CORE.FACT_TRANSACTIONS t
JOIN STAGING.STG_TRANSACTIONS s
  ON s.TRANSACTION_ID = t.TRANSACTION_ID AND s.IS_VALID
LEFT JOIN (SELECT DISTINCT TRANSACTION_KEY FROM CORE.FACT_AML_ALERTS) a
  ON a.TRANSACTION_KEY = t.TRANSACTION_KEY
GROUP BY 1
ORDER BY 1;
