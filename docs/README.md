# Documentation Index

Central index of all project documentation. All 15 phases are complete; the "Delivered in"
column records which phase produced each document.

> **New here? Start with the [Deployment Guide](deployment_guide.md)** to build the platform
> yourself, and the [Portfolio Limitations](portfolio_limitations.md) for honest scope.

| Document | Purpose | Delivered in |
|---|---|---|
| [`solution_architecture.md`](solution_architecture.md) | Snowflake layered architecture, data flow, warehouse & environment strategy, cost notes | Phase 2 |
| [`data_model.md`](data_model.md) | Dimensional model — every dimension & fact, grains, keys, measures, SCD strategy | Phase 3 |
| [`erd.md`](erd.md) | Entity-relationship diagram (logical + physical), Mermaid + PNG | Phase 3 |
| [`aml_rules_framework.md`](aml_rules_framework.md) | AML typologies, rule logic, scoring, escalation | Phase 8 |
| [`str_workflow.md`](str_workflow.md) | STR case lifecycle, statuses, SLA logic, KPIs | Phase 9 |
| [`governance_model.md`](governance_model.md) | RBAC, least privilege, data classification, masking, Time Travel, retention | Phase 12 |
| [`validation_framework.md`](validation_framework.md) | Data quality + reconciliation + phase-validation approach | Phase 11 |
| [`deployment_guide.md`](deployment_guide.md) | Step-by-step runbook: build the platform in a Snowflake account, in order | Phase 15 |
| [`portfolio_limitations.md`](portfolio_limitations.md) | Honest scope, caveats, what production would add | Phase 15 |

### Learning & validation notes

| Document | Purpose | Delivered in |
|---|---|---|
| [`current_state_phase_01_to_09_audit.md`](current_state_phase_01_to_09_audit.md) | Static audit of the Phase 1–9 build | Phase 10 |
| [`snowflake_learning_audit.md`](snowflake_learning_audit.md) | Snowflake features exercised, mapped to deliverables | Phase 10 |
| [`snowflake_skills_matrix.md`](snowflake_skills_matrix.md) | Skills-to-artifact matrix | Phase 10 |
| [`reporting_layer.md`](reporting_layer.md) | Reporting views + grain-safety design | Phase 10 |
| [`phase_10_reporting_views_learning_notes.md`](phase_10_reporting_views_learning_notes.md) | Reporting-layer learning notes | Phase 10 |
| [`pre_phase10_validation_checklist.md`](pre_phase10_validation_checklist.md) / [`pre_phase10_validation_results.md`](pre_phase10_validation_results.md) / [`post_phase10_validation_results.md`](post_phase10_validation_results.md) | Reporting checkpoint validation | Phase 10 |

### Presentation & execution readiness

> The project is fully authored across 15 phases; the remaining step is **live Snowflake
> execution**. These docs make the status honest and the next step unmistakable.

| Document | Purpose |
|---|---|
| [`final_presentation_audit.md`](final_presentation_audit.md) | Complete vs pending, by area (classification-tagged) |
| [`pre_flight_dry_run_review.md`](pre_flight_dry_run_review.md) | Static end-to-end trace before the live run (2 generator bugs found & fixed) |
| [`next_real_world_step.md`](next_real_world_step.md) | The exact next step: run it live in Snowflake (before any Cursor rebuild) |
| [`manual_snowflake_test_plan.md`](manual_snowflake_test_plan.md) | Ordered run + smoke-test queries |
| [`execution_proof_checklist.md`](execution_proof_checklist.md) | Tick-box proof of what ran |
| [`validation_results.md`](validation_results.md) | Results template to fill after execution (placeholders only) |
| [`screenshot_capture_guide.md`](screenshot_capture_guide.md) | Which evidence to capture after a live run |
| [`sql_formatting_review.md`](sql_formatting_review.md) | SQL readability review (no logic changed) |
| [`final_readiness_checklist.md`](final_readiness_checklist.md) | Final consistency review |

## Diagrams

Diagram sources (Mermaid `.mmd`) and rendered images (`.png`) live in [`../diagrams/`](../diagrams):

| Diagram | Location | Delivered in |
|---|---|---|
| Solution architecture | `diagrams/architecture/` | Phase 2 |
| Logical & physical ERD | `diagrams/data_model/` | Phase 3 |
| AML alert workflow | `diagrams/workflows/` | Phase 8 |
| STR case workflow | `diagrams/workflows/` | Phase 9 |

## Conventions

- Snowflake SQL syntax; uppercase object names; `CREATE OR REPLACE` where appropriate.
- Scripts are runnable in numbered order under [`../snowflake/`](../snowflake).
- All data is synthetic; no credentials or secrets appear anywhere.
