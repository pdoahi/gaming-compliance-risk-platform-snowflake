# Pre-Flight Dry-Run Review

> A **static, read-only** end-to-end trace of the execution path before the first live Snowflake
> run — the layer-by-layer review a senior engineer does to catch cross-script bugs before
> burning trial time. This is **not** an execution; it is a code review. Live validation is
> still required (see [`validation_results.md`](validation_results.md)).

## Method

Traced column names, keys, data types, and dependencies across the scripts in run order:
generator → RAW DDL → staging DDL/transform → dimension loads → fact loads → AML generate →
AML scoring → STR generate → reporting views. Cross-checked every downstream reference against
the table that defines it.

## Result: 2 bugs found and fixed (both in the synthetic data generator)

Following the "document before fixing" rule, both are recorded here.

### Bug 1 — `FISCAL_YEAR_QUARTER` too long (hard failure)
- **Symptom:** `03_core_model/04_load_facts.sql` would abort loading `FACT_MARKET_PERFORMANCE`
  with a *"string too long"* error, leaving the market fact and all market views empty.
- **Cause:** the generator emitted `'FY2024-Q1'` (9 chars), but
  `FACT_MARKET_PERFORMANCE.FISCAL_YEAR_QUARTER` is `VARCHAR(6)`; `DIM_DATE`'s convention is the
  6-char `'FY24Q1'`.
- **Fix:** generator now emits `'FY' || LPAD(MOD(fy,100),2,'0') || 'Q' || fq` → `'FY25Q1'`,
  fitting the column and matching `DIM_DATE`.

### Bug 2 — R10 (counterparty concentration) fired 0 alerts (silent)
- **Symptom:** rule R10 would produce no alerts, contradicting the "all 11 typologies fire"
  design and the smoke-test expectation.
- **Cause:** the concentration cohort funnelled to an **external** payee (`A99999`). The fact
  loader resolves `COUNTERPARTY_ACCOUNT_KEY` by looking the id up in `DIM_ACCOUNT`, which only
  contains *originating* accounts — so external payees resolve to `NULL`, and R10 filters
  `WHERE COUNTERPARTY_ACCOUNT_KEY IS NOT NULL`.
- **Fix:** the cohort now funnels to an **internal** account (`A00007`, a plain account present
  in the population), so the counterparty key resolves and R10 fires (4 × 6,000 → PC=4,
  PS=24,000). Documented inline in the generator.

## Confirmed correct during the trace (no change needed)

- **Escalation → STR cases will populate:** seed base scores (R01/R02/R03/R08 = 70–80, R11 = 95)
  escalate on their own; the +10 multi-typology and +10 elevated-customer modifiers push R04–R10
  over the 70 threshold for the bad-actor cohorts.
- **Key resolution:** `DIM_PLAYER.WATCHLIST_FLAG` (from `BOOLOR_AGG(SANCTIONS_FLAG)`) drives R11;
  `KYC_RISK_LEVEL='High'` / `ACCOUNT_RISK_RATING='High'` drive R09 and modifier 2.
- **Governance consistency:** `RAP_REGION` allows `'REGION-A'`, which `DIM_PLAYER.REGION_CODE`
  actually produces (`'REGION-' || CHR(65 + MOD(HASH,4))`).
- **Grain firewall:** market views derive `FISCAL_YEAR` from `DIM_DATE`, and
  `FACT_MARKET_PERFORMANCE` joins only `DIM_DATE`.
- **Reporting views:** every column referenced by the DAX/measures docs exists on the views;
  KPI views collapse to one row via pre-aggregation + `CROSS JOIN` (no fan-out).
- **String widths / types:** `TRANSACTION_ID`, `CURRENCY`, `YEAR_MONTH`, `TRANSACTION_TYPE`,
  `PAYMENT_FORMAT` all fit their target columns; booleans emitted as `'true'/'false'` for the
  staging `TRY_TO_BOOLEAN` casts.

## Residual risk (why live execution still matters)

Static review cannot catch everything — runtime-only issues (a Snowflake version quirk, an
edge-case cast, an empty-set aggregate) can still surface. Treat the in-script validation
queries as the source of truth and record outcomes in
[`validation_results.md`](validation_results.md).
