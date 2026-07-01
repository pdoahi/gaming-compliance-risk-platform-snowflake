# Governance & Security Model

> **Phase 12 deliverable.** How the platform handles access, sensitive identifiers,
> classification, auditability, and retention — the controls a regulated compliance workload
> needs. Policy SQL is in
> [`snowflake/00_setup/04_governance_policies.sql`](../snowflake/00_setup/04_governance_policies.sql).

> ⚠️ **Synthetic data only.** No real people, players, transactions, PII, credentials, or
> secrets exist here. These controls **demonstrate** what a real regulated deployment would
> apply to genuine sensitive data.

## 1. Role-based access control (RBAC)

Six functional roles (created in `00_setup/03`), each granted only what its job needs:

| Role | Purpose |
|---|---|
| `PLATFORM_OWNER` | Platform admin; inherits all functional roles |
| `DATA_ENGINEER` | Builds & loads RAW → STAGING → CORE → ANALYTICS → REPORTING |
| `COMPLIANCE_ANALYST` | Investigates: reads REPORTING + ANALYTICS |
| `COMPLIANCE_MANAGER` | Oversight: analyst access + curated CORE read |
| `BI_REPORTING` | Power BI service role; **REPORTING views only** |
| `READ_ONLY_AUDITOR` | Read-only across all data layers for audit |

## 2. Access matrix (least privilege)

| Schema | ENGINEER | ANALYST | MANAGER | BI_REPORTING | AUDITOR |
|---|---|---|---|---|---|
| RAW | read/write | — | — | — | read |
| STAGING | read/write | — | — | — | read |
| CORE | read/write | — | read | — | read |
| ANALYTICS | read/write | read | read | — | read |
| REPORTING | create views | read | read | **read** | read |
| GOVERNANCE | — | — | — | — | read |

Key least-privilege choices: BI touches **only** REPORTING (never raw/core); analysts get no
write anywhere; the auditor is read-only everywhere; `FUTURE` grants auto-extend read to new
objects for the right roles.

## 3. Data classification

Two Snowflake **tags** (`00_setup/04`):
- `DATA_CLASSIFICATION` ∈ {PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED} — applied to objects
  (`FACT_AML_ALERTS`/`FACT_STR_CASES` = **RESTRICTED**; player/account/transactions =
  **CONFIDENTIAL**; market = **INTERNAL**).
- `PII` ∈ {IDENTIFIER, QUASI_IDENTIFIER, NONE} — marks identifier columns (`PLAYER_ID`,
  `ACCOUNT_ID`). Tags make it possible to find and govern sensitive data at scale.

## 4. Dynamic data masking

`MP_IDENTIFIER` masks player/account identifiers by role:
- Owners / engineers / managers → full value
- Analysts → partial (`PLR-****XX`)
- Everyone else → `***MASKED***`

Applied to `DIM_PLAYER.PLAYER_ID` and `DIM_ACCOUNT.ACCOUNT_ID`. Because BI reads only REPORTING
views, masking protects direct CORE access without affecting dashboards. In a real deployment
the masked columns would be true PII (name, DOB, email, national ID).

## 5. Row-access policy

`RAP_REGION` scopes rows by region: oversight roles (owner/manager/auditor/engineer) see all;
an analyst is limited to their region. Applied to `DIM_PLAYER.REGION_CODE`. In production the
allowed region(s) would come from a user→region mapping table, not a hard-coded value.

## 6. Time Travel & recovery

Snowflake **Time Travel** allows point-in-time queries and recovery — valuable for audit and
historical risk reconstruction. DB-level retention is a cost-aware 1 day (Phase 4); the
**RESTRICTED** compliance facts (`FACT_AML_ALERTS`, `FACT_STR_CASES`) are extended to **14
days** for a longer audit window. Examples: `AT(OFFSET => -3600)`, `BEFORE(STATEMENT => ...)`,
`UNDROP TABLE`.

## 7. Audit-friendly metadata

