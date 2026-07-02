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
| 10 | FACT_AML_ALERTS rows | 5,820 | > 0 | PASS |
| 11 | AML typologies firing (distinct) | 11 | 11 | PASS |
| 12 | Escalated alerts | > 0 | > 0 | PASS |
| 13 | FACT_STR_CASES rows | 3,051 | > 0 | PASS |
| 14 | Orphan alerts | 0 | 0 | PASS |
| 15 | VW_EXECUTIVE_OVERVIEW rows | 1 | 1 | PASS |
| 16 | VW_ALERT_TYPOLOGY_BREAKDOWN rows | 11 | 11 | PASS |
| 17 | VW_STR_WORKFLOW_SUMMARY rows | 1 | 1 | PASS |
| 18 | VW_MARKET_PERFORMANCE rows | 36 | 36 | PASS |

**Headline numbers:** RAW = 5,310 · FACT_TRANSACTIONS = 5,310 · FACT_AML_ALERTS = 5,820
(all **11** typologies) · FACT_STR_CASES = 3,051 · Market = 36 months · all reporting views live.

## 3. Issue found & fixed during execution

| Issue | Layer | Root cause | Fix | Result |
|---|---|---|---|---|
| Rule **R10** (counterparty concentration) fired 0 alerts → only 10 typologies | AML generation | The run initially used a **pre-fix copy** of the generator whose concentration cohort funnelled to an **external** payee (`A99999`), which the fact loader resolves to a **NULL** `COUNTERPARTY_ACCOUNT_KEY`; R10 filters `IS NOT NULL`. | Applied the committed fix (concentration routes to an **internal** account `A00007` that exists in `DIM_ACCOUNT`; commit `f61a6ee`), re-ran `01_ingestion/05` → core loads → `04_aml_rules`. | **R10 now generates 57 alerts**; all **11** typologies active → 18/18. |

> This exact failure was predicted in [`pre_flight_dry_run_review.md`](pre_flight_dry_run_review.md);
> the live run confirmed it and the committed fix resolved it.

## 4. What was verified vs. still optional

- **Verified (this run):** end-to-end build, all four facts populated, all 11 AML typologies
  firing, STR cases generated, all reporting views returning — via the 18-check setup
  verification.
- **Optional next validation layer (not yet run):** the deeper reconciliation / DQ scripts in
  `snowflake/07_data_quality/00–04` (R1–R8 reconciliation, P1–P6 reporting checks, per-phase
  gates). Recommended for completeness; record their `STATUS` output here when run.

## 5. Evidence

- **Textual evidence:** the 18/18 verification grid above (pasted from the live run).
- **Screenshots:** capture in progress — see
  [`screenshot_capture_guide.md`](screenshot_capture_guide.md); store under `docs/evidence/` and
  link from the README **Execution Evidence** section. No screenshots are fabricated.

## 6. Final verdict

**Executed and health-checked: 18/18 PASS.** The platform runs end to end on synthetic data in a
live Snowflake account, with all AML typologies, the STR workflow, and the reporting layer
producing data. Remaining polish: evidence screenshots and (optionally) the deeper reconciliation
scripts.
