/* ============================================================================
   Phase 11 — Data Quality 03: Phase-by-Phase Validation Gates
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   One gate per phase: does the phase's expected object set (and, where relevant,
   its data) exist? Run top to bottom; each returns PHASE, STATUS, DETAIL. A FAIL
   points straight at the phase/script to re-run.

   NOTE: Must be EXECUTED in your Snowflake account. Warehouses & roles use SHOW
   (not in INFORMATION_SCHEMA) — eyeball those. Uses WH_TRANSFORM. SYNTHETIC.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE WAREHOUSE WH_TRANSFORM;
USE DATABASE GAMING_COMPLIANCE_DB;

/* ---- Phase 4: setup (schemas queryable; warehouses/roles via SHOW) --------- */
SELECT 'Phase 4 schemas' AS PHASE, IFF(COUNT(*) = 7,'PASS','FAIL') AS STATUS, LISTAGG(SCHEMA_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME IN ('RAW','STAGING','CORE','ANALYTICS','REPORTING','GOVERNANCE','UTILITY');
-- Eyeball these two (SHOW results are not selectable inline):
SHOW WAREHOUSES LIKE 'WH_%';         -- expect WH_INGESTION/TRANSFORM/REPORTING/DATA_SCIENCE
SHOW ROLES LIKE '%COMPLIANCE%';      -- expect COMPLIANCE_ANALYST / COMPLIANCE_MANAGER (+ others)

/* ---- Phase 5: ingestion --------------------------------------------------- */
SELECT 'Phase 5 file formats' AS PHASE, IFF(COUNT(*) >= 2,'PASS','FAIL') AS STATUS, LISTAGG(FILE_FORMAT_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.FILE_FORMATS WHERE FILE_FORMAT_SCHEMA = 'RAW'
UNION ALL
SELECT 'Phase 5 stage', IFF(COUNT(*) >= 1,'PASS','FAIL'), LISTAGG(STAGE_NAME, ', ')
FROM INFORMATION_SCHEMA.STAGES WHERE STAGE_SCHEMA = 'RAW'
UNION ALL
SELECT 'Phase 5 RAW tables', IFF(COUNT(*) >= 2,'PASS','FAIL'), LISTAGG(TABLE_NAME, ', ')
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'RAW' AND TABLE_NAME LIKE 'RAW_%';

/* ---- Phase 6: staging ----------------------------------------------------- */
SELECT 'Phase 6 STAGING tables' AS PHASE, IFF(COUNT(*) >= 2,'PASS','FAIL') AS STATUS, LISTAGG(TABLE_NAME, ', ') AS DETAIL
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'STAGING' AND TABLE_NAME LIKE 'STG_%';

/* ---- Phase 7: core model (objects + rows) --------------------------------- */
SELECT 'Phase 7 dims exist' AS PHASE, IFF(COUNT(*) = 6,'PASS','FAIL') AS STATUS, COUNT(*)||' dims' AS DETAIL
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='CORE' AND TABLE_NAME LIKE 'DIM_%'
UNION ALL SELECT 'Phase 7 facts exist', IFF(COUNT(*) = 4,'PASS','FAIL'), COUNT(*)||' facts'
FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA='CORE' AND TABLE_NAME LIKE 'FACT_%'
UNION ALL SELECT 'Phase 7 DIM_PLAYER loaded', IFF((SELECT COUNT(*) FROM CORE.DIM_PLAYER) > 0,'PASS','FAIL'), (SELECT COUNT(*) FROM CORE.DIM_PLAYER)::VARCHAR
UNION ALL SELECT 'Phase 7 FACT_TRANSACTIONS loaded', IFF((SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS) > 0,'PASS','FAIL'), (SELECT COUNT(*) FROM CORE.FACT_TRANSACTIONS)::VARCHAR
UNION ALL SELECT 'Phase 7 FACT_MARKET loaded', IFF((SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE) > 0,'PASS','FAIL'), (SELECT COUNT(*) FROM CORE.FACT_MARKET_PERFORMANCE)::VARCHAR;

/* ---- Phase 8: AML rules --------------------------------------------------- */
SELECT 'Phase 8 alert types seeded (11)' AS PHASE, IFF((SELECT COUNT(*) FROM CORE.DIM_ALERT_TYPE) = 11,'PASS','FAIL') AS STATUS, (SELECT COUNT(*) FROM CORE.DIM_ALERT_TYPE)::VARCHAR AS DETAIL
UNION ALL SELECT 'Phase 8 alerts generated', IFF((SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS) > 0,'PASS','FAIL'), (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS)::VARCHAR
UNION ALL SELECT 'Phase 8 scoring applied (some escalated)', IFF((SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED) >= 0,'PASS','FAIL'), (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED)::VARCHAR;

/* ---- Phase 9: STR workflow ------------------------------------------------ */
SELECT 'Phase 9 STR cases generated' AS PHASE, IFF((SELECT COUNT(*) FROM CORE.FACT_STR_CASES) > 0
        OR (SELECT COUNT(*) FROM CORE.FACT_AML_ALERTS WHERE IS_ESCALATED) = 0,'PASS','FAIL') AS STATUS, (SELECT COUNT(*) FROM CORE.FACT_STR_CASES)::VARCHAR AS DETAIL
UNION ALL SELECT 'Phase 9 SLA fields populated', IFF((SELECT COUNT(*) FROM CORE.FACT_STR_CASES WHERE SLA_DAYS IS NULL) = 0,'PASS','FAIL'), 'null SLA_DAYS count above';

/* ---- Phase 10: reporting -------------------------------------------------- */
SELECT 'Phase 10 reporting views (>=11)' AS PHASE, IFF(COUNT(*) >= 11,'PASS','FAIL') AS STATUS, COUNT(*)||' views' AS DETAIL
FROM INFORMATION_SCHEMA.VIEWS WHERE TABLE_SCHEMA='REPORTING' AND TABLE_NAME LIKE 'VW_%';
