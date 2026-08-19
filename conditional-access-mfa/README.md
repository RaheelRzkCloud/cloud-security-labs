# Conditional Access: Risk-Based MFA

## Scenario

Following an account compromise (see the identity/incident scenarios in my broader learning programme), the CISO asked for a Conditional Access policy — but explicitly not a blanket "MFA for everyone, always" policy, since that trains people to approve MFA prompts without thinking and drives support tickets up. The brief: something targeted at real risk signals.

The environment: a UK-based organisation, no international travel, company-issued Intune-managed laptops, with a few people occasionally checking email from personal phones.

## The design

Two independent policies, each requiring MFA on its own risk signal:

1. **`outside_uk_mfa`** — requires MFA for any sign-in from outside the UK
2. **`noncompliant_device_mfa`** — requires MFA for any sign-in from a device that isn't Entra-joined/compliant

Both start in **report-only mode** (`enabledForReportingButNotEnforced`) rather than fully enforced — a new policy should never go straight to blocking real sign-ins on day one. Report-only mode shows exactly who *would* have been affected, based on real sign-in data, without actually blocking anyone. Only once that data confirms the policy behaves as intended would it move to enforced.

Both policies also carry an explicit note that a break-glass/emergency admin account must be excluded — the one account that must always remain reachable, precisely because it's the account you'd need to fix things if a policy misfired and locked people out.

## A genuine mistake, and the fix

My first draft combined both the UK-location and non-compliant-device conditions into a **single** policy. That was wrong: conditions within one Conditional Access policy are combined with **AND logic**, not OR — so that policy would only have required MFA when a sign-in was *both* outside the UK *and* on a non-compliant device, at the same time.

That missed real risk: a UK-based sign-in from an unmanaged personal device, or an overseas sign-in from a fully compliant company laptop, would both have been ignored entirely. The fix was splitting it into two separate, independent policies, each firing on its own signal — the version in this repo.

## Why this couldn't be built live

Conditional Access requires an Entra ID P1 or P2 licence. My free-trial tenant (personal/consumer-based) couldn't self-provision a trial P2 licence through either the Azure portal or the Entra admin center — both blocked on "you need a Microsoft Entra ID Premium licence." Rather than leave the lab undone, I wrote and reasoned through the full policy as Terraform instead — which is genuinely how Conditional Access is often managed in real organisations anyway, as code reviewed through a pipeline, not manual portal clicks.

## What this demonstrates

- **Risk-based, not blanket, controls** — matching the CISO's actual brief rather than defaulting to "MFA everywhere"
- **Report-only rollout** for any new policy with the power to lock people out — same principle as testing a backup restore before trusting it
- **Break-glass account exclusion** as a non-negotiable safeguard on any access-restricting policy
- **Reusable, single-source-of-truth definitions** (the UK named location) rather than duplicating logic across policies
- **Recognising and correcting a real logic error** (AND vs. OR) rather than assuming a first draft was correct

## Technologies

Microsoft Entra ID · Conditional Access · Terraform (azuread provider)

