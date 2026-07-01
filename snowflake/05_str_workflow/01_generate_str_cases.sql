/* ============================================================================
   Phase 9 — STR 01: Generate Investigation Cases
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Converts ESCALATED AML alerts into STR investigation cases (one case per
   escalated transaction — the highest-risk escalated alert on that transaction).
   Assigns an analyst by priority tier, sets priority/open date, and synthesizes a
   deterministic lifecycle (status, close date, STR-submitted, closure reason).
   SLA fields are computed in 02_case_sla_logic.sql.

   "Only escalated/high-risk alerts become cases" is enforced by the WHERE filter.
   Run after Phase 8. Uses WH_TRANSFORM. SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

INSERT OVERWRITE INTO CORE.FACT_STR_CASES
    (CASE_ID, ALERT_KEY, PLAYER_KEY, ANALYST_KEY, STATUS_KEY, OPEN_DATE_KEY,
     CLOSE_DATE_KEY, CASE_PRIORITY, SLA_DAYS, INVESTIGATION_DAYS, SLA_BREACHED,
     STR_SUBMITTED_FLAG, CLOSURE_REASON, SOURCE_SYSTEM, LOAD_BATCH_ID)
WITH esc AS (                                            -- escalated alerts only
    SELECT ALERT_KEY, PLAYER_KEY, DATE_KEY AS OPEN_DATE_KEY, RISK_SCORE, LOAD_BATCH_ID,
           TO_DATE(TO_CHAR(DATE_KEY), 'YYYYMMDD') AS OPEN_DATE
    FROM CORE.FACT_AML_ALERTS
    WHERE IS_ESCALATED = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY TRANSACTION_KEY ORDER BY RISK_SCORE DESC, ALERT_KEY) = 1
),
base AS (
    SELECT esc.*,
        CASE WHEN RISK_SCORE >= 90 THEN 'Critical'
             WHEN RISK_SCORE >= 80 THEN 'High'
             ELSE 'Medium' END                                     AS CASE_PRIORITY,
        (MOD(ABS(HASH(ALERT_KEY, 7)), 100) < 55)                   AS IS_CLOSED,
        CASE WHEN RISK_SCORE >= 90 THEN 2 + MOD(ABS(HASH(ALERT_KEY, 1)), 7)    -- 2-8 days
             WHEN RISK_SCORE >= 80 THEN 4 + MOD(ABS(HASH(ALERT_KEY, 1)), 11)   -- 4-14
             ELSE 6 + MOD(ABS(HASH(ALERT_KEY, 1)), 15) END         AS DURATION_DAYS,  -- 6-20
        CASE WHEN RISK_SCORE >= 80                                              -- senior/lead for High+
             THEN CASE MOD(ABS(HASH(ALERT_KEY, 3)), 3) WHEN 0 THEN 'AN-003' WHEN 1 THEN 'AN-007' ELSE 'AN-014' END
             ELSE CASE MOD(ABS(HASH(ALERT_KEY, 3)), 2) WHEN 0 THEN 'AN-001' ELSE 'AN-011' END
        END                                                        AS ANALYST_ID
    FROM esc
),
life AS (
    SELECT base.*,
        IFF(IS_CLOSED, 5,                                          -- 5 = Closed
            CASE MOD(ABS(HASH(ALERT_KEY, 9)), 4)                   -- open: New/Review/Escalated/STR_Sub
                 WHEN 0 THEN 1 WHEN 1 THEN 2 WHEN 2 THEN 3 ELSE 4 END) AS STATUS_KEY
    FROM base
),
final AS (
    SELECT life.*,
        IFF(IS_CLOSED, TO_NUMBER(TO_CHAR(DATEADD(day, DURATION_DAYS, OPEN_DATE), 'YYYYMMDD')), NULL) AS CLOSE_DATE_KEY,
        CASE WHEN STATUS_KEY = 4 THEN TRUE                          -- open, STR submitted
             WHEN IS_CLOSED THEN (MOD(ABS(HASH(ALERT_KEY, 11)), 100)
                                  < IFF(CASE_PRIORITY = 'Critical', 70, IFF(CASE_PRIORITY = 'High', 55, 35)))
             ELSE FALSE END                                        AS STR_SUBMITTED_FLAG
    FROM life
)
SELECT
    'CASE-' || LPAD(ROW_NUMBER() OVER (ORDER BY f.ALERT_KEY), 6, '0') AS CASE_ID,
    f.ALERT_KEY,
    f.PLAYER_KEY,
    an.ANALYST_KEY,
    f.STATUS_KEY,
    f.OPEN_DATE_KEY,
    f.CLOSE_DATE_KEY,
    f.CASE_PRIORITY,
    NULL AS SLA_DAYS,                 -- set in 02
    NULL AS INVESTIGATION_DAYS,       -- set in 02
    NULL AS SLA_BREACHED,             -- set in 02
    f.STR_SUBMITTED_FLAG,
    CASE WHEN NOT f.IS_CLOSED           THEN NULL
         WHEN f.STR_SUBMITTED_FLAG      THEN 'STR Filed'
         ELSE CASE MOD(ABS(HASH(f.ALERT_KEY, 13)), 3)
              WHEN 0 THEN 'No Further Action' WHEN 1 THEN 'False Positive' ELSE 'Insufficient Evidence' END
    END AS CLOSURE_REASON,
    'STR_WORKFLOW',
    f.LOAD_BATCH_ID
FROM final f
JOIN CORE.DIM_ANALYST an ON an.ANALYST_ID = f.ANALYST_ID;

-- Case count + confirmation that every case came from an escalated alert.
SELECT COUNT(*) AS CASES,
       SUM(IFF(a.IS_ESCALATED, 0, 1)) AS CASES_FROM_NON_ESCALATED   -- must be 0
FROM CORE.FACT_STR_CASES c
JOIN CORE.FACT_AML_ALERTS a ON a.ALERT_KEY = c.ALERT_KEY;
