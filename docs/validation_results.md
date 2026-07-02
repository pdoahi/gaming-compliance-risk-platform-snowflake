# Validation Results

> **Execution status: `Executed — setup verification passed (18/18)`.**
>
> The platform was built and run in a **Snowflake trial on 2026-07-02** by the repository owner.
> The numbers below are the **actual pasted output** of that run's setup-verification query
> ([`snowflake/07_data_quality/05_setup_verification.sql`](../snowflake/07_data_quality/05_setup_verification.sql)),
> not placeholders. Synthetic data only.

- **Execution date:** 2026-07-02
- **Environment:** Snowflake free trial (Snowsight)
- **Executed by:** repository owner
- **Warehouses used:** `WH_INGESTION`, `WH_TRANSFORM`, `WH_REPORTING`
- **Data path:** in-database synthetic generator (`01_ingestion/05_generate_synthetic_data.sql`)

---

## 1. Deployment execution log

| Step | Script(s) | Status | Notes |
|---|---|---|---|
| Setup | `00_setup/01–03` | PASS | 7 schemas, warehouses, roles created |
| Ingestion + data gen | `01_ingestion/01–03, 05` | PASS | RAW_TRANSACTIONS = 5,310 |
| Staging | `02_staging/01–02` | PASS | 0 invalid rows |
| Core model | `03_core_model/01–04` | PASS | dims + facts loaded |
| AML rules | `04_aml_rules/01–03` | PASS | 11 typologies seeded; alerts generated + scored |
| STR workflow | `05_str_workflow/01–02` | PASS | cases generated with SLA |
| Reporting views | `06_reporting/01–05` | PASS | 11 views compile & return |

## 2. Setup-verification results (18/18 PASS)

| # | Check | Actual | Expected | Status |
|---|---|---|---|---|
| 1 | Schemas present | 7 | 7 | PASS |
| 2 | RAW_TRANSACTIONS rows | 5,310 | ~5,300 | PASS |
| 3 | STAGING invalid rows | 0 | 0 | PASS |
| 4 | DIM_DATE rows | 2,922 | 2,922 | PASS |
| 5 | DIM_PLAYER rows | 400 | ~400 | PASS |
| 6 | DIM_ACCOUNT rows | 400 | ~400 | PASS |
| 7 | DIM_ALERT_TYPE rows | 11 | 11 | PASS |
| 8 | FACT_TRANSACTIONS rows | 5,310 | ~5,300 | PASS |
| 9 | FACT_MARKET_PERFORMANCE months | 36 | 36 | PASS |
| 10 | FACT_AML_ALERTS rows | 5,749 | > 0 | PASS |
| 11 | AML typologies firing (distinct) | 11 | 11 | PASS |
| 12 | Escalated alerts | > 0 | > 0 | PASS |
| 13 | FACT_STR_CASES rows | 3,051 | > 0 | PASS |
| 14 | Orphan alerts | 0 | 0 | PASS |
| 15 | VW_EXECUTIVE_OVERVIEW rows | 1 | 1 | PASS |
| 16 | VW_ALERT_TYPOLOGY_BREAKDOWN rows | 11 | 11 | PASS |
| 17 | VW_STR_WORKFLOW_SUMMARY rows | 1 | 1 | PASS |
| 18 | VW_MARKET_PERFORMANCE rows | 36 | 36 | PASS |

**Headline numbers (final, post-fixes):** RAW = 5,310 · FACT_TRANSACTIONS = 5,310 ·
FACT_AML_ALERTS = 5,749 (all **11** typologies) · FACT_STR_CASES = 3,051 · Market = 36 months ·
all reporting views live.

## 3. Issues found & fixed during execution & validation

| Issue | Layer | Root cause | Fix | Result |
|---|---|---|---|---|
| Rule **R10** (counterparty concentration) fired 0 alerts → only 10 typologies | AML generation | The run initially used a **pre-fix copy** of the generator whose concentration cohort funnelled to an **external** payee (`A99999`), which the fact loader resolves to a **NULL** `COUNTERPARTY_ACCOUNT_KEY`; R10 filters `IS NOT NULL`. | Concentration routes to an **internal** account `A00007` that exists in `DIM_ACCOUNT` (commit `f61a6ee`); re-ran generator → core → `04_aml_rules`. | **R10 generates 57 alerts**; all **11** typologies active → 18/18. |
| **71 duplicate `ALERT_ID`s** in `FACT_AML_ALERTS` (DQ check FAIL) | AML generation | Rule **R03** (rapid movement) was a **self-join**, emitting one row per matching prior deposit; a withdrawal matching several deposits produced duplicate `(txn × R03)` rows — and inflated the scoring step's multi-typology `COUNT(*) > 1` modifier. | Rewrote R03 as an **`EXISTS` semi-join** so each qualifying withdrawal yields exactly one alert (commit `b1c6b14`); re-ran `04_aml_rules/02,03` + `05_str_workflow`. | Duplicates → **0**; alerts 5,820 → **5,749**; cases unchanged (3,051) → **21/21**. |

> The R10 failure was predicted in [`pre_flight_dry_run_review.md`](pre_flight_dry_run_review.md)
> and confirmed live; the R03 duplication was caught by the reconciliation/DQ verification
> (`07_data_quality/06`) — exactly what that layer is for.

## 4. Reconciliation & data-quality verification (21/21 PASS)

The consolidated reconciliation/DQ grid
([`07_data_quality/06_reconciliation_verification.sql`](../snowflake/07_data_quality/06_reconciliation_verification.sql))
passed **21/21**:

- **R1–R8 reconciliation — all PASS.** Counts and values tie end-to-end: RAW→STAGING→CORE
  (5,310), market (36), transaction value (32,157,132.00 = 32,157,132.00), alerts CORE = view
  (5,749), cases CORE = view (3,051), GGR CORE = view (1,630,980,000), cases ≤ escalated txns
  with **0** from non-escalated, and the executive view ties to the facts.
- **DQ integrity — all PASS.** No duplicate transaction/alert/case IDs, no null keys, no orphans,
  SLA logic consistent, market months contiguous (max gap 1), no negative values, 11 reporting
  views present.

**Together: 18/18 setup verification + 21/21 reconciliation/DQ** = the platform is fully
validated on synthetic data.

## 5. Evidence

- **Textual evidence:** the 18/18 verification grid above (pasted from the live run).
- **Screenshots:** capture in progress — see
  [`screenshot_capture_guide.md`](screenshot_capture_guide.md); store under `docs/evidence/` and
  link from the README **Execution Evidence** section. No screenshots are fabricated.

## 6. Final verdict

**Fully validated: 18/18 setup verification + 21/21 reconciliation/DQ, all PASS.** The platform
runs end to end on synthetic data in a live Snowflake account; every layer reconciles and every
integrity check passes. Two defects surfaced during execution (R10 concentration, R03 duplicate
alerts), were fixed, and re-verified. Remaining polish: capture evidence screenshots.
