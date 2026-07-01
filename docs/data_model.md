# Data Model — Snowflake Edition

> **Phase 3 deliverable.** The dimensional model for the platform: every dimension and fact
> (grain, keys, measures, additivity, SCD strategy), the conformed relationships, and the
> SCD Type 2 roadmap. Physical `CREATE TABLE` DDL is implemented in Phase 7. All data is
> **synthetic**.

---

## 1. Modeling approach

- **Dimensional (Kimball-style) fact-constellation / galaxy schema** — multiple fact tables
  sharing **conformed dimensions**.
- **Surrogate keys** (`*_KEY`, Snowflake `NUMBER IDENTITY`) on every dimension and fact;
  **business/natural keys** (`*_ID`) retained as attributes for traceability.
- **Grain declared first** for every fact; measures chosen to match the grain.
- **Audit columns** (`CREATED_AT`, `UPDATED_AT`, `SOURCE_SYSTEM`, `LOAD_BATCH_ID`) where useful.
- **Grain discipline:** transaction-level AML data and monthly market/GGR data are **kept
  separate**; they conform only through `DIM_DATE`.

## 2. Data Model Overview

![Logical ERD](../diagrams/data_model/logical_erd.png)

*Logical ERD. Full sources and the physical (column-level) ERD are in
[`erd.md`](erd.md) and [`../diagrams/data_model/`](../diagrams/data_model).*

**Business flow the model supports:**

```text
Player / Account → Transaction → AML Alert → Investigation Case → STR Outcome
```

`FACT_MARKET_PERFORMANCE` sits **beside** this flow at a monthly grain and connects only to
`DIM_DATE`.

---

## 3. Dimensions

### DIM_DATE  — *SCD Type 1 (static)*
- **Purpose:** conformed calendar; the single date dimension every fact shares (role-played
  as transaction date, alert date, case open/close date, market month).
- **Grain:** one row per calendar day.
- **Key:** `DATE_KEY` (PK, `NUMBER(8)` `YYYYMMDD`); `FULL_DATE` (natural).
- **Attributes:** `DAY, MONTH, MONTH_NAME, QUARTER, YEAR, YEAR_MONTH, DAY_OF_WEEK, DAY_NAME,
  IS_WEEKEND, FISCAL_YEAR, FISCAL_QUARTER, MONTH_START_DATE`.

### DIM_PLAYER  — *SCD Type 1 now · Type 2 candidate*
- **Purpose:** the monitored customer.
- **Grain:** one row per player (current state).
- **Keys:** `PLAYER_KEY` (PK surrogate); `PLAYER_ID` (business key).
- **Attributes:** `REGISTRATION_DATE, REGION_CODE, KYC_STATUS*, KYC_RISK_LEVEL*, PEP_FLAG,
  WATCHLIST_FLAG, SELF_EXCLUSION_FLAG, PLAYER_STATUS`.
- **SCD:** Type 1. `*` `KYC_STATUS` and `KYC_RISK_LEVEL` are **Type 2 candidates** (see §6).

### DIM_ACCOUNT  — *SCD Type 1 now · Type 2 candidate*
- **Purpose:** a wallet/account owned by a player (the monitored party in a transaction).
- **Grain:** one row per account (current state).
- **Keys:** `ACCOUNT_KEY` (PK); `ACCOUNT_ID` (business key).
- **FK:** `PLAYER_KEY` → `DIM_PLAYER` (a player owns 1..* accounts).
- **Attributes:** `ACCOUNT_TYPE, CURRENCY, OPEN_DATE, ACCOUNT_STATUS*, ACCOUNT_RISK_RATING*,
  PRIMARY_FUNDING_METHOD`.
- **SCD:** Type 1. `*` `ACCOUNT_STATUS` and `ACCOUNT_RISK_RATING` are **Type 2 candidates**.

### DIM_ALERT_TYPE  — *SCD Type 1 (reference)*
- **Purpose:** catalog of AML typologies/rules.
- **Grain:** one row per rule/typology.
- **Keys:** `ALERT_TYPE_KEY` (PK); `RULE_CODE` (e.g. `R01`).
- **Attributes:** `RULE_NAME, TYPOLOGY, DESCRIPTION, BASE_RISK_SCORE, DEFAULT_SEVERITY,
  REGULATORY_REFERENCE, IS_ACTIVE`.

