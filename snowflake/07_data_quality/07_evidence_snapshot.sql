/* ============================================================================
   Evidence Snapshot — screenshot-friendly (vertical) KPI outputs
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   The one-row summary views (e.g. VW_EXECUTIVE_OVERVIEW) are very WIDE (~17
   columns), so a single screenshot can't show every column. These queries
   TRANSPOSE the wide KPIs into a tall metric -> value list that fits in one
   screenshot — cleaner evidence for the README Execution Evidence section.

   Reads only. Role DATA_ENGINEER, warehouse WH_REPORTING. Synthetic data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_REPORTING;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- A) Executive KPI snapshot (transposed) -> 01_kpi_snapshot.png --------- */
WITH e AS (SELECT * FROM REPORTING.VW_EXECUTIVE_OVERVIEW)
SELECT SECTION, METRIC, VALUE FROM (
    SELECT 1  AS ORD,'Transactions' AS SECTION,'Total transactions'      AS METRIC, TO_VARCHAR(TOTAL_TRANSACTIONS)        AS VALUE FROM e
    UNION ALL SELECT 2 ,'Transactions','Total transaction value', TO_VARCHAR(TOTAL_TRANSACTION_VALUE) FROM e
    UNION ALL SELECT 3 ,'Market','Total wagers',                  TO_VARCHAR(TOTAL_WAGERS)            FROM e
    UNION ALL SELECT 4 ,'Market','Total GGR',                     TO_VARCHAR(TOTAL_GGR)               FROM e
    UNION ALL SELECT 5 ,'Market','Hold %',                        TO_VARCHAR(HOLD_PCT)                FROM e
    UNION ALL SELECT 6 ,'Market','Active accounts (latest)',      TO_VARCHAR(LATEST_ACTIVE_ACCOUNTS)  FROM e
    UNION ALL SELECT 7 ,'Market','GGR per active',                TO_VARCHAR(GGR_PER_ACTIVE)          FROM e
    UNION ALL SELECT 8 ,'AML','Alerts',                           TO_VARCHAR(AML_ALERTS)              FROM e
    UNION ALL SELECT 9 ,'AML','Escalated alerts',                 TO_VARCHAR(ESCALATED_ALERTS)        FROM e
    UNION ALL SELECT 10,'AML','Escalation rate %',                TO_VARCHAR(ESCALATION_RATE_PCT)     FROM e
    UNION ALL SELECT 11,'AML','Avg risk score',                   TO_VARCHAR(AVG_RISK_SCORE)          FROM e
    UNION ALL SELECT 12,'STR','Total cases',                      TO_VARCHAR(TOTAL_CASES)             FROM e
    UNION ALL SELECT 13,'STR','Open investigations',              TO_VARCHAR(OPEN_INVESTIGATIONS)     FROM e
    UNION ALL SELECT 14,'STR','STRs submitted',                   TO_VARCHAR(STRS_SUBMITTED)          FROM e
    UNION ALL SELECT 15,'STR','STR conversion %',                 TO_VARCHAR(STR_CONVERSION_RATE_PCT) FROM e
    UNION ALL SELECT 16,'STR','Avg investigation days',           TO_VARCHAR(AVG_INVESTIGATION_DAYS)  FROM e
    UNION ALL SELECT 17,'STR','SLA compliance %',                 TO_VARCHAR(SLA_COMPLIANCE_PCT)      FROM e
)
ORDER BY ORD;

/* ---- B) AML by typology (narrowed, all 11 rules) -> 02_aml_typologies.png -- */
SELECT RULE_CODE, RULE_NAME, ALERTS, ESCALATED, AVG_RISK_SCORE, PCT_OF_ALERTS
FROM REPORTING.VW_ALERT_TYPOLOGY_BREAKDOWN
ORDER BY ALERTS DESC;

/* Reconciliation (21/21) -> use 06_reconciliation_verification.sql
   Setup verification (18/18) -> use 05_setup_verification.sql
   Both already return narrow, tall grids that screenshot cleanly. */
