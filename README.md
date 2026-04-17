# SideCoach Blueprint — Infrastructure

> **The Terraform + CI/CD backing the _SideCoach Blueprint_ project card on [nirmitdagli.github.io](https://nirmitdagli.github.io).**
> A production-grade reference architecture for a multi-tenant Azure SaaS — written in real HCL, not diagrams on a slide.

## What this is

A self-contained, runnable reference architecture for a **multi-tenant SaaS on Azure** that serves university athletic programs (or anything shaped like SaaS-per-tenant, really). Two views:

- **Runtime** — the platform: Cloudflare edge, Entra ID, App Service with Managed Identity, Azure SQL with Row-Level Security, Key Vault, Log Analytics.
- **Delivery** — the CI/CD spine: OIDC federated login to Azure (no long-lived secrets in GitHub), `tfsec` / `checkov` / `trivy` gates, staged `dev → staging → prod` with blue/green slot swaps.

## What I want an interviewer to notice

| Principle | Where it shows up |
|---|---|
| **No long-lived secrets** | OIDC federated login (`azure/login@v2`), System-Assigned Managed Identity on App Service, RBAC to Key Vault |
| **Tenant isolation as a policy, not a prayer** | Row-Level Security at the SQL layer (`modules/sql-rls`), per-tenant CNAMEs, per-tenant role scopes in Entra ID |
| **Compliance-ready by design** | Soft-delete + purge-protection on Key Vault, audit logs to Log Analytics, FERPA / COPPA mapped in `docs/compliance.md` |
| **Defense at the edge** | Cloudflare WAF (OWASP), rate limiting on `/api/auth/*`, strict TLS posture — see `infra/cloudflare.tf` |
| **Runnable, not decorative** | `terraform -chdir=infra validate` is green; the pipeline deploys end-to-end in under eight minutes |

## Repo layout

```
.
├─ infra/
│  ├─ main.tf               # Key Vault, App Service + MI, role assignments
│  ├─ cloudflare.tf         # DNS, WAF, rate limit, strict TLS
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ modules/
│     └─ sql-rls/           # Azure SQL with Row-Level Security
├─ .github/workflows/
│  └─ deploy.yml            # OIDC → validate → scan → staging → prod
├─ docs/
│  ├─ architecture-runtime.svg    # Platform view
│  ├─ architecture-delivery.svg   # CI/CD view
│  └─ compliance.md               # FERPA / COPPA mapping
└─ README.md
```

## Try it locally

```bash
terraform -chdir=infra fmt -check
terraform -chdir=infra init -backend=false
terraform -chdir=infra validate
tfsec infra/
checkov -d infra/ --compact --quiet
```

All four should be green on a clean checkout.

## Why the portfolio links here

This repo is the "show your work" half of the SideCoach Blueprint project card at [nirmitdagli.github.io](https://nirmitdagli.github.io). The portfolio shows the story; this repo shows the code. Both commits are on the same day — same person, same week.

—
Nirmit Dagli · Cloud Infrastructure & Security Engineer · [LinkedIn](https://linkedin.com/in/nirmitdagli)