### DIM_STATUS  — *SCD Type 1 (reference)*
- **Purpose:** workflow status values for alerts and cases.
- **Grain:** one row per status.
- **Keys:** `STATUS_KEY` (PK); `STATUS_CODE`.
- **Attributes:** `STATUS_NAME, STATUS_CATEGORY (Open/Closed), WORKFLOW_ORDER, IS_TERMINAL,
  APPLIES_TO (ALERT/CASE/BOTH)`.

### DIM_ANALYST  — *SCD Type 1*
- **Purpose:** compliance analysts who own STR cases (all synthetic).
- **Grain:** one row per analyst.
- **Keys:** `ANALYST_KEY` (PK); `ANALYST_ID`.
- **Attributes:** `ANALYST_NAME, TEAM, SENIORITY, ACTIVE_FLAG`.

---

## 4. Fact tables

### FACT_TRANSACTIONS
- **Business process:** player deposits/withdrawals monitored for AML.
- **Grain:** **one row per transaction.**
- **PK:** `TRANSACTION_KEY` (surrogate); `TRANSACTION_ID` (degenerate business key).
- **FKs:** `DATE_KEY`→DIM_DATE · `PLAYER_KEY`→DIM_PLAYER · `ACCOUNT_KEY`→DIM_ACCOUNT (originating)
  · `COUNTERPARTY_ACCOUNT_KEY`→DIM_ACCOUNT (receiving, role-playing, nullable).
- **Degenerate dims:** `TRANSACTION_TYPE, PAYMENT_FORMAT, CURRENCY, IS_HIGH_RISK_METHOD`.

| Measure | Type | Additivity |
|---|---|---|
| `AMOUNT`, `AMOUNT_CAD` | currency | **Additive** across all dimensions |
| `TRANSACTION_COUNT` (=1) | count | **Additive** |

### FACT_AML_ALERTS
- **Business process:** an AML rule firing on a transaction.
- **Grain:** **one row per (transaction × rule) match** — i.e. one alert. A transaction that
  trips two rules produces two alerts.
- **PK:** `ALERT_KEY`; `ALERT_ID` (degenerate).
- **FKs:** `TRANSACTION_KEY`→FACT_TRANSACTIONS (lineage) · `ALERT_TYPE_KEY`→DIM_ALERT_TYPE ·
  `PLAYER_KEY`→DIM_PLAYER · `ACCOUNT_KEY`→DIM_ACCOUNT · `DATE_KEY`→DIM_DATE (alert date) ·
  `STATUS_KEY`→DIM_STATUS.
- **Degenerate/derived:** `SEVERITY`, `ALERT_DESCRIPTION`.

| Measure | Type | Additivity |
|---|---|---|
| `ALERT_COUNT` (=1) | count | **Additive** |
| `IS_ESCALATED` (0/1) | flag | **Additive** (sum = escalated count) |
| `RISK_SCORE` | score | **Non-additive** — average/max, never sum |

### FACT_STR_CASES
- **Business process:** investigation of an escalated alert through to an STR outcome.
- **Grain:** **one row per investigation case.** Only **escalated / high-risk** alerts become cases.
- **PK:** `CASE_KEY`; `CASE_ID` (degenerate).
- **FKs:** `ALERT_KEY`→FACT_AML_ALERTS (triggering alert) · `PLAYER_KEY`→DIM_PLAYER ·
  `ANALYST_KEY`→DIM_ANALYST · `STATUS_KEY`→DIM_STATUS · `OPEN_DATE_KEY`→DIM_DATE ·
  `CLOSE_DATE_KEY`→DIM_DATE (role-playing, nullable).
- **Degenerate:** `CASE_PRIORITY, CLOSURE_REASON`.

| Measure | Type | Additivity |
|---|---|---|
| `CASE_COUNT` (=1) | count | **Additive** |
| `SLA_BREACHED` (0/1), `STR_SUBMITTED_FLAG` (0/1) | flag | **Additive** |
| `INVESTIGATION_DAYS` | duration | **Semi-additive** (sum as effort; usually averaged) |
| `SLA_DAYS` | target | **Non-additive** (a per-priority attribute) |

