# Interview Talking Points

> A concise script for talking about this project in interviews. Honest throughout: it's a
> **portfolio-grade, synthetic** Snowflake implementation, and the next real step is executing
> it live. Execution proof is what turns a *documented implementation* into an *interview-ready
> technical portfolio project*.

---

## 30-second summary

> "I built a **Gaming Compliance & Risk Intelligence Platform** on Snowflake — a layered cloud
> data warehouse that simulates how a regulated online-gaming operator would run AML transaction
> monitoring, generate suspicious-transaction (STR) cases with SLAs, track player/account risk,
> and report market/GGR performance. It goes RAW → STAGING → CORE → REPORTING → BI, with 11
> explainable AML rules, a dimensional model, governance demo patterns, a data-quality
> framework, and a Power BI-ready semantic layer. All data is synthetic. It's fully authored and
> documented across 15 phases; my next step is executing it end-to-end in a Snowflake trial and
> capturing validation evidence."

## Technical architecture summary

```
RAW → STAGING → CORE / ANALYTICS → REPORTING → BI
```
- **RAW** — source-faithful landing (VARCHAR + load metadata), `TRANSIENT` to save storage.
- **STAGING** — typed/cleaned (`TRY_TO_*`), category normalization, data-quality flags.
- **CORE / ANALYTICS** — dimensional model (6 conformed dims + 4 facts), the AML rule engine,
  and the STR workflow.
- **REPORTING** — 11 business-named `VW_*` views that act as the semantic layer for BI.
- **BI** — Power BI connects (Import) under a least-privilege `BI_REPORTING` role.

## Business problem

Regulated operators must run AML programs and file **STRs** with a financial-intelligence
regulator (in Canada, FINTRAC) when they suspect money laundering. Manual review doesn't scale.
The platform provides the analytics layer: monitor transactions for suspicious patterns, score
and prioritize alerts, manage investigations to SLA deadlines, and give leadership visibility
into both compliance health and market performance.

## Snowflake skills demonstrated

- **Platform:** warehouse / database / schema design; cost-aware, workload-isolated warehouses
  (`AUTO_SUSPEND`); least-privilege RBAC with `FUTURE` grants.
- **Ingestion:** file formats, internal stages, `COPY INTO` with load metadata, plus an in-DB
  synthetic data generator.
- **Transformation:** staging casts/cleansing and DQ flags.
- **Modeling:** dimensional fact-constellation, surrogate keys, deliberate grain management.
- **Analytics SQL:** 11 AML typologies, STR/SLA logic, CTEs, window functions (`LAG`,
  `PERCENTILE_CONT`, `QUALIFY`), `CASE` scoring.
- **Serving:** reporting views as a semantic layer; reconciliation & validation checks.
- **Governance (demo):** masking + row-access policies, classification tags, Time Travel.
- **BI:** Power BI connection guide, model, DAX measures, dashboard spec.

## Key technical decisions

- **Layered architecture** — separates landing, cleansing, modeling, and serving so each layer
  has one job; failures are isolated and the pipeline is rebuildable.
- **Dimensional modeling** — conformed dimensions + fact tables make the data analytics-friendly
  and BI-ready without bespoke joins per report.
- **Market/GGR kept separate from transaction-level AML** — a deliberate **grain firewall**:
  market data is monthly and market-wide, so blending it with per-transaction alerts would
  double-count. They meet only through `DIM_DATE` and pre-aggregated reporting views.
- **Reporting views as the semantic layer** — one business-named contract for BI; dashboards
  never touch raw/core, which also supports least-privilege access.
- **Validation before presentation** — I don't claim it works until the validation scripts run
  green in a live account; that honesty is part of the engineering.

## Honest limitations

- **Synthetic data** — no real players/customers; alert volumes are demonstration artifacts.
- **Governance is a demo pattern** — role-only logic and a hard-coded region, not production
  access control.
- **Manual Snowflake execution still required** — authored and statically reviewed, not yet run
  live from my build environment, so nothing is claimed as passed.
- **No regulatory-system integration**, no production deployment, rule-based (not ML) detection,
  and SCD Type 1 (Type 2 is on the roadmap).

## Strong interview answer — "Tell me about your Snowflake project"

> "I designed and built a compliance and risk analytics platform on Snowflake for a regulated
> online-gaming context, entirely on synthetic data. It's a layered warehouse — RAW to STAGING
> to a dimensional CORE, then a REPORTING layer of business-named views for BI. On top of the
> model I wrote an AML engine of 11 explainable rule typologies — structuring, rapid movement,
> velocity, high-risk methods, sanctions hits — each a small, auditable SQL rule with an additive
> risk score. Escalated alerts flow into an STR case workflow with priority-based SLAs. I was
> deliberate about grain: market/GGR data is kept on its own monthly grain so it can't
> contaminate transaction-level AML metrics. I added governance demo patterns — masking,
> row-access, classification tags, Time Travel — and a data-quality/reconciliation framework so
> the numbers can be trusted. I built it in 15 validated phases with documentation at each step.
> I'm careful to say it's authored and reviewed but not yet executed live — my immediate next
> step is running it end-to-end in a Snowflake trial, validating it, and capturing evidence."

## Rapid answers

**What problem does this project solve?** It gives a regulated operator the analytics layer for
AML monitoring and STR reporting — detecting suspicious activity, prioritizing it by risk, and
managing investigations to regulatory deadlines — plus executive visibility.

**How did you model the data?** A dimensional fact-constellation: 6 conformed dimensions
(date, player, account, alert type, status, analyst) and 4 facts (transactions, AML alerts, STR
cases, market performance), with surrogate keys and informational FKs.

**How did you avoid metric duplication?** A grain firewall — market data joins only `DIM_DATE`,
never transaction/alert/case facts — and reporting views that pre-aggregate to each key before
any cross-domain join, so nothing fans out.

**How did you validate the platform?** A data-quality suite (duplicates, null keys, orphans,
SLA consistency), reconciliation across every layer (RAW→…→REPORTING, counts and values), and
per-phase readiness gates — each returning `PASS`/`FAIL`/`REVIEW`. They're authored; running
them live is the pending step.

**What would you improve next?** Execute and validate live; then SCD Type 2 history, a real
KYC/CRM source, tuned/ML detection, dynamic entitlement mapping for governance, and CI/CD.

**What did you learn about Snowflake?** Separation of storage and compute (right-sizing
warehouses, auto-suspend for cost), the role hierarchy and least privilege, `TRANSIENT` vs
Fail-safe trade-offs, load lineage via stage metadata, and native governance (masking/row-access
policies, tags, Time Travel).

**What is your next real-world step for this project?**
> "The next real-world step is to execute the full project in Snowflake, run validation checks,
> capture evidence screenshots, update the validation results, and then connect Power BI to the
> reporting views."