Every layer carries lineage/audit columns so activity is traceable:
- Ingestion/staging: `LOAD_BATCH_ID`, `SOURCE_FILE_NAME`, `FILE_ROW_NUMBER`, `LOADED_AT`, `STAGED_AT`.
- Core/derived: `SOURCE_SYSTEM`, `CREATED_AT` (and `UPDATED_AT` where relevant).
- Plus Snowflake **`QUERY_HISTORY` / `ACCESS_HISTORY`** (via `ACCOUNT_USAGE`) for who-queried-what.

## 8. Retention notes

- Transient RAW/STAGING (rebuildable) → minimal Time-Travel, no Fail-safe (cost).
- CORE curated tables → standard tables with Time Travel; RESTRICTED facts extended to 14 days.
- Real programmes set retention by regulatory record-keeping requirements (often years, in a
  separate archive), which is out of scope for this portfolio demo.

## 9. Alignment with regulated-data principles

- **Least privilege & separation of duties** — functional roles; BI can't reach raw/core.
- **Data minimization / masking** — identifiers exposed only to roles that need them.
- **Classification & tagging** — sensitivity is explicit and queryable.
- **Auditability** — lineage columns + Time Travel + query/access history.
- **Recoverability** — Time Travel + `UNDROP`.

## 10. Portfolio-safe vs. real-world

| This project | Real regulated environment |
|---|---|
| Synthetic data; identifiers are fake | Genuine PII under masking + tokenization |
| Hard-coded region in row policy | User→entitlement mapping table |
| ACCOUNTADMIN applies policies | Dedicated security/governance role, SoD-controlled |
| 1–14 day retention | Multi-year record-keeping + archival tier |

## 11. Demo Governance Limitations

> These policies are **portfolio/demo patterns that illustrate the mechanics** of Snowflake
> governance. They are **not** a production-ready access-control design. Read them as "here is
> how the control works," not "here is a hardened deployment." Status: **Implemented as Demo
> Pattern** (authored & statically reviewed; live execution pending — see
> [`validation_results.md`](validation_results.md)).

Specific limitations to be transparent about:

- **Hard-coded region.** `RAP_REGION` grants the analyst role rows where `REGION_CODE =
  'REGION-A'` — a literal. There is no user-to-region entitlement source, so every analyst sees
  the same region regardless of who they are.
- **Role-only logic.** Masking and row access branch solely on `CURRENT_ROLE()`. There is no
  attribute-based access control, no per-user context, and no session policy.
- **Masking scope is narrow.** `MP_IDENTIFIER` covers `PLAYER_ID` / `ACCOUNT_ID` only. Real PII
  (name, DOB, email, national ID, payment instrument) is not present because the data is
  synthetic, so the masking surface is illustrative.
- **No audit/access-review process.** `QUERY_HISTORY` / `ACCESS_HISTORY` are referenced but no
  access-review workflow, alerting, or periodic recertification is implemented.
- **Elevated actor.** Policies are applied as `ACCOUNTADMIN` for convenience rather than a
  delegated, separation-of-duties-controlled security role.
- **No environment separation.** A single account/database; no dev/test/prod isolation or
  change-management gate on policy changes.
- **Not executed.** The policies have not been run/verified against a live account here; the
  verification queries at the end of `00_setup/04_governance_policies.sql` are the source of
  truth once you run them.

## 12. Future Enhancements (toward production governance)

- **Dynamic access mapping table** — a `GOVERNANCE.USER_ENTITLEMENTS` table (user → allowed
  regions/business units) that `RAP_REGION` joins against, replacing the hard-coded region.
- **Production-grade RBAC** — SoD-controlled security-admin role hierarchy, IdP/SSO + SCIM
  provisioning, network policies, and periodic access recertification.
- **Data-classification governance** — a maintained tag taxonomy with automated tag-based
  policy propagation and a classification review process.
- **Masking-policy expansion** — cover all true-PII columns with format-preserving or
  tokenized masking, plus conditional masking by purpose/consent.
- **Row-access-policy expansion** — multi-dimensional entitlements (region + product +
  case-sensitivity), driven entirely by mapping tables.
- **Audit history & access review** — persisted access-review evidence from `ACCESS_HISTORY`,
  alerting on policy changes, and scheduled recertification.