### FACT_MARKET_PERFORMANCE
- **Business process:** monthly online-gaming market / GGR reporting.
- **Grain:** **one row per reporting month.** ⚠️ Different grain from the AML facts.
- **PK:** `MARKET_PERF_KEY`.
- **FK:** `DATE_KEY`→DIM_DATE (month start) **only**. **Never** joined to transaction, alert,
  or case facts.

| Measure | Type | Additivity |
|---|---|---|
| `TOTAL_WAGERS`, `TOTAL_GGR` | currency | **Additive** over time |
| `ACTIVE_ACCOUNTS` | snapshot count | **Semi-additive** (not additive across months) |
| `GGR_PER_ACTIVE` (ARPPA), `HOLD_PCT`, `MOM_GGR_GROWTH_PCT` | ratio | **Non-additive** |

---

## 5. Conformance & grain separation

- **Conformed dimensions:** `DIM_DATE`, `DIM_PLAYER`, `DIM_ACCOUNT`, `DIM_STATUS` are shared
  across facts, enabling consistent cross-fact filtering (e.g. by month, by player).
- **Role-playing:** `DIM_DATE` plays transaction/alert/open/close/market-month roles;
  `DIM_ACCOUNT` plays originating + counterparty roles in `FACT_TRANSACTIONS`. In BI these are
  modeled with multiple relationships / `USERELATIONSHIP`.
- **Grain firewall:** `FACT_MARKET_PERFORMANCE` is **monthly** and **market-wide**; it shares
  only `DIM_DATE`. Reporting views never join it to transaction-grain facts, so wagers/GGR are
  never blended with per-transaction AML metrics (which would double-count).

## 6. Future Enhancement: SCD Type 2 Risk and KYC History

The first implementation uses **current-state (SCD Type 1)** dimensions for simplicity. For a
production-grade compliance platform, the following attributes should become **SCD Type 2**
(history-preserving):

- **Player risk rating** (`DIM_PLAYER.KYC_RISK_LEVEL`)
- **KYC status** (`DIM_PLAYER.KYC_STATUS`)
- **Account status** (`DIM_ACCOUNT.ACCOUNT_STATUS`)
- **Account risk rating** (`DIM_ACCOUNT.ACCOUNT_RISK_RATING`)

**Why SCD Type 2 matters for compliance analytics.** Compliance is inherently *point-in-time*:
the question is rarely "what is this player's risk rating **now**?" but "what was it **at the
time of the flagged transaction**?" Type 1 overwrites history, so once a rating changes you can
no longer answer that — which undermines investigation, audit, and rule back-testing.

**Example SCD Type 2 columns** (added to the historized dimensions):

| Column | Purpose |
|---|---|
| `EFFECTIVE_START_DATE` | when this version of the row became true |
| `EFFECTIVE_END_DATE` | when it stopped being true (`NULL`/high-date for the current row) |
| `IS_CURRENT` | boolean flag for the active version (fast "current" filtering) |
| `VERSION_NUMBER` | incrementing version per business key |
| `CHANGE_REASON` | why the attribute changed (e.g. `KYC_REVIEW`, `RISK_RECLASSIFICATION`) |

**How it improves auditability.** History becomes immutable and queryable: a regulator or
auditor can reconstruct exactly what the platform "knew" about a player/account on any date,
and see when and why risk or KYC state changed — with a full version trail.

**How it supports historical risk reconstruction.** Facts join to the dimension version that
was effective on the fact's date (`fact.DATE BETWEEN dim.EFFECTIVE_START_DATE AND
dim.EFFECTIVE_END_DATE`). That lets you: (1) attribute each alert to the player's *then-current*
risk rating, (2) back-test whether a rule change would have fired historically, and (3) analyze
how risk migrated over time — none of which is possible with Type 1.

Snowflake supports this cleanly with `MERGE` (close the old version, insert the new) and, for
validation/recovery, **Time Travel**. Full implementation is tracked as a Phase-15 future
enhancement.

## 7. What Phase 4 does next

Phase 4 creates the Snowflake **setup scripts** — warehouses, database & schemas, and roles &
grants — the platform this model will be built into.
