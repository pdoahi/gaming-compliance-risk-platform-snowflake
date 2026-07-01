/* ============================================================================
   Phase 12 — Governance & Security Policies
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Column masking, row-access, and data-classification tags for regulated-data
   handling. Policies are DEFINED in the GOVERNANCE schema and APPLIED to CORE
   objects.

   RUN ORDER: this depends on the core model existing, so run it AFTER Phase 7
   (03_core_model). Policy creation needs elevated privileges — shown as
   ACCOUNTADMIN; in a real account, delegate via a dedicated security role.

   ⚠️ SYNTHETIC data only. There is no real PII here — these policies DEMONSTRATE
   the controls a real regulated deployment would use. No secrets appear anywhere.

   ⚠️ DEMO GOVERNANCE PATTERN — NOT production access control. Specifically:
     - The row-access policy hard-codes an allowed region ('REGION-A') for the
       analyst role. Production would resolve entitlements from a user→region
       MAPPING TABLE (or identity-provider claims), not a literal.
     - Masking/row-access are keyed off CURRENT_ROLE() only. Production would add
       SoD-controlled security roles, IdP/SSO + SCIM, audit logging/access review,
       environment separation (dev/prod), and formal data-classification governance.
     - ACCOUNTADMIN is used for convenience; production delegates to a dedicated,
       least-privilege security/governance role.
   See docs/governance_model.md → "Demo Governance Limitations" for the full list.
   ============================================================================ */

USE ROLE ACCOUNTADMIN;                 -- or a role granted CREATE MASKING/ROW ACCESS POLICY + CREATE TAG
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA GOVERNANCE;

/* ============================================================================
   1. Data-classification tags
   ============================================================================ */
CREATE OR REPLACE TAG GOVERNANCE.DATA_CLASSIFICATION
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED'
    COMMENT = 'Sensitivity classification for objects/columns.';

CREATE OR REPLACE TAG GOVERNANCE.PII
    ALLOWED_VALUES 'IDENTIFIER', 'QUASI_IDENTIFIER', 'NONE'
    COMMENT = 'Marks columns that would be PII in a real (non-synthetic) deployment.';

-- Classify objects (run after core model exists)
ALTER TABLE CORE.DIM_PLAYER              SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'CONFIDENTIAL';
ALTER TABLE CORE.DIM_ACCOUNT             SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'CONFIDENTIAL';
ALTER TABLE CORE.FACT_TRANSACTIONS       SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'CONFIDENTIAL';
ALTER TABLE CORE.FACT_AML_ALERTS         SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'RESTRICTED';
ALTER TABLE CORE.FACT_STR_CASES          SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'RESTRICTED';
ALTER TABLE CORE.FACT_MARKET_PERFORMANCE SET TAG GOVERNANCE.DATA_CLASSIFICATION = 'INTERNAL';

-- Mark the identifier columns (illustrative; real PII would be name/DOB/email/etc.)
ALTER TABLE CORE.DIM_PLAYER  MODIFY COLUMN PLAYER_ID  SET TAG GOVERNANCE.PII = 'IDENTIFIER';
ALTER TABLE CORE.DIM_ACCOUNT MODIFY COLUMN ACCOUNT_ID SET TAG GOVERNANCE.PII = 'IDENTIFIER';

/* ============================================================================
   2. Column masking policy — player / account identifiers
   ============================================================================
   Full value for owners/engineers/managers; partial for analysts; fully masked
   for anyone else. Demonstrates least-exposure of identifiers.                */
CREATE OR REPLACE MASKING POLICY GOVERNANCE.MP_IDENTIFIER AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('PLATFORM_OWNER','DATA_ENGINEER','COMPLIANCE_MANAGER') THEN val
        WHEN CURRENT_ROLE() = 'COMPLIANCE_ANALYST' THEN LEFT(val, 4) || '****' || RIGHT(val, 2)  -- partial
        ELSE '***MASKED***'
    END;

-- Apply to the identifier columns
ALTER TABLE CORE.DIM_PLAYER  MODIFY COLUMN PLAYER_ID  SET MASKING POLICY GOVERNANCE.MP_IDENTIFIER;
ALTER TABLE CORE.DIM_ACCOUNT MODIFY COLUMN ACCOUNT_ID SET MASKING POLICY GOVERNANCE.MP_IDENTIFIER;
-- NOTE: BI / reporting roles read only the REPORTING views, not CORE, so masking here
-- protects direct CORE access without affecting dashboards.

/* ============================================================================
   3. Row-access policy — regional data segmentation (illustrative)
   ============================================================================
   Oversight roles see all regions; an analyst is scoped to their region. In a
   real deployment the allowed region(s) would come from a mapping table keyed to
   the user, not a hard-coded value.                                            */
CREATE OR REPLACE ROW ACCESS POLICY GOVERNANCE.RAP_REGION AS (region VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('PLATFORM_OWNER','DATA_ENGINEER','COMPLIANCE_MANAGER','READ_ONLY_AUDITOR')
    OR (CURRENT_ROLE() = 'COMPLIANCE_ANALYST' AND region = 'REGION-A');

-- Apply to the player dimension on REGION_CODE
ALTER TABLE CORE.DIM_PLAYER ADD ROW ACCESS POLICY GOVERNANCE.RAP_REGION ON (REGION_CODE);

/* ============================================================================
   4. Time Travel & retention (audit-oriented)
   ============================================================================
   DB-level Time Travel was set to 1 day in Phase 4 (cost-aware). For audit,
   extend retention on the RESTRICTED compliance facts so point-in-time review /
   recovery is possible over a longer window.                                   */
ALTER TABLE CORE.FACT_AML_ALERTS SET DATA_RETENTION_TIME_IN_DAYS = 14;
ALTER TABLE CORE.FACT_STR_CASES  SET DATA_RETENTION_TIME_IN_DAYS = 14;
-- Time Travel usage examples (read-only; no changes):
--   SELECT * FROM CORE.FACT_STR_CASES AT(OFFSET => -3600);           -- 1 hour ago
--   SELECT * FROM CORE.FACT_STR_CASES BEFORE(STATEMENT => '<query_id>');
--   UNDROP TABLE CORE.FACT_STR_CASES;                                -- recover a dropped table

/* ============================================================================
   5. Verify (run as ACCOUNTADMIN)
   ============================================================================ */
SELECT 'masking policies' AS OBJECT, COUNT(*) AS N FROM INFORMATION_SCHEMA.MASKING_POLICIES WHERE POLICY_SCHEMA = 'GOVERNANCE'
UNION ALL SELECT 'row access policies', COUNT(*) FROM INFORMATION_SCHEMA.ROW_ACCESS_POLICIES WHERE POLICY_SCHEMA = 'GOVERNANCE'
UNION ALL SELECT 'tags', COUNT(*) FROM INFORMATION_SCHEMA.TAGS WHERE TAG_SCHEMA = 'GOVERNANCE';
-- Confirm masking is live (run as COMPLIANCE_ANALYST to see partial masking):
--   SELECT PLAYER_ID FROM CORE.DIM_PLAYER LIMIT 5;
