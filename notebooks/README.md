# notebooks/

Analysis notebooks that connect to the platform's Snowflake **reporting layer** and chart the
results — the visual companion to the SQL platform.

| Notebook | What it shows |
|---|---|
| [`01_reporting_analysis.ipynb`](01_reporting_analysis.ipynb) | Executive KPIs, AML alerts by typology, monthly trends, market/GGR, STR SLA, and detection performance (recall/precision/F1 vs the synthetic ground-truth label) — charted from the `REPORTING.VW_*` views |
| [`02_data_profiling.ipynb`](02_data_profiling.ipynb) | Profiles the synthetic transaction data — amount distribution, payment-method mix, laundering rate by method, monthly volume, and data quality (from `STAGING`) |
| [`03_ml_baseline.ipynb`](03_ml_baseline.ipynb) | Logistic-regression baseline predicting the `IS_LAUNDERING` label from features served from Snowflake — ROC-AUC, classification report, ROC curve, and coefficients (hybrid rules-plus-ML) |

## Running

1. Build the platform in Snowflake (see [`../docs/deployment_guide.md`](../docs/deployment_guide.md)).
2. `pip install -r ../requirements.txt` (includes scikit-learn for notebook 03).
3. Provide your Snowflake connection **without hard-coding secrets** — a `connections.toml`
   entry named `gaming_compliance`, or the `SNOWFLAKE_*` environment variables the notebooks
   read.
4. **Run all cells, then commit the notebook with its outputs** so the charts render on GitHub.

## Notes

- All notebooks run on **synthetic data only** and require no real credentials.
- The system of record is the SQL under [`../snowflake/`](../snowflake); notebooks are for
  visual analysis and explanation, not production logic.
- The notebook is committed **without outputs** until it is run against a live account — no
  results are fabricated.
