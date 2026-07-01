# 09_snowpark — Snowpark Python (OPTIONAL)

> ⚠️ **Optional, educational example.** Shows how **in-database Python (Snowpark)** can do AML
> feature engineering + risk scoring without moving data out of Snowflake. Synthetic data only.
> **No credentials or secrets** are stored in this repo.

## What's here

| File | Purpose |
|---|---|
| `aml_risk_scoring_example.py` | Aggregates `FACT_TRANSACTIONS` to per-player features and computes an explainable heuristic risk score → writes `ANALYTICS.PLAYER_RISK_FEATURES` |

The heuristic score (transaction size + high-risk-method ratio + structuring signal) is a
**placeholder for a trained model** — the point is the Snowpark DataFrame pattern, not the model.

## How to run

**Option A — inside Snowflake (recommended, zero local setup):**
Open a **Snowpark Python worksheet** (or deploy as a stored procedure). The runtime provides a
`session` object — just call `main(session)`. Nothing to install, no credentials to manage.

**Option B — locally:**
1. `pip install snowflake-snowpark-python`
2. Configure a **named connection** in `~/.snowflake/connections.toml` (Snowflake's standard
   config file) — for example a connection named `gaming_compliance`. **Never hardcode
   credentials in code or commit them.** Prefer key-pair auth or SSO/externalbrowser.
3. `export SNOWFLAKE_CONNECTION=gaming_compliance` (defaults to that name)
4. `python aml_risk_scoring_example.py`

The script reads the connection by **name** via `Session.builder.config("connection_name", ...)`
and overrides role/warehouse from env vars — so no secret ever appears in the source.

## 💲 Cost note

Runs on `WH_DATA_SCIENCE` (created XSMALL + `AUTO_SUSPEND`, and **initially suspended**). It
auto-resumes for the run and suspends after — a single scoring pass is a tiny amount of compute.

## Portfolio note

This is a **concept demo** on synthetic data. A real deployment would train and register a
model (Snowpark ML / model registry), schedule scoring, monitor drift, and feed scores back into
the AML/alerting layer — out of scope for this portfolio project.
