# Recommended DAX Measures

> **Phase 14 deliverable.** DAX measures for the Power BI model, aligned 1:1 with the
> `REPORTING.VW_*` view columns from Phase 10. Table names refer to the imports in
> [`recommended_model.md`](recommended_model.md). Synthetic data only.

**Note on the summary views:** the `*_SUMMARY` / `VW_EXECUTIVE_OVERVIEW` views return **one row**
of pre-computed KPIs, so `SUM(...)` on a value and `AVERAGE(...)` on an already-computed percentage
both return that single value. Detail tables (`AlertTypology`, `Market`, `Trends`, `SLA`,
`AnalystWorkload`, `PlayerRisk`) respond to slicers/time.

## Executive Overview (table `ExecKPIs` + `Trends`)

```DAX
Total Transactions      = SUM(ExecKPIs[TOTAL_TRANSACTIONS])
Total Transaction Value = SUM(ExecKPIs[TOTAL_TRANSACTION_VALUE])
Total GGR               = SUM(ExecKPIs[TOTAL_GGR])
Active Accounts         = SUM(ExecKPIs[LATEST_ACTIVE_ACCOUNTS])
GGR per Active Account  = AVERAGE(ExecKPIs[GGR_PER_ACTIVE])
Hold %                  = AVERAGE(ExecKPIs[HOLD_PCT])
AML Alerts              = SUM(ExecKPIs[AML_ALERTS])
Escalated Alerts        = SUM(ExecKPIs[ESCALATED_ALERTS])
Escalation Rate %       = AVERAGE(ExecKPIs[ESCALATION_RATE_PCT])
STR Cases               = SUM(ExecKPIs[TOTAL_CASES])
STRs Submitted          = SUM(ExecKPIs[STRS_SUBMITTED])
STR Conversion %        = AVERAGE(ExecKPIs[STR_CONVERSION_RATE_PCT])
SLA Compliance %        = AVERAGE(ExecKPIs[SLA_COMPLIANCE_PCT])
Avg Investigation Days  = AVERAGE(ExecKPIs[AVG_INVESTIGATION_DAYS])
```

Trend visuals (respond to the Date slicer):
```DAX
Alerts (monthly)     = SUM(Trends[ALERTS])
Escalated (monthly)  = SUM(Trends[ESCALATED_ALERTS])
STR Cases (monthly)  = SUM(Trends[STR_CASES])
GGR (monthly)        = SUM(Trends[TOTAL_GGR])
```

## AML Monitoring (tables `AlertTypology` + `AMLKPIs`)

```DAX
Total Alerts        = SUM(AlertTypology[ALERTS])       -- responds to the Rule slicer
Escalated (by rule) = SUM(AlertTypology[ESCALATED])
Avg Risk Score      = AVERAGE(AMLKPIs[AVG_RISK_SCORE])
Critical Alerts     = SUM(AMLKPIs[CRITICAL_ALERTS])
Sanctions Hits      = SUM(AMLKPIs[SANCTIONS_HITS])
High-Risk Accounts  = SUM(AMLKPIs[HIGH_RISK_ACCOUNTS])
Rules Firing        = SUM(AMLKPIs[RULES_FIRING])
```

## STR Workflow (tables `STRKPIs`, `SLA`, `AnalystWorkload`, `StatusFunnel`)

```DAX
Total Cases            = SUM(STRKPIs[TOTAL_CASES])
Open Backlog           = SUM(STRKPIs[OPEN_BACKLOG])
STRs Filed             = SUM(STRKPIs[STRS_FILED])
STR Conversion %       = AVERAGE(STRKPIs[STR_CONVERSION_PCT])
SLA Compliance % (STR) = AVERAGE(STRKPIs[SLA_COMPLIANCE_PCT])
SLA Breaches           = SUM(SLA[SLA_BREACHES])
Analyst Cases          = SUM(AnalystWorkload[TOTAL_CASES])
Analyst Open Cases     = SUM(AnalystWorkload[OPEN_CASES])
Analyst STRs Filed     = SUM(AnalystWorkload[STRS_FILED])
Cases in Status        = SUM(StatusFunnel[CASES])       -- ordered by WORKFLOW_ORDER
```

## Market / GGR (tables `Market` + `MarketFY`)

```DAX
Monthly GGR       = SUM(Market[TOTAL_GGR])
Monthly Wagers    = SUM(Market[TOTAL_WAGERS])
Hold % (Market)   = AVERAGE(Market[HOLD_PCT])
MoM GGR Growth %  = AVERAGE(Market[MOM_GGR_GROWTH_PCT])
Active Accounts (Market) = SUM(Market[ACTIVE_ACCOUNTS])
GGR YoY %         = AVERAGE(MarketFY[GGR_YOY_PCT])       -- pre-computed in the view

-- Optional: compute YoY in DAX instead (needs the marked Date table)
GGR YoY % (DAX) =
VAR Cur = [Monthly GGR]
VAR Prev = CALCULATE([Monthly GGR], SAMEPERIODLASTYEAR('Date'[Date]))
RETURN DIVIDE(Cur - Prev, Prev)
```

## Player Risk (table `PlayerRisk`)

```DAX
Players            = COUNTROWS(PlayerRisk)
High-Risk Players  = CALCULATE(COUNTROWS(PlayerRisk), PlayerRisk[COMPOSITE_RISK_BAND] IN {"Critical","High"})
Players with Alerts= CALCULATE(COUNTROWS(PlayerRisk), PlayerRisk[ALERT_COUNT] > 0)
Players with STRs  = CALCULATE(COUNTROWS(PlayerRisk), PlayerRisk[STRS_FILED] > 0)
Total Player Value = SUM(PlayerRisk[TXN_VOLUME])
Max Risk Score     = MAX(PlayerRisk[MAX_RISK_SCORE])
```

## Formatting

- `*%` measures → **Percentage**; value measures → **Currency** (0–2 dp); counts → **Whole number**.
- These names map directly to the dashboard-page metrics in
  [`../../powerbi/dashboard_specification.md`](../../powerbi/dashboard_specification.md).
