# Current-State Audit — Phases 1–9

> A checkpoint audit of everything built before the Phase 10 reporting layer: what exists,
> which Snowflake objects it produces, phase completeness, gaps, and whether the architecture
> and compliance workflow still hold. Synthetic data only.

## Business flow verified

The model preserves the required lineage end-to-end:

```text
Player / Account  →  Transaction  →  AML Alert  →  STR Case  →  Reporting View
  DIM_PLAYER/         FACT_          FACT_          FACT_         REPORTING.VW_*
  DIM_ACCOUNT         TRANSACTIONS   AML_ALERTS     STR_CASES
```

- `FACT_AML_ALERTS.TRANSACTION_KEY` → `FACT_TRANSACTIONS` (alert traces to its transaction).
- `FACT_STR_CASES.ALERT_KEY` → `FACT_AML_ALERTS` (case traces to its escalated alert).
- `PLAYER_KEY` / `ACCOUNT_KEY` carried on the facts (subject of activity).
- **Grain firewall:** `FACT_MARKET_PERFORMANCE` is monthly and joins **only** `DIM_DATE`; it
  is never joined to transaction/alert/case facts, so market/GGR is not blended with
  transaction-level AML metrics.

## Phase-by-phase status

| Phase | Deliverables | Files | Status |
|---|---|---|---|
| 1 Foundation | README, structure, `.gitignore`, disclaimer, docs index | repo root, `data/`, `docs/README` (via README) | Complete |
| 2 Architecture | layered architecture + diagram | `docs/solution_architecture.md`, `diagrams/architecture/*` | Complete |
| 3 Data model & ERD | dims/facts spec, logical+physical ERD, SCD2 roadmap | `docs/data_model.md`, `docs/erd.md`, `diagrams/data_model/*` | Complete |
| 4 Setup | warehouses, DB/schemas, roles/grants | `snowflake/00_setup/01–03` | Complete |
| 5 Ingestion | file formats, stages, RAW tables, COPY INTO | `snowflake/01_ingestion/01–04` | Complete |
| 6 Staging | typed tables + transformations + DQ flags | `snowflake/02_staging/01–02` | Complete |
| 7 Core model | 6 dims + 4 facts (create + load) | `snowflake/03_core_model/01–04` | Complete |
| 8 AML rules | 11 typologies, alert generation, scoring | `snowflake/04_aml_rules/01–03`, `docs/aml_rules_framework.md`, workflow diagram | Complete |
| 9 STR workflow | case generation + SLA logic | `snowflake/05_str_workflow/01–02`, `docs/str_workflow.md`, workflow diagram | Complete |
| 10 Reporting | 11 reporting views | `snowflake/06_reporting/01–05` | ◑ In progress (this checkpoint) |

## Snowflake objects expected (after running Phases 1–9 in an account)

- **Warehouses:** `WH_INGESTION`, `WH_TRANSFORM`, `WH_REPORTING`, `WH_DATA_SCIENCE`
- **Database / schemas:** `GAMING_COMPLIANCE_DB` · RAW, STAGING, CORE, ANALYTICS, REPORTING, GOVERNANCE, UTILITY
- **Roles:** PLATFORM_OWNER, DATA_ENGINEER, COMPLIANCE_ANALYST, COMPLIANCE_MANAGER, BI_REPORTING, READ_ONLY_AUDITOR
- **RAW:** `RAW_TRANSACTIONS`, `RAW_MARKET_PERFORMANCE`, `RAW_MARKET_BY_PRODUCT` (+ stage, file formats)
- **STAGING:** `STG_TRANSACTIONS`, `STG_MARKET_PERFORMANCE`, `STG_MARKET_BY_PRODUCT` (typed + DQ flags)
- **CORE dims:** `DIM_DATE`, `DIM_PLAYER`, `DIM_ACCOUNT`, `DIM_ALERT_TYPE`, `DIM_STATUS`, `DIM_ANALYST`
- **CORE facts:** `FACT_TRANSACTIONS`, `FACT_AML_ALERTS`, `FACT_STR_CASES`, `FACT_MARKET_PERFORMANCE`

## Architecture alignment

Still matches `docs/solution_architecture.md`: strict one-directional flow RAW → STAGING →
CORE → (ANALYTICS engine populating alert/case facts) → REPORTING, with governance/utility
cross-cutting. Cost-aware warehouses and least-privilege RBAC are defined in setup.

## Gaps / notes (non-blocking)

- **Synthetic data + generator** are not yet in the repo — the ingestion COPY steps document
  the expected file layouts; the generator + sample CSVs are to be added before the
  end-to-end run (needed to actually load and validate).
- **ANALYTICS schema** currently holds no objects: the AML/STR engine writes to CORE facts
  (documented assumption). This is a naming choice, not a defect.
- **Product/category market** data lands in STAGING but has no CORE fact; monthly + fiscal-year
  market reporting is covered without it.
- **Runtime validation** (row counts, orphans) requires a live Snowflake run — see
  `pre_phase10_validation_checklist.md`.

## Conclusion

Phases 1–9 are structurally complete and consistent; the data model supports the compliance
workflow and keeps market/GGR at a separate grain. The platform is ready for the Phase 10
reporting layer, pending the runtime validation checks.
