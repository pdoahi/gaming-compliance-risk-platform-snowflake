# 08_automation — Streams & Tasks (OPTIONAL)

> ⚠️ **Optional layer.** The platform works fully without this — Phases 5–10 do a complete
> batch build/refresh. This folder shows how to make the pipeline **incremental and scheduled**
> with Snowflake Streams + Tasks. Synthetic data only; no secrets.

## What's here

| File | Purpose |
|---|---|
| `01_streams.sql` | `STRM_NEW_TRANSACTIONS` — an append-only stream on `FACT_TRANSACTIONS` that captures only newly inserted rows |
| `02_tasks.sql` | `TSK_INCREMENTAL_ALERTS` — a scheduled task that consumes the stream and flags large new transactions, gated on `SYSTEM$STREAM_HAS_DATA` |

## The pattern

```text
new rows -> FACT_TRANSACTIONS -> STREAM (offset of new rows) -> TASK (scheduled, when stream has data) -> FACT_AML_ALERTS
```

Instead of re-scanning every transaction on each run, the stream tells the task exactly which
rows are new, and the task only fires when there is something to do.

## 💲 Cost cautions (important)

- **Streams are cheap** (they store offsets, not data). **Tasks cost compute per run.**
- The task is **created SUSPENDED** — nothing runs (or bills) until you `RESUME` it.
- It uses `WHEN SYSTEM$STREAM_HAS_DATA(...)` so empty runs are skipped (free).
- Keep the `SCHEDULE` infrequent, the warehouse `XSMALL` with `AUTO_SUSPEND`, and
  **`SUSPEND` the task when you're done** so it doesn't keep billing.

## Enable / disable

```sql
-- enable (one-time privilege, then resume)
USE ROLE ACCOUNTADMIN; GRANT EXECUTE TASK ON ACCOUNT TO ROLE DATA_ENGINEER;
USE ROLE DATA_ENGINEER; ALTER TASK ANALYTICS.TSK_INCREMENTAL_ALERTS RESUME;
-- disable (stop billing)
ALTER TASK ANALYTICS.TSK_INCREMENTAL_ALERTS SUSPEND;
```

## Portfolio note

This demonstrates the **concept** of automated, incremental compliance processing. A real
deployment would add a dedicated task warehouse, task-graph dependencies (DAG), failure
alerting, and monitoring via `TASK_HISTORY` — out of scope for this portfolio demo.
