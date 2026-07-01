/* ============================================================================
   Phase 8 — AML 03: Alert Scoring, Severity & Escalation
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Turns each alert's BASE_RISK_SCORE (from its rule) into a final, explainable
   RISK_SCORE, then derives SEVERITY and the ESCALATION flag.

   Scoring model (transparent, additive; capped at 100):
     final = base_risk_score (from DIM_ALERT_TYPE)
           + 10  if the same transaction triggered MULTIPLE typologies
           + 10  if the player is PEP / watchlisted / High KYC-risk
   Severity bands:  >=90 Critical | >=70 High | >=40 Medium | else Low
   Escalation:      IS_ESCALATED = (final RISK_SCORE >= 70) -> feeds Phase 9 (STR cases)

   Run after 02 (generate). Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

/* ---- Modifier 1: multiple typologies on the same transaction (+10) --------- */
UPDATE CORE.FACT_AML_ALERTS a
SET RISK_SCORE = LEAST(100, a.RISK_SCORE + 10)
FROM (
    SELECT TRANSACTION_KEY
    FROM CORE.FACT_AML_ALERTS
    GROUP BY TRANSACTION_KEY
    HAVING COUNT(*) > 1
) multi
WHERE a.TRANSACTION_KEY = multi.TRANSACTION_KEY;

/* ---- Modifier 2: elevated-risk customer (PEP / watchlist / High KYC) (+10) - */
UPDATE CORE.FACT_AML_ALERTS a
SET RISK_SCORE = LEAST(100, a.RISK_SCORE + 10)
FROM CORE.DIM_PLAYER p
WHERE a.PLAYER_KEY = p.PLAYER_KEY
  AND (p.PEP_FLAG = TRUE OR p.WATCHLIST_FLAG = TRUE OR p.KYC_RISK_LEVEL = 'High');

/* ---- Derive final SEVERITY and ESCALATION from the score ------------------- */
UPDATE CORE.FACT_AML_ALERTS
SET SEVERITY = CASE
                   WHEN RISK_SCORE >= 90 THEN 'Critical'
                   WHEN RISK_SCORE >= 70 THEN 'High'
                   WHEN RISK_SCORE >= 40 THEN 'Medium'
                   ELSE 'Low'
               END,
    IS_ESCALATED = (RISK_SCORE >= 70),
    STATUS_KEY   = IFF(RISK_SCORE >= 70, 3, STATUS_KEY);   -- escalated alerts -> 'Escalated'

/* ============================================================================
   Scoring validation
   ============================================================================ */

-- Distribution by severity + escalation.
SELECT SEVERITY,
       COUNT(*)                        AS ALERTS,
       SUM(IFF(IS_ESCALATED, 1, 0))    AS ESCALATED,
       MIN(RISK_SCORE)                 AS MIN_SCORE,
       MAX(RISK_SCORE)                 AS MAX_SCORE
FROM CORE.FACT_AML_ALERTS
GROUP BY SEVERITY
ORDER BY MAX_SCORE DESC;

-- Explainability spot check: alert, rule, base vs final score, escalation.
SELECT a.ALERT_ID, at.RULE_CODE, at.BASE_RISK_SCORE, a.RISK_SCORE, a.SEVERITY, a.IS_ESCALATED
FROM CORE.FACT_AML_ALERTS a
JOIN CORE.DIM_ALERT_TYPE at ON at.ALERT_TYPE_KEY = a.ALERT_TYPE_KEY
ORDER BY a.RISK_SCORE DESC
LIMIT 10;

-- Every alert must connect to a real transaction (no orphans).
SELECT COUNT(*) AS ORPHAN_ALERTS
FROM CORE.FACT_AML_ALERTS a
LEFT JOIN CORE.FACT_TRANSACTIONS t ON t.TRANSACTION_KEY = a.TRANSACTION_KEY
WHERE t.TRANSACTION_KEY IS NULL;
