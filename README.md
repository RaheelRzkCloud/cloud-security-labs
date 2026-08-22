# Cloud Security Labs

Hands-on Azure security work, built alongside a structured security architecture learning programme. Each entry starts from a realistic enterprise scenario, works through the security reasoning, then implements and documents the fix — first manually in the Azure portal, then translated into Terraform, since production changes should be deployed as code, not clicked through.

## Why this repo exists

I'm a Cloud Governance Technician moving toward Cloud Security Consulting and Security Architecture. This repo is where the reasoning becomes something built and verifiable, not just theoretical — a record of what I've actually configured, tested, and understood well enough to translate into Infrastructure as Code.

## Approach

Each lab follows the same structure:
1. **The business scenario** — a realistic problem (e.g. a developer hardcoding database credentials in source code)
2. **The security reasoning** — what's wrong, what the risk is, what the right architectural response looks like
3. **Implementation** — built manually in the Azure portal where possible, to understand exactly how the underlying services work; where a live environment wasn't available (e.g. licensing limits on a free trial tenant), reasoned through and built directly as Terraform instead
4. **Infrastructure as Code** — the setup as Terraform, reflecting how this would actually be deployed in a real, governed environment (no ClickOps)
5. **What tripped me up** — genuine troubleshooting notes and, where relevant, real design mistakes caught and corrected — not just a clean success story

## Labs

| Lab | Scenario | Key concepts |
|---|---|---|
| [`managed-identity-keyvault/`](./managed-identity-keyvault) | Developer hardcodes a database password and API key directly in source code | Azure Managed Identity, Key Vault, RBAC (Key Vault Secrets User), least privilege |
| [`conditional-access-mfa/`](./conditional-access-mfa) | CISO wants risk-based MFA, not a blanket policy, for a UK-based org with no international travel | Entra ID Conditional Access, risk-based access control, report-only rollout, break-glass accounts |
| [`landing-zone-governance/`](./landing-zone-governance) | CTO wants to stop ad-hoc, ungoverned resource creation from recurring as the company scales | Azure Management Groups, Azure Policy inheritance, Detect vs. Protect enforcement |
| [`network-segmentation/`](./network-segmentation) | New customer-facing web app needs a database isolated from the office network and the public internet | VNets, Subnets, Network Security Groups, Azure SQL, Private Endpoints, deny-by-default segmentation |
| [`hub-spoke-firewall/`](./hub-spoke-firewall) | Multiple product teams scaling up need consistent outbound network security without each building and reviewing their own | Hub-and-spoke architecture, VNet Peering, Azure Firewall, User-Defined Routes, centralised shared services |

*(More labs added as the learning programme progresses.)*

## Tools & technologies

- Azure (App Service, Key Vault, Entra ID, RBAC, Azure Policy)
- Terraform (organisational IaC standard — no ClickOps in production)
- Azure Portal (for initial hands-on understanding before translating to code)

## Background

Prior experience in service management (Home Office, HMRC) and current Cloud Governance role (mobilisation forums, security consultant assignment, architecture documentation review) — this repo reflects the technical depth being built alongside that governance and stakeholder experience, aimed at Cloud Security Consultant / Security Architecture roles.

