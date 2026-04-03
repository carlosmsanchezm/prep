# Architecture Practice: NTConcepts Bird-Dog Network Architecture

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the hub-and-spoke network with Transit Gateway
2. Show the packet flow from a spoke workload to the internet
3. Explain every hop — this is the networking depth Anduril tests
4. Time yourself: 10 minutes to draw + narrate

---

## What You Should Be Able to Draw

### Overview

```
                    ┌──────────────────────────────┐
                    │     INFRASTRUCTURE ACCOUNT    │
                    │       (Hub / Inspection)      │
                    │                               │
                    │  ┌─────────────────────────┐  │
                    │  │    Inspection VPC        │  │
                    │  │                          │  │
                    │  │  TGW subnet              │  │
                    │  │     ↓                    │  │
                    │  │  NFW endpoint            │  │
                    │  │     ↓                    │  │
                    │  │  Firewall subnet         │  │
                    │  │     ↓                    │  │
                    │  │  NAT Gateway             │  │
                    │  │     ↓                    │  │
                    │  │  Public subnet           │  │
                    │  │     ↓                    │  │
                    │  │  Internet Gateway (IGW)  │  │
                    │  └─────────────────────────┘  │
                    └───────────────┬────────────────┘
                                   │
                          ┌────────┴────────┐
                          │  Transit Gateway │ (shared via AWS RAM)
                          └────────┬────────┘
                    ┌──────────────┼──────────────┐
                    │              │              │
              ┌─────┴─────┐ ┌─────┴─────┐ ┌─────┴─────┐
              │ Directory  │ │  Collab   │ │  Proj64   │
              │  (spoke)   │ │  (spoke)  │ │  (spoke)  │
              │            │ │           │ │           │
              │ Private    │ │ Private   │ │ Private   │
              │ subnets    │ │ subnets   │ │ subnets   │
              │            │ │           │ │           │
              │ VPC        │ │ VPC       │ │ VPC       │
              │ Endpoints  │ │ Endpoints │ │ Endpoints │
              └────────────┘ └───────────┘ └───────────┘
```

### TGW Route Tables

**Inspection Route Table** (attached to spoke VPCs):
- 0.0.0.0/0 → Network Firewall attachment (ALL traffic goes through firewall)

**Return Route Table** (attached to Inspection VPC):
- 10.0.1.0/24 → Directory spoke attachment
- 10.0.2.0/24 → Collab spoke attachment
- 10.0.3.0/24 → Proj64 spoke attachment

### Inspection VPC Architecture (per-AZ)

```
Spoke traffic arrives at TGW
    ↓
TGW subnet → NFW endpoint (Network Firewall)
    ↓
Firewall subnet → NAT Gateway
    ↓
Public subnet → Internet Gateway (IGW)
    ↓
Internet
```

**Appliance mode MUST be enabled** on the TGW attachment — without it, return traffic can take a different AZ path and bypass the firewall (asymmetric routing).

### Network Firewall Rules

**Default action:** `aws:drop_established` — everything not explicitly allowed is dropped.

**Rule groups (stateful allowlist):**
1. Core HTTPS: PKI/OCSP endpoints for certificate validation
2. AWS GovCloud APIs: STS, SSM, S3, ECR (so spoke workloads can call AWS services)
3. Controlled dev/testing URLs: specific domains for development needs

### VPC Endpoints (in each spoke)

Each spoke has its own:
- **Interface endpoints:** STS, EC2, ECR, S3
- **Gateway endpoints:** S3, DynamoDB

**Why?** Traffic to AWS services stays WITHIN the AWS network — never traverses the firewall or internet. Private API access.

---

## Packet Trace Exercise

**Scenario:** A pod in the Proj64 spoke needs to reach https://api.external.com

Trace the packet through EVERY hop:

1. Pod generates HTTPS request
2. Pod DNS lookup → CoreDNS → upstream DNS → resolves to IP
3. Packet leaves pod via veth → CNI bridge → node NIC
4. Node routing table → default route → spoke VPC route table
5. VPC route table → 0.0.0.0/0 → TGW attachment
6. TGW → Inspection Route Table → Network Firewall attachment
7. Network Firewall inspects against stateful rules
8. If ALLOWED → forwarded to firewall subnet → NAT Gateway
9. NAT Gateway translates private IP to public IP (SNAT)
10. Public subnet → IGW → internet → api.external.com
11. Response follows reverse path: IGW → NAT → NFW (established session) → TGW (Return RT) → spoke VPC → node → pod

**What breaks if appliance mode is disabled?**
- Return traffic might enter TGW in a different AZ
- Gets routed to NFW endpoint in wrong AZ
- NFW doesn't see it as part of an established session → DROPS it
- Symptom: intermittent connection failures, especially for long-lived connections

---

## Follow-Up Questions (Answer Aloud)

1. **"Why Network Firewall instead of Palo Alto?"**
   - Native TGW integration — no VM instances to manage
   - Lower operational overhead in GovCloud
   - Allowlist approach doesn't need deep L7 inspection
   - Tradeoff: less feature depth, but sufficient for our use case

2. **"Why allowlist instead of denylist?"**
   - DoD posture: deny by default, allow explicitly
   - Smaller attack surface — only known-good domains reachable
   - Easier to audit: "here's everything we allow" vs. "here's everything we block"
   - New domains require explicit approval — prevents shadow IT

3. **"How do you add a new spoke account?"**
   - Create VPC with private subnets
   - Share TGW via AWS RAM
   - Create TGW attachment with appliance mode
   - Add spoke CIDR to Return RT
   - Create VPC endpoints for private AWS API access
   - All automated via Terraform modules

4. **"What's the latency impact?"**
   - P95 < 75ms for inspected traffic
   - VPC endpoint traffic (AWS API calls) = sub-millisecond (no firewall traversal)
   - NAT Gateway and NFW add ~1-3ms each
   - 99.95% regional HA

---

## Answer Keys + Coaching

- **Real architecture reference:** `ntconcepts-answers.md` — first mermaid chart (full network topology with CIDRs, account names, VPC endpoints)
- **How to present this:** `deep-dive-coaching-guide.md` — System 4
