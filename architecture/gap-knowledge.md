# Gap Knowledge — Study These Until You Can Explain Without Notes

> These are the concepts you flagged as not fully understanding. Read this file until every section clicks. Then close it, explain each concept aloud, and check if you got it right.

---

## 1. Multi-Tenancy — What It Actually Means and How It Works

### "Does the whole JCWA run on one cluster?"

**No.** Multi-tenancy doesn't mean one giant cluster for everything. Here's the actual setup:

Each ENVIRONMENT gets its own EKS cluster — dev has a cluster, staging-left has a cluster, staging-right has a cluster, production has a cluster. That's 8+ clusters across 2 classification levels.

Within EACH cluster, multiple mission app teams deploy their workloads. That's multi-tenancy — multiple teams sharing one cluster, isolated from each other.

```
JCWA Program
├── Dev Cluster (unclassified)
│   ├── Tenant: JAWS team (namespace: jaws)
│   ├── Tenant: CyberAlly team (namespace: cyberally)
│   └── Tenant: Platform team (namespace: platform-services)
│
├── Staging Cluster (unclassified)
│   ├── Same tenants, pre-production testing
│
├── Production Cluster (unclassified)
│   ├── Same tenants, live workloads
│
└── SIPRNET Cluster (classified)
    ├── Same tenants, classified workloads
```

### "How are tenants isolated?"

Each tenant gets:

