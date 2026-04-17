# Compliance Mapping — FERPA · COPPA

This platform touches two student-data regimes. Neither is optional for
university athletic programs. The table below maps the controls each
regulation requires to the specific Terraform resources + CI steps that
enforce them.

## FERPA (Family Educational Rights and Privacy Act)

| FERPA control | Implementation |
|---|---|
| Directory-information opt-out | Per-tenant toggle in `dbo.tenants.directory_opt_in`; app reads it before any student record returns in a public route. |
| Consent for disclosure | Every API response carrying PII is tagged `X-FERPA-Consent-Scope`; audit log (`dbo.disclosures`) has a row per disclosure. |
| Access logs retained 5y | Activity logs + diagnostic settings ship to Log Analytics with a 5-year retention tier (see `main.tf` → `azurerm_monitor_diagnostic_setting`). |
| Right to inspect / amend records | `/api/students/me/export` dumps every row keyed to the authenticated student; `/api/students/me/amend-request` files an amendment ticket. |

## COPPA (Children's Online Privacy Protection Act)

> Triggers only when a tenant enables "Under-13 mode" — common for
> high-school feeder programs enrolled in university camps.

| COPPA control | Implementation |
|---|---|
| Verifiable parental consent | Consent flow via signed email + challenge question; consent record stored in `dbo.parental_consents`, linked to `dbo.athletes.id`. |
| Limited data collection | Schema enforces NULL on `dbo.athletes.phone_number`, `dbo.athletes.home_address` when `age_band = 'U13'`. |
| No behavioral tracking | Analytics pipeline strips any event where the subject's `age_band = 'U13'`. Tested in `tests/coppa_under13_no_tracking.py`. |
| Safe deletion | Tombstone → hard delete after 30d. `dbo.pending_deletions` is processed by a Durable Function nightly. |

## Evidence for an auditor

1. **IaC proves intent** — every Key Vault, SQL server, App Service in this repo is in source control; every secret is rotated via Managed Identity, never typed into a console.
2. **CI proves enforcement** — `tfsec` + `checkov` block a PR that introduces a public SQL server or an unencrypted Storage Account.
3. **Logs prove fact** — Activity Log + diagnostic settings → Log Analytics → immutable cold tier for ≥ 5 years.

If an auditor asks "can you prove no student data ever lived on a
public endpoint?" the answer is: `checkov.CKV_AZURE_1` has failed
every PR that would have allowed it.
