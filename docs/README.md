# Documentation Index

Central index of all project documentation. Most documents are produced in later phases;
this index defines the target set and which phase delivers each.

| Document | Purpose | Delivered in |
|---|---|---|
| [`solution_architecture.md`](solution_architecture.md) | Snowflake layered architecture, data flow, warehouse & environment strategy, cost notes | Phase 2 |
| [`data_model.md`](data_model.md) | Dimensional model — every dimension & fact, grains, keys, measures, SCD strategy | Phase 3 |
| [`erd.md`](erd.md) | Entity-relationship diagram (logical + physical), Mermaid + PNG | Phase 3 |
| [`aml_rules_framework.md`](aml_rules_framework.md) | AML typologies, rule logic, scoring, escalation | Phase 8 |
| [`str_workflow.md`](str_workflow.md) | STR case lifecycle, statuses, SLA logic, KPIs | Phase 9 |
| [`governance_model.md`](governance_model.md) | RBAC, least privilege, data classification, masking, Time Travel, retention | Phase 12 |
| [`validation_framework.md`](validation_framework.md) | Data quality + reconciliation + phase-validation approach | Phase 11 |
| [`deployment_guide.md`](deployment_guide.md) | How to deploy the Snowflake scripts in order | Later phase |
| [`portfolio_limitations.md`](portfolio_limitations.md) | Honest scope, caveats, what production would add | Later phase |

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
