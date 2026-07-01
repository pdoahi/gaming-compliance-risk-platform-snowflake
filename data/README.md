# data/

> ⚠️ **Synthetic data only.** Everything in this folder is **fabricated and illustrative**.
> It represents no real individuals, players, customers, transactions, accounts, or market
> figures, and contains **no personal data, credentials, or secrets**. Do not place real,
> production, or personally identifiable data here.

## Purpose

Holds the synthetic datasets that feed the Snowflake pipeline. Data is generated for
demonstration and is small enough to commit for reproducibility.

## Subfolders

| Folder | Contents |
|---|---|
| `raw/` | Source-shaped synthetic files as they would land from an operator's systems (e.g. transaction extracts, monthly market figures). Loaded into the Snowflake `RAW` schema via stages + `COPY INTO`. |
| `processed/` | Cleaned / analytics-ready synthetic outputs where useful. |
| `reference/` | Small reference / seed data (e.g. alert-type definitions, status codes, lookup lists). |

## Provenance

Synthetic data (and the generator that produces it) is added in the data-related phases.
The schema is designed so that a **real, properly-governed** dataset could be substituted in
a genuine deployment — but only synthetic data is ever committed here.

## Rules

- Never commit real customer/player data, PII, credentials, or secrets.
- Keep committed files small; large generated artifacts are git-ignored (see `.gitignore`).
- Every dataset must be clearly labelled as synthetic in its documentation.
