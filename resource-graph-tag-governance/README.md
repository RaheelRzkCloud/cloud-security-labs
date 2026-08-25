# Resource Graph Tag Governance: Detecting Missing and Invalid Metadata

## Scenario

A periodic report at work had identified Azure resources with missing or invalid `ProjectCode` tags. The existing process was reactive: wait for a report, identify the resource owner, ask them to fix it. There was no way for Governance to self-serve this visibility — it depended on someone manually producing a CSV.

This raised a set of questions worth answering hands-on, in a sanitised personal lab: where does tag data actually live, how can it be queried at scale, and — critically — is "the tag exists" the same thing as "the tag is correct"?

## The design

Three fictional business lines, each with its own resource group and one storage account, deliberately tagged to represent three different real-world states:

| Business line | Resource group | ProjectCode | Represents |
|---|---|---|---|
| Credit Cards | `rg-creditcards-prod-uks` | `PC001` | Valid (control case) |
| Mortgages | `rg-mortgages-prod-uks` | *(not set)* | Missing tag |
| Business Banking | `rg-businessbanking-prod-uks` | `TBC` | Present but meaningless |

The goal was to prove — with real queries against real resources, not assumption — that "missing" and "invalid" are two different failure modes, and that a control designed to catch one won't automatically catch the other.

**Scope decision:** the list of valid ProjectCodes is hardcoded directly into the KQL query rather than pulled from an external source of truth. Azure Policy and Resource Graph can only evaluate values available to them at evaluation time — they can't call out to a live CSV or database mid-query. A hardcoded list means updating it requires a code change rather than a simple data edit, which doesn't scale in a real enterprise. For this lab, that trade-off was accepted deliberately rather than building a Function/Logic App integration that would have added complexity without adding to the core lesson. Documented here as a known limitation, not an oversight.

## What actually happened (the real troubleshooting)

**1. Tags do not inherit from resource group to resource.** Tagging the resource group did nothing to the storage account created inside it — confirmed by checking the storage account's own Tags blade and finding it empty until tagged explicitly. Every resource needs its own tags; there is no automatic inheritance in the portal.

**2. An unplanned Deny policy hit — a live example of Deny vs Audit.** Creating the first storage account failed validation: a built-in policy disallowed public network access. This wasn't something I'd configured — it stopped the deployment before the resource ever existed. It became a useful, concrete comparison point for the Audit vs Deny distinction I was about to explore for tagging: Deny blocks a bad state at creation time; Audit would have let it be created and just flagged it afterwards.

**3. First KQL attempt at the combined query returned zero rows.** The intent was "flag a resource if its ProjectCode is empty OR not in the valid list," written as:

```kql
| where isempty( tags["ProjectCode"] !in ("PC001", "PC002", "PC003") )
```

This nests a boolean expression (`!in`, which already evaluates to true/false) inside `isempty()`, which expects a value to test for blankness — not another boolean. The fix was to stop nesting and join the two independent conditions with `or`:

```kql
Resources
| where resourceGroup contains "prod-uks"
| extend ProjectCodeValue = tags['ProjectCode']
| where isempty(ProjectCodeValue) or ProjectCodeValue !in ("PC001", "PC002", "PC003")
```

**4. A typo in the allow-list would have produced a false positive.** An early draft of the valid list read `"PR001", "PR002", "PR003"` instead of `PC0xx` — which would have wrongly flagged the valid Credit Cards resource as non-compliant. Caught before running, but a reminder that a hardcoded allow-list is only as reliable as whoever typed it; a single typo silently breaks trust in the control's output.

**5. Proof that "missing" and "invalid" genuinely need different queries.** Running `isempty()` alone correctly found the missing-tag resource (Mortgages) but said nothing about the invalid-value resource (Business Banking, `TBC`) — because `TBC` is a non-empty string, so a presence check alone is blind to it:

![isempty() alone only catches the missing tag](./screenshots/missing-only-query.png)
*`isempty(ProjectCodeValue)` correctly isolates Mortgages — but Business Banking's `TBC` value doesn't appear, since it isn't empty.*

Extending the query with tag values visible across all three resources made the gap easy to see directly:

![All three resources with their ProjectCode values side by side](./screenshots/all-tag-values.png)
*Credit Cards (`PC001`), Business Banking (`TBC`), Mortgages (blank) — the difference between "wrong" and "missing" is visible, but not yet flagged automatically.*

Combining both conditions with `or` correctly caught both failure modes in a single query, while leaving the valid resource untouched:

![Combined query flags both missing and invalid resources](./screenshots/missing-and-invalid-query.png)
*`isempty(ProjectCodeValue) or ProjectCodeValue !in (...)` returns exactly Mortgages and Business Banking — Credit Cards correctly does not appear.*

## What this demonstrates

- **Presence and validity are different technical checks, not one problem** — a query built to catch missing tags will not catch meaningless ones, and treating them as the same control creates a false sense of coverage.
- **Governance self-serve, proven, not theoretical** — a single KQL query replaced what would otherwise be a manual, resource-by-resource click-through, directly mirroring the CSV-report bottleneck this lab was based on.
- **Deny vs Audit, encountered in practice, not just described** — an unrelated built-in policy blocked deployment before the resource existed, giving a real, unprompted comparison to the detective-only alternative.
- **A control is only as trustworthy as the assumptions behind it** — a typo in a hardcoded allow-list, or a boolean nested inside the wrong function, would have silently produced incorrect compliance results rather than an obvious error.

## Status / next steps

This lab currently covers **discovery only** — Azure Resource Graph and KQL. It does not yet implement enforcement or infrastructure-as-code:

- **Not yet done:** Azure Policy (Audit effect, then Deny) built on top of this same tagging logic, to move from detecting non-compliance to preventing it at deployment time.
- **Not yet done:** Terraform recreation of the resource groups, storage accounts, and eventually the Policy definitions — deliberately left until the manual/portal-driven logic above was fully understood and evidenced first.

## Technologies

Azure Resource Graph · Kusto Query Language (KQL) · Azure Policy (encountered, not yet built) · Azure Storage · Azure Tags

