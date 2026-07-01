"""
Snowpark AML risk-scoring example  (OPTIONAL, Phase 13)
Gaming Compliance & Risk Intelligence Platform (Snowflake edition)

*** OPTIONAL, educational example. *** Shows how in-database Python (Snowpark) can do feature
engineering + risk scoring on the transaction fact WITHOUT moving data out of Snowflake. It
engineers per-player features and computes a simple, explainable heuristic risk score, then
writes ANALYTICS.PLAYER_RISK_FEATURES.

SYNTHETIC data only. NO CREDENTIALS OR SECRETS are stored here — a connection is supplied by
the runtime (Snowflake) or by your own local Snowflake config (see 09_snowpark/README.md).

The heuristic score is a placeholder for a trained model; the point is the Snowpark pattern,
not the model. Requires: snowflake-snowpark-python.
"""

from snowflake.snowpark import Session, functions as F

DB = "GAMING_COMPLIANCE_DB"


def engineer_player_features(session: Session):
    """Aggregate FACT_TRANSACTIONS to per-player AML features."""
    tx = session.table(f"{DB}.CORE.FACT_TRANSACTIONS")
    feats = tx.group_by("PLAYER_KEY").agg(
        F.count("*").alias("TXN_COUNT"),
        F.round(F.sum("AMOUNT"), 2).alias("TOTAL_VALUE"),
        F.round(F.avg("AMOUNT"), 2).alias("AVG_AMOUNT"),
        F.max("AMOUNT").alias("MAX_AMOUNT"),
        F.sum(F.iff(F.col("IS_HIGH_RISK_METHOD"), 1, 0)).alias("HIGH_RISK_TXNS"),
        F.sum(F.iff((F.col("AMOUNT") >= 9000) & (F.col("AMOUNT") < 10000), 1, 0)).alias("NEAR_THRESHOLD_TXNS"),
    )
    return feats.with_column(
        "HIGH_RISK_RATIO",
        F.iff(F.col("TXN_COUNT") > 0, F.round(F.col("HIGH_RISK_TXNS") / F.col("TXN_COUNT"), 3), F.lit(0)),
    )


def score_risk(feats):
    """Explainable 0-100 heuristic risk score + band (placeholder for a trained model)."""
    score = (
        F.least(F.lit(40), F.col("MAX_AMOUNT") / 1000)          # transaction size signal
        + F.col("HIGH_RISK_RATIO") * 30                          # high-risk-method signal
        + F.least(F.lit(30), F.col("NEAR_THRESHOLD_TXNS") * 10)  # structuring signal
    )
    feats = feats.with_column("RISK_SCORE", F.round(F.least(F.lit(100), score), 1))
    return feats.with_column(
        "RISK_BAND",
        F.when(F.col("RISK_SCORE") >= 75, F.lit("High"))
         .when(F.col("RISK_SCORE") >= 45, F.lit("Medium"))
         .otherwise(F.lit("Low")),
    )


def main(session: Session):
    feats = score_risk(engineer_player_features(session))
    feats.write.mode("overwrite").save_as_table(f"{DB}.ANALYTICS.PLAYER_RISK_FEATURES")
    print(f"Wrote {DB}.ANALYTICS.PLAYER_RISK_FEATURES ({feats.count()} players).")
    feats.select("PLAYER_KEY", "TXN_COUNT", "MAX_AMOUNT", "RISK_SCORE", "RISK_BAND") \
         .order_by(F.col("RISK_SCORE").desc()).show(5)


# ---------------------------------------------------------------------------
# Run option A — inside Snowflake (Snowpark Python worksheet / stored proc):
#   a `session` is provided by the runtime; simply call:  main(session)
#
# Run option B — locally: build a Session from a NAMED connection in your own
#   ~/.snowflake/connections.toml (or environment), NEVER hardcoded here.
#   See 09_snowpark/README.md for setup.
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    import os

    # Uses a named connection from connections.toml (no secrets in this file).
    connection_name = os.environ.get("SNOWFLAKE_CONNECTION", "gaming_compliance")
    session = Session.builder.config("connection_name", connection_name).create()
    try:
        session.use_role(os.environ.get("SNOWFLAKE_ROLE", "DATA_ENGINEER"))
        session.use_warehouse(os.environ.get("SNOWFLAKE_WAREHOUSE", "WH_DATA_SCIENCE"))
        main(session)
    finally:
        session.close()