1. **Namespace** — a K8s boundary. Tenant A's pods are in namespace `jaws`, Tenant B's in `cyberally`. By default they CAN see each other (K8s namespaces aren't true security boundaries), so you add:

2. **RBAC (Role-Based Access Control)** — "JAWS team can only read/write resources in the `jaws` namespace. They can't touch `cyberally` namespace." Enforced at the API server — if they try `kubectl get pods -n cyberally`, they get "Forbidden."

3. **Network Policies** — "Pods in `jaws` namespace can only talk to pods in `jaws` namespace. No cross-namespace traffic unless explicitly allowed." Enforced by the CNI (Calico).

4. **Vault Policies** — "JAWS team can only read secrets under the `jaws/` path in Vault. They can't read `cyberally/` secrets." Automated via Crossplane — team declares their access needs, Crossplane provisions the Vault policy.

5. **ArgoCD Projects** — "JAWS team's ArgoCD project can only deploy to the `jaws` namespace. Can't deploy to `cyberally` or `platform-services`." Enforced by ArgoCD's project-level RBAC.

6. **Resource Quotas** — "JAWS namespace gets max 8 CPU, 16Gi memory. Can't consume the whole cluster." Enforced by K8s ResourceQuota objects.

### "What makes a cluster 'big' in multi-tenancy terms?"

Not one number — it's a combination:

| Metric | Small cluster | Medium | Large |
|--------|--------------|--------|-------|
| Namespaces (tenants) | 5-10 | 20-50 | 100+ |
| Pods | 50-100 | 200-500 | 1000+ |
| Nodes | 3-10 | 10-30 | 50+ |
| Services | 10-20 | 50-100 | 200+ |
| Teams deploying | 2-3 | 5-10 | 20+ |

For JCRS-E: 20+ services, 4 programs deploying, multiple namespaces per program — that's a MEDIUM cluster. Not massive, but complex because of classification boundaries and air-gap constraints.

### How to explain to Andy:
"Multi-tenant means multiple teams share the same cluster but are isolated — each gets a namespace, RBAC, network policies, Vault policies, and resource quotas. At VivSoft, JAWS, CyberAlly, and OpenCTI all deploy to the same production cluster but can't see each other's resources. Crossplane automates the provisioning — a team writes five lines of YAML declaring their needs, the pipeline creates everything. Without this, each team would need their own cluster — expensive and operationally heavy."

---

## 2. How Bundles Get From Connected to Air-Gapped — The Full Story

### The Technical Story (use this)

At VivSoft, we DIDN'T use a physical diode. The air-gap was within AWS GovCloud — logically separated, not physically. Here's how it actually worked:

```
CONNECTED SIDE (has internet)              AIR-GAPPED SIDE (no internet)
─────────────────────────                  ────────────────────────────

GitLab CI runner                           EKS cluster in private VPC
  (EC2 instance with internet)               (no internet access at all)
         │                                          ▲
         │ 1. Pipeline builds                       │
         │    Zarf packages                         │
         │    (pulls from Iron Bank,                │
         │     scans with Trivy,                    │
         │     bundles into .tar.zst)               │
         │                                          │
         ▼                                          │
    S3 Bucket                                       │
    (artifact storage)  ─────────────────────>      │
         │                    3. Pipeline on        │
         │                    air-gapped side        │
         │                    PULLS from S3          │
         │                    (via VPC endpoint —    │
         │                     private, no internet) │
         │                                          │
    2. Bundle uploaded                     4. UDS deploys bundle
       to S3 via pipeline                    to EKS cluster
```

**The key detail: S3 is the bridge.** Both sides can access S3 — the connected side pushes bundles via internet, the air-gapped side pulls via VPC endpoint (private, no internet traversal). The VPC endpoint lets the cluster access S3 WITHOUT going through the internet — it's a private connection within AWS's backbone network.

**Why this is "air-gapped":**
- The EKS cluster has NO internet access — no NAT gateway, no public IP
- It can ONLY reach AWS services (S3, ECR, STS) via VPC endpoints — private paths that never touch the public internet
- Container images don't come from Docker Hub — they come from ECR (mirrored from Iron Bank on the connected side)
- Zarf bundles don't come from GitHub — they come from S3
- The cluster can't call out to anything except pre-approved AWS endpoints

**It's not a physical diode like Anduril uses.** It's LOGICAL air-gap: the cluster is isolated by network configuration (no routes to internet), not by hardware. For SIPRNET (actual classified), there may be additional physical controls, but the GovCloud setup relies on VPC-level isolation + VPC endpoints.

### How to explain to Andy:
"The build side has internet — GitLab CI pulls from Iron Bank, scans, bundles with Zarf, pushes to S3. The cluster side has zero internet — private VPC, no NAT, no public routes. It reaches S3 through a VPC endpoint — a private path within AWS, never touches the internet. The pipeline on the cluster side pulls bundles from S3 via the endpoint, UDS deploys them. S3 is the bridge between connected and disconnected. For SIPRNET, the physical transfer mechanism may differ — courier, secure media — but the pattern is the same: build once on the connected side, transfer the bundle, deploy on the isolated side."

### If Andy asks "how is that different from what we do?"
"Your setup uses a physical diode — hardware-enforced one-way transfer. Same concept, different mechanism. Instead of S3 + VPC endpoints, you'd push bundles to the diode input on the connected side, they flow through the hardware to the classified side, and a receiver process unpacks into Nexus. The bundle format and deploy process stay the same — just the TRANSFER layer changes. Zarf bundles don't care how they got there; they just deploy."

---

## 3. Kapitan vs Kustomize — Deep Dive

### The Problem Both Solve

You have ONE application (say, Vault) that deploys to MANY environments (dev, staging, prod, siprnet). Each environment needs slightly different config: different database host, different replica count, different domain name. How do you manage this without maintaining separate YAML files for every environment?

### Kustomize — The Patching Approach

Kustomize starts with a BASE — the full set of K8s manifests — and applies PATCHES per environment.

```
base/
├── deployment.yaml        # Vault with 1 replica, default image
├── service.yaml
└── kustomization.yaml     # "these are my base resources"

overlays/
├── dev/
│   ├── kustomization.yaml # "use base, apply these patches"
│   └── patch-replicas.yaml # "change replicas from 1 to 1"
├── staging/
│   ├── kustomization.yaml
│   └── patch-replicas.yaml # "change replicas from 1 to 2"
└── prod/
    ├── kustomization.yaml
    ├── patch-replicas.yaml # "change replicas from 1 to 3"
    └── patch-resources.yaml # "change memory limit to 8Gi"
```

**How it works:** You write the full manifest once (base), then each environment PATCHES specific fields. "Take the base Deployment, but change replicas to 3 and memory to 8Gi."

**The problem at scale:** When you have 8+ environments across 2 classification levels, each needing different database hosts, different domains, different security policies, different image registries — the patches stack up. Each environment has 5-10 patch files. Change the base structure? Every patch might break. It's death by a thousand patches.

### Kapitan — The Inheritance Approach

Kapitan starts with CLASSES (shared defaults) and TARGETS (per-environment declarations). No patching — pure variable substitution via inheritance.

```
inventory/
├── classes/
│   ├── defaults/
│   │   ├── bb-vault.yml          # "Vault should use Raft HA, port 8200, TLS"
│   │   ├── bb-keycloak.yml       # "Keycloak needs RDS, CAC auth"
│   │   └── bb-monitoring.yml     # "Prometheus + Grafana + Loki"
│   ├── environments/
│   │   ├── dev.yml               # "dev AWS account, dev domain, small resources"
│   │   └── prod.yml              # "prod AWS account, prod domain, large resources"
│   └── jcrse-common.yml          # AGGREGATOR: includes 20+ default classes
│
├── targets/
│   ├── dev-cluster.yml           # 5 LINES: "I'm dev. Use jcrse-common + dev env."
│   └── prod-cluster.yml          # 5 LINES: "I'm prod. Use jcrse-common + prod env."
│
└── templates/
    └── deploy-vault.sh.j2        # "deploy Vault with {{ vault_port }}"
```

**How it works:**

1. A TARGET file (5 lines) says: "I am the dev cluster. Include the jcrse-common class and the dev environment class."

2. Kapitan resolves the classes: jcrse-common includes bb-vault, bb-keycloak, bb-monitoring — 20+ default classes. The dev environment sets the AWS account, domain, resource sizes.

3. All variables merge together (later classes override earlier). The target might override one specific value.

4. Kapitan renders the templates: `deploy-vault.sh.j2` gets `{{ vault_port }}` → `8200` from the bb-vault class.

5. Output: a fully compiled set of scripts and configs for that specific environment. Ready to deploy.

**Why inheritance beats patching:**

| Scenario | Kustomize (patching) | Kapitan (inheritance) |
|----------|---------------------|----------------------|
| Add new environment | Copy overlay dir, write 5-10 patch files | Write 5-line target file referencing existing classes |
| Change Vault port globally | Change base, verify no patch conflicts | Change `bb-vault.yml`, every target auto-inherits |
| Add a new service | Add to base, add patches per overlay | Add new class (`bb-new-service.yml`), add to `jcrse-common.yml` aggregator |
| Environment-specific override | Write a new patch file | Add one line to the target: `vault_port: 8201` |
| 8+ environments | 8 overlay directories × 5-10 patches each = 40-80 files | 8 target files × 5 lines each = 40 lines total |

**The killer difference:** With Kustomize, if you change the base Deployment structure (say, add a new container), every overlay's patches that touch the Deployment might break. With Kapitan, you change the template once and every target that compiles against it gets the change — no patch conflicts.

### Concrete Example: How ONE Template Becomes 8 Outputs

**The template (ONE file — used by all environments):**
```
# templates/deploy-vault.sh.j2
#!/bin/bash
echo "Deploying Vault to {{ env_name }}"
helm upgrade vault ./charts/vault \
  --set server.ha.replicas={{ vault_replicas }} \
  --set server.resources.limits.memory={{ vault_memory }} \
  --set server.dataStorage.size={{ vault_storage }} \
  --set global.tlsDisable={{ tls_disable }} \
  --set server.image.repository={{ vault_image }} \
  --namespace vault
```

The `{{ }}` parts are VARIABLES — no values yet. Kapitan fills them in.

**The class (shared defaults — inherited by everyone):**
```yaml
# classes/defaults/bb-vault.yml
parameters:
  vault_replicas: 1
  vault_memory: "2Gi"
  vault_storage: "10Gi"
  tls_disable: false
  vault_image: "registry.local/vault:1.15"
```

**Environment classes (override specific values):**
```yaml
# classes/environments/dev.yml
parameters:
  env_name: "dev"
  vault_replicas: 1
  vault_memory: "1Gi"       # smaller for dev
  tls_disable: true          # skip TLS in dev for speed
```

```yaml
# classes/environments/prod.yml
parameters:
  env_name: "production"
  vault_replicas: 3          # HA for production
  vault_memory: "8Gi"        # more memory
  vault_storage: "50Gi"      # more data
```

```yaml
# classes/environments/siprnet-prod.yml
parameters:
  env_name: "siprnet-production"
  vault_replicas: 3
  vault_memory: "8Gi"
  vault_storage: "50Gi"
  vault_image: "ironbank-mirror.siprnet/vault:1.15"  # DIFFERENT registry on classified
```

**Target files (5 lines each — "I am THIS environment"):**
```yaml
# targets/dev-cluster.yml
classes:
  - defaults.bb-vault          # inherit Vault defaults
  - environments.dev            # override with dev values
```

```yaml
# targets/prod-cluster.yml
classes:
  - defaults.bb-vault
  - environments.prod
```

```yaml
# targets/siprnet-prod.yml
classes:
  - defaults.bb-vault
  - environments.siprnet-prod
```

**Run `kapitan compile` — what comes out:**

For dev-cluster:
```bash
#!/bin/bash
echo "Deploying Vault to dev"
helm upgrade vault ./charts/vault \
  --set server.ha.replicas=1 \
  --set server.resources.limits.memory=1Gi \
  --set server.dataStorage.size=10Gi \
  --set global.tlsDisable=true \
  --set server.image.repository=registry.local/vault:1.15 \
  --namespace vault
```

For prod-cluster:
```bash
#!/bin/bash
echo "Deploying Vault to production"
helm upgrade vault ./charts/vault \
  --set server.ha.replicas=3 \
  --set server.resources.limits.memory=8Gi \
  --set server.dataStorage.size=50Gi \
  --set global.tlsDisable=false \
  --set server.image.repository=registry.local/vault:1.15 \
  --namespace vault
```

For siprnet-prod:
```bash
#!/bin/bash
echo "Deploying Vault to siprnet-production"
helm upgrade vault ./charts/vault \
  --set server.ha.replicas=3 \
  --set server.resources.limits.memory=8Gi \
  --set server.dataStorage.size=50Gi \
  --set global.tlsDisable=false \
  --set server.image.repository=ironbank-mirror.siprnet/vault:1.15 \
  --namespace vault
```

**ONE template → THREE different outputs.** Same structure, different values. Now multiply by 8 environments × 20+ services = 160+ compiled scripts from ONE set of templates.

**The power:** Need to change Vault's default storage across ALL environments?
1. Edit `classes/defaults/bb-vault.yml` — change `vault_storage: "20Gi"`
2. Run `kapitan compile` — all 8 targets recompile with the new value
3. Done. ONE file change, ALL environments updated.

**With Kustomize:** Change the base, then check each of the 8 overlay directories for patch conflicts, fix broken patches, apply per environment. At 8 environments, that's painful. At 20 services × 8 environments, it's unmanageable.

### How to explain to Andy:
"Kustomize patches a base: 'take this YAML, change these fields per environment.' Works fine for 2-3 environments. At 8+ environments across classification levels, you end up with dozens of patch files that can conflict when the base changes. Kapitan uses inheritance: shared defaults in classes, 5-line target files per environment. Change a default once, every target picks it up. No patch conflicts, no file explosion. For JCRS-E with 8 environments across 2 classification levels, inheritance was the only sane approach."

---

## 3b. What Kapitan Actually Configures — And Why Not Just Helm or Kustomize

### "Can't Helm do the same thing? Or Kustomize?"

**Kapitan is NOT configuring K8s manifests.** It's a GENERAL-PURPOSE template compiler that sits ABOVE Helm, Terraform, and everything else. It generates the INPUTS that feed into those tools.

**The tool hierarchy at VivSoft:**
```
Kapitan (generates scripts + Helm values + Crossplane YAML + pipeline config)
    ↓ outputs
Shell scripts that call:
    ↓
Zarf / UDS (bundles + deploys packages)
    ↓ which contain
Helm charts (template K8s manifests with the values Kapitan generated)
    ↓ which render
K8s manifests (Deployments, Services, etc.)
    ↓ applied to
Kubernetes cluster
```

**ONE Kapitan class (`bb-vault.yml`) generates:**
1. A Helm values override for Vault's chart (what replicas, memory, storage to use)
2. A shell script that calls `uds deploy` with the right bundle version
3. A Crossplane claim YAML for Vault's RDS backend database
4. Pipeline variables for the toggle-based GitLab CI

**Helm alone can't do that** — Helm only templates K8s manifests. It can't generate shell scripts, Terraform variables, Crossplane claims, or pipeline config. Kapitan crosses tool boundaries.

### "But Helm has values files per environment"

Yes — `helm install -f values-dev.yaml` vs `helm install -f values-prod.yaml`. That works for K8s manifests. But at VivSoft, a deploy involves MORE than just Helm:

| What needs per-environment config | Can Helm do it? | Can Kapitan do it? |
|----------------------------------|----------------|-------------------|
| K8s manifest values (replicas, image, memory) | YES | YES (generates the Helm values file) |
| Shell script for air-gap deployment | NO | YES |
| Crossplane claim YAML for RDS provisioning | NO (not a Helm resource) | YES |
| Pipeline toggle variables for GitLab CI | NO | YES |
| Terraform variable overrides | NO | YES |

Kapitan manages variables ACROSS all these tools from one place. One class defines Vault settings that feed into Helm AND scripts AND Crossplane AND the pipeline. Helm can't do that.

### "Can Kustomize propagate changes?"

Yes — Kustomize CAN propagate base changes to overlays. The problem isn't propagation, it's how patches reference things. Kustomize patches use STRUCTURAL PATHS like `/spec/containers/0/resources`. Kapitan uses NAMED VARIABLES like `{{ vault_memory }}`.

Structural paths break when the YAML structure changes (add a sidecar, index shifts, wrong container gets patched). Named variables don't care about structure — they fill in wherever the template references them.

Plus, Kustomize only patches K8s manifests — same limitation as Helm. Can't generate scripts, Terraform vars, or Crossplane claims.

### When to use each:

| Tool | What it does | When to use it |
|------|-------------|---------------|
| **Helm** | Templates K8s manifests with values.yaml | Packaging and deploying ONE service. Standard K8s. |
| **Kustomize** | Patches base K8s manifests per environment | 2-3 environments, simple overrides. Built into kubectl. |
| **Kapitan** | Compiles ANY template (scripts, values, configs) with class inheritance | Many environments (8+), MULTIPLE tools (Helm + scripts + Terraform + Crossplane). |

**At VivSoft:** Kapitan generates → Helm values + deploy scripts + Crossplane YAML. Helm templates → K8s manifests inside Zarf packages. Kustomize not used — Kapitan replaced it.

### How to explain to Andy:
"Helm templates K8s manifests — great for packaging services. But we needed to manage variables across more than just K8s: shell scripts for air-gap deployment, Crossplane claims for self-service, pipeline toggles for CI/CD. Kapitan sits above Helm — it generates the Helm values, the deploy scripts, and the Crossplane YAML from one set of shared variables. One class change propagates to every tool, every environment. Helm alone can't cross that tool boundary."

---

## 4. What "Stacking Patches" Means (Why It's Bad)

Imagine this Kustomize scenario:

**Base deployment.yaml:**
```yaml
replicas: 1
image: vault:1.15
resources:
  limits:
    memory: 2Gi
```

**Overlay for staging:**
```yaml
# patch-staging.yaml
- op: replace
  path: /spec/replicas
  value: 2
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/memory
  value: 4Gi
```

**Overlay for prod:**
```yaml
# patch-prod.yaml
- op: replace
  path: /spec/replicas
  value: 3
- op: replace
  path: /spec/template/spec/containers/0/resources/limits/memory
  value: 8Gi
- op: add
  path: /spec/template/spec/containers/0/env/-
  value:
    name: VAULT_HA_ENABLED
    value: "true"
```

Now you change the base: add a SIDECAR container. The patch paths (`/spec/template/spec/containers/0/...`) might now point to the wrong container because the index shifted. Every overlay breaks. That's "stacking patches" — each layer of patches depends on the exact structure of the layer below. Change the structure, patches crumble.

With Kapitan: there are no patches. There's a template that says `{{ vault_replicas }}` and a class that says `vault_replicas: 3`. Add a sidecar? Change the template. The variable references don't care about structural indexes.

---

## 5. Multi-Tenancy Size — "How Big Is Your Cluster?"

If Andy asks "how big was the cluster?" — here's what to say:

**JCRS-E production cluster:**
- **20+ services** deployed (Istio, Vault, Keycloak, ArgoCD, monitoring, plus mission apps)
- **4 mission programs** deploying workloads (JAWS, CyberAlly, OpenCTI, internal)
- **~30-50 pods** running at any time (not thousands — this is internal tooling, not public web scale)
- **3-5 worker nodes** (plus 3 control plane for HA)
- **~10 namespaces** (one per tenant team, plus system namespaces)

It's not massive — it's COMPLEX. The scale isn't in pod count; it's in:
- Classification boundaries (2 levels)
- Air-gap packaging (every image pre-bundled)
- Environment count (8 environments from one set of templates)
- Compliance requirements (FedRAMP High, DISA STIGs)

"Big" in this context means big in complexity, not in pod count. If Andy asks "how many pods?" — be honest: "thirty to fifty in production, but the complexity was in the air-gap packaging, classification boundaries, and multi-environment templating, not raw scale."

---

## 6. VPC Endpoints — How the Air-Gap Side Reaches S3

This is the missing piece of the transfer story. The air-gapped cluster has NO internet but CAN reach S3. How?

**VPC Endpoint = a private door from your VPC directly to an AWS service, without going through the internet.**

```
WITHOUT VPC Endpoint:
  Pod → NAT Gateway → Internet → S3
  (needs internet access — BLOCKED in air-gap)

WITH VPC Endpoint:
  Pod → VPC Endpoint → S3
  (stays within AWS private network — NO internet needed)
```

There are two types:
- **Gateway Endpoint** (free): for S3 and DynamoDB only. Adds a route to your VPC route table. Traffic stays on AWS backbone.
- **Interface Endpoint** (costs ~$8/month per AZ): for everything else (ECR, STS, Secrets Manager). Creates an ENI (network interface) in your subnet with a private IP.

For JCRS-E:
- Gateway endpoint for S3 → pipeline pulls Zarf bundles
- Interface endpoints for ECR → containerd pulls images
- Interface endpoint for STS → IRSA token exchange
- Interface endpoint for Secrets Manager → External Secrets reads credentials

"Air-gapped" in GovCloud means: no NAT gateway, no internet gateway, no public IPs. But VPC endpoints give private access to specific AWS services. The cluster is isolated from the INTERNET but can still reach S3, ECR, and STS through these private doors. That's how bundles transfer — S3 is reachable from both the connected side (via internet) and the air-gapped side (via VPC endpoint).

---

## 7. "Why Not Use Official Helm Charts for Jira/Bitbucket?"

Andy might ask: "Why write custom charts? Didn't Atlassian have Helm charts?"

**Answer:** "Three reasons. First, Atlassian didn't have official Helm charts when we did the migration — they came later. Second, even if they existed, we couldn't pull from a public Helm repository — air-gapped, everything from internal sources. Third, the existing Docker Compose files had years of accumulated configuration: custom plugins, SSO integration with Crowd, proxy settings, database connection tuning, specific volume mounts. An off-the-shelf chart wouldn't know about any of that. I wrote custom charts that TRANSLATED the existing proven config into Helm templates — same logic, new format. The images came from our internal registry, mirrored from the vendor."

---

## 8. The 8 Environments at VivSoft — What Are They?

| # | Environment | Level | Lifetime | Purpose |
|---|-------------|-------|----------|---------|
| 1 | Shared Dev | Unclassified | Persistent | Always running — developers test daily |
| 2-3 | Ephemeral Dev (x2+) | Unclassified | 8-hour TTL | Per-developer/feature — auto-destroys |
| 4 | Staging Left | Unclassified | Persistent | Pre-production full-stack validation |
| 5 | Staging Right | Unclassified | Persistent | Alternate staging — parallel release testing |
| 6 | Production | Unclassified | Persistent | Live — mission app teams use daily |
| 7 | SIPRNET Staging | Classified | Persistent | Pre-production for classified workloads |
| 8 | SIPRNET Production | Classified | Persistent | Live classified — USCYBERCOM operational |

**Why left AND right staging?** Test two releases in parallel. Release A on left, release B on right — no blocking.

**Why ephemerals?** Full production-equivalent cluster for 8 hours. Test, auto-destroy. No orphan resources.

**Why this matters:** All 8 environments from the SAME Kapitan templates — just different target files. One change propagates to all 8.

---

## 9. registries.yaml — Node-Level, Not Just Bootstrap

**Misconception:** registries.yaml only matters during RKE2 bootstrap.

**Reality:** registries.yaml configures **containerd** — the container runtime on the node. Affects ALL image pulls on that node, forever.

```
Pod says: image: docker.io/nginx:latest
containerd reads registries.yaml: "docker.io mirrors to ecr.local"
containerd pulls from ecr.local instead — PRIVATE, no internet
```

- Applies to EVERY pod on the node — bootstrap, ArgoCD, Istio, your apps, everything
- Per-NODE, not per-pod. Set once, all containers redirect.
- Pod spec doesn't change — devs don't know it's air-gapped. containerd handles it transparently.
- Without it, you'd rewrite every image reference in every manifest — hundreds of changes.

---

## 10. Image Pull Policies

| Policy | What it does | When to use |
|--------|-------------|-------------|
| **IfNotPresent** | Already cached on node? → use it. Not cached? → pull. | Default for tagged images. Air-gap safe: first pull from mirror, then cached. |
| **Always** | Always check registry, even if cached. | For `:latest`. Risky in air-gap if mirror unreachable. |
| **Never** | Never pull. Use only cached. If missing → pod fails. | Pre-loaded images (Zarf pushes before pods start). |

`IfNotPresent` is the safe air-gap default. Bundle pushes images to mirror → first pod pull caches on node → subsequent pods use cache. Fast, no network after first pull.

---

## Quick Test — Can You Explain Each Concept?

Close this file and answer these aloud. If you can't, re-read the section.

1. What is multi-tenancy? How are tenants isolated? (namespace, RBAC, network policies, Vault policies, quotas)
2. How do Zarf bundles get from connected to air-gapped? (build on connected → S3 → VPC endpoint → cluster pulls)
3. What's the difference between Kustomize and Kapitan? (patches vs inheritance — give the "change Vault port" example)
4. What's a VPC endpoint? (private door to AWS service, no internet needed)
5. How big was your cluster? (20+ services, 30-50 pods, 4 programs — complex, not massive)
6. Did you use a diode? (No — S3 + VPC endpoints. Anduril uses diode. Same concept, different transfer.)
7. Why custom Helm charts instead of official ones? (Atlassian didn't have them, air-gapped, years of custom config in Compose files)
8. What are the 8 environments? (shared dev, ephemerals, staging left/right, production, SIPRNET staging/prod)
9. Does registries.yaml only apply during bootstrap? (No — it configures containerd on the NODE. ALL pods, forever.)
10. What does pullPolicy: IfNotPresent do? (Use cached if available, pull if not. Safe default for air-gap.)
