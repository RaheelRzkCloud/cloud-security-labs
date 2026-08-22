# Hub-and-Spoke Architecture: Centralised Outbound Firewall

## Scenario

The CTO raised a scaling concern: as more product teams onboard, each building their own version of network security controls (their own firewall rules, their own review process) creates inconsistency, cost, and a growing governance burden — every team's slightly different setup needs its own separate security review.

## The design

A **hub-and-spoke** architecture: a central **hub VNet** owned by a platform team, housing shared services (in this lab, an Azure Firewall); and **spoke VNets**, one per application team, connected to the hub via **VNet Peering**. Rather than each spoke building its own outbound security, a **User-Defined Route (UDR)** on the spoke forces all its outbound traffic through the hub's centrally-managed firewall before it can reach the internet.

## What actually happened (the real build)

**1. VNet address space overlap.** The hub and spoke needed distinct, non-overlapping address ranges (`10.1.0.0/16` and `10.2.0.0/16`) — two VNets with overlapping ranges cannot be peered at all. An initial attempt defaulted to the same range as an earlier, unrelated lab and had to be corrected before peering would work.

**2. `AzureFirewallSubnet` — a mandatory, exact subnet name.** Azure's firewall deployment automation looks specifically for this name to know where to place the firewall; any other name fails deployment.

**3. The real gotcha: Basic SKU requires a second, separate mandatory subnet.** Deployment failed with *"Force Tunneling requires this virtual network have a subnet named AzureFirewallManagementSubnet"* — a requirement specific to the Basic tier, keeping the firewall's own administrative traffic separate from the customer traffic it inspects. This wasn't anticipated in advance; it only surfaced as a deployment-time error, and required going back to add a second subnet with its own separate public IP before the firewall would deploy at all.

**4. Cost discipline throughout.** Azure Firewall has no free tier — even the cheapest Basic SKU carries a fixed hourly charge regardless of traffic volume. The build was deliberately time-boxed, and the entire resource group was torn down immediately after testing rather than left running.

**5. VM availability constraint.** An attempt to deploy a small test VM into the workload subnet — to prove the routing end-to-end with real traffic — hit a wall: no VM size was available for this trial subscription in the region used, across both Arm64 and x64 architectures. Rather than continue spending time and firewall cost chasing an increasingly unlikely fix, the decision was made to verify the design through configuration review instead of live traffic. Knowing when to stop and document rather than keep spending is itself a reasonable engineering judgement call, not a shortfall in the work.

## What this demonstrates

- **Centralising shared controls while preserving team-level isolation** — the hub owns the firewall and review burden once; spokes stay isolated from each other but consume the shared service via peering
- **Peering as two independently-consented objects** — each VNet owner (potentially different teams) explicitly configures their own side of the relationship, rather than one shared setting either side could silently change
- **A User-Defined Route (`0.0.0.0/0` → firewall's private IP) forcing traffic through a specific path** — connectivity (peering) and routing (UDRs) are separate mechanisms; peering alone does not force traffic through any particular route
- **Real deployment-time discovery of a requirement not visible in advance** — the management subnet requirement only appeared as an error at deployment, not as something researched and pre-empted
- **Deliberately stopping a test path when it stops being a good use of time and cost**, and documenting that decision honestly rather than pretending an end-to-end live test happened

## Architecture

The spoke's workload subnet is forced, via UDR, through the hub's firewall subnet before reaching the internet. The firewall's separate management subnet and public IP keep its own administrative traffic apart from customer traffic entirely.

## Built two ways

1. **Manually, in the Azure portal** — including every obstacle documented above
2. **As Terraform** — see `main.tf`

## Technologies

Azure Virtual Network · VNet Peering · Azure Firewall (Basic SKU) · Firewall Policy · User-Defined Routes (UDR) · Route Tables · Terraform

