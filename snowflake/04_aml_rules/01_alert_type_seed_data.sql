/* ============================================================================
   Phase 8 — AML 01: Alert-Type Seed Data
   Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

   Seeds CORE.DIM_ALERT_TYPE with the 11 AML rule typologies. BASE_RISK_SCORE and
   DEFAULT_SEVERITY are the explainable starting points; the scoring step (03)
   applies modifiers. REGULATORY_REFERENCE values are illustrative (FINTRAC/PCMLTFA).

   Run after the core model (Phase 7). SYNTHETIC data.
   ============================================================================ */

USE ROLE DATA_ENGINEER;
USE DATABASE GAMING_COMPLIANCE_DB;
USE SCHEMA CORE;

INSERT OVERWRITE INTO CORE.DIM_ALERT_TYPE
    (ALERT_TYPE_KEY, RULE_CODE, RULE_NAME, TYPOLOGY, DESCRIPTION,
     BASE_RISK_SCORE, DEFAULT_SEVERITY, REGULATORY_REFERENCE, IS_ACTIVE)
VALUES
    (1,  'R01', 'Large Transaction',          'Large transactions',
         'Single transaction at or above the large-transaction threshold (>= 10,000).',
         70, 'High',     'FINTRAC LCTR (CAD 10,000)',            TRUE),
    (2,  'R02', 'Structuring',                'Structuring / smurfing',
         'Three or more transactions just under the reporting threshold (9,000-9,999) per account.',
         80, 'High',     'PCMLTFA structuring',                  TRUE),
    (3,  'R03', 'Rapid Movement of Funds',    'Rapid movement of funds',
         'Deposit followed by a near-equal (>=90%) withdrawal on the same account within 6 hours.',
         75, 'High',     'FATF layering typology',               TRUE),
    (4,  'R04', 'High Transaction Velocity',  'High-velocity activity',
         'Eight or more transactions on one account within a single day.',
         60, 'Medium',   'Operator monitoring standard',         TRUE),
    (5,  'R05', 'Repeated Sub-Threshold',     'Repeated suspicious activity',
         'Five or more sub-threshold (<10,000) transactions on one account within a day.',
         60, 'Medium',   'PCMLTFA structuring (repeated)',       TRUE),
    (6,  'R06', 'High-Risk Payment Method',   'High-risk payment method',
         'Transaction via a high-risk method (Crypto / Prepaid Card) at or above 5,000.',
         55, 'Medium',   'FINTRAC virtual-currency guidance',    TRUE),
    (7,  'R07', 'Unusual Activity Spike',     'Unusual activity spike',
         'Daily account total at least 5x the account median daily total (and >= 5,000).',
         65, 'Medium',   'Behavioural anomaly monitoring',       TRUE),
    (8,  'R08', 'Dormant Account Reactivation','Dormant account reactivation',
         'Account inactive 30+ days then a transaction of 5,000 or more.',
         70, 'High',     'FATF dormant-reactivation typology',   TRUE),
    (9,  'R09', 'High-Risk Player / Account', 'High-risk players/accounts',
         'Transaction of 3,000+ by a High KYC-risk player or a High-risk account.',
         55, 'Medium',   'Risk-based approach (CDD)',            TRUE),
    (10, 'R10', 'Counterparty Concentration', 'Counterparty concentration',
         'Four or more transactions totalling 20,000+ to the same counterparty.',
         65, 'Medium',   'FATF concentration typology',          TRUE),
    (11, 'R11', 'Sanctions / Watchlist Match','Sanctions / watchlist indicators',
         'Any transaction by a watchlisted/sanctioned player. Mandatory control.',
         95, 'Critical', 'Sanctions screening (mandatory)',      TRUE);

SELECT RULE_CODE, RULE_NAME, TYPOLOGY, BASE_RISK_SCORE, DEFAULT_SEVERITY
FROM CORE.DIM_ALERT_TYPE ORDER BY ALERT_TYPE_KEY;
