# Tradeoff Questions, Motivations & Architectural Decisions

## Instructions
Pick 5 random questions each day. Answer each one aloud in 60-90 seconds. No notes.
The **Motivations** sections are critical — they show you didn't just implement tickets, you identified problems, designed solutions, and drove architecture decisions.

---

## Motivations: Why I Migrated IBM from Docker/Swarm to Helm/K8s

> **Use when:** Andy asks "why did you migrate?", "what was wrong with the old system?", "what drove that decision?"

### The 5 Pains (memorize these — they're your ammunition)

1. **Manual promotion** — deploying meant SSH to the server, git pull, run `make deploy`. Same process for test AND production. No automation, no pipeline, no gates. Every release depended on one person running commands in the right order.

2. **No atomic rollback** — Swarm had no revision history. If a deploy broke production, you had to find the right Git commit, revert, re-run make, and hope Gomplate produced the same output. No `helm rollback` equivalent. Rollback was a gamble, not a command.

3. **Config drift between deploys** — between deploying to test and deploying to production, someone might SSH in and change a config directly. No detection, no alerting. What was running could silently diverge from what was in Git.

4. **No health check gating** — Swarm's rolling update was basic: replace containers, hope they start. No readiness probes, no liveness checks gating the rollout. If the new container crashed, users saw errors until someone manually noticed and rolled back.

5. **Release prep took hours** — manually checking each of 9 services, verifying configs matched, running make targets in order, smoke testing each web UI. Helm reduced this by forty percent because one command deployed everything with known-good configs and automatic rollback on failure.

### The Decision Drivers (why K8s + Helm, not just "better scripts")

| Alternative considered | Why I rejected it |
|----------------------|-------------------|
| Better Makefiles + Docker Compose | Doesn't solve rollback, drift detection, or health check gating. Just polishes the same fragile chain. |
| Docker Swarm with better orchestration | Swarm was EOL-trending. No community, limited features. K8s was the industry standard and where hiring was moving. |
| Ansible for deployment instead of Make | Ansible could replace Make for orchestration, but still doesn't give you declarative state management, rollback, or drift detection. |
| Kustomize instead of Helm | Kustomize patches YAML but doesn't package it. For 9 services with shared patterns, Helm's templating and library charts were more maintainable. |

### How to Explain the Motivation to Andy
"The pain wasn't that things were broken — the platform worked. The pain was that every release was a multi-hour manual process with no safety net. No rollback, no drift detection, no health check gating. Six hundred engineers depended on these tools, and one bad deploy could take everything down. I evaluated alternatives — better scripts, Ansible, Kustomize — but the root cause was that we had no declarative state management. Helm on Kubernetes gave us that: versioned releases, one-command rollback, health checks gating every rollout, and a CI/CD pipeline for automated promotion."

---

## Motivations: Why I Built the Nightwatch RKE2 Platform (NTConcepts)

> **Use when:** Andy asks about RKE2 decisions, why you built a K8s cluster for ML, what drove the architecture

### The 3 Pains That Drove It

1. **Manual GPU provisioning** — data scientists had to request GPU instances through tickets. Wait times were days. When they got an instance, they'd configure it manually — install CUDA, set up Jupyter, mount storage. If the instance crashed, start over.

2. **No reproducibility** — each data scientist's environment was a snowflake. Different CUDA versions, different Python packages, different notebook configs. "It works on my machine" was the daily complaint. Models trained on one setup couldn't reproduce results on another.

3. **No cost control** — GPU instances (g4dn, A100) are expensive. Scientists launched them and forgot to stop them. No auto-shutdown, no utilization monitoring. Tens of thousands wasted per month on idle GPUs.

### The Decisions I Made (and why)

| Decision | Why |
|----------|-----|
| RKE2 over EKS | On-prem / classified environment. No cloud API access from inside the cluster. RKE2 bundles everything — one binary, embedded etcd, runs disconnected. FIPS and CIS hardened. |
| Kubeflow for ML platform | Industry-standard ML platform on K8s. Provides notebooks, pipelines, model serving. Self-service for data scientists — no tickets for GPU access. |
| Cluster Autoscaler for GPU nodes | Automatically provisions GPU nodes when training jobs are pending, scales down when idle. Eliminated the "forgot to stop my instance" problem. |
| ArgoCD over manual kubectl | GitOps — all manifests in Git, ArgoCD syncs. No one SSHs in and changes things. Drift is detected and reverted automatically. |
| NVIDIA GPU Operator | Auto-installs GPU drivers on new nodes. No manual CUDA setup. New GPU node joins, operator detects hardware, installs driver, pod schedules. |
| Keycloak + oauth2-proxy for auth | Enterprise SSO. Data scientists login once, get access to notebooks, pipelines, dashboards. No credential management per service. |
| External Secrets Operator → Secrets Manager | Keeps database passwords and API keys in AWS Secrets Manager, syncs to K8s Secrets automatically. No secrets in Git, no manual rotation. |

### How to Explain the Motivation to Andy
"Twelve data scientists were waiting days for GPU access through tickets, configuring environments manually, and leaving expensive instances running idle. I built a self-service platform on RKE2 where they launch a notebook, select a GPU profile, and the platform handles the rest — autoscaling, driver installation, storage mounting. Tripled throughput because they went from waiting to working. And the Cluster Autoscaler with idle-shutdown automation cut GPU costs dramatically — nodes only exist during active training."

---

## Motivations: Why I Re-Architected JCRS-E at VivSoft

> **Use when:** Asked about the VivSoft platform migration, why multi-repo, why Kapitan, why air-gap-first

### The 4 Pains I Inherited (TAURUS Legacy)

1. **Monolithic repo** — Terraform, flat .env files, Kustomize overlays, Big Bang YAML, and GitLab CI all in one repository. Any change to anything touched the entire repo. No separation of concerns.

2. **No air-gap capability** — the platform had zero ability to deploy to disconnected networks. SIPRNET deployment was a hard requirement from the JCWA consolidation mandate, and the existing architecture couldn't support it.

3. **No config inheritance** — each environment had its own set of manually maintained config files. Adding a new environment meant copy-pasting hundreds of lines and changing values by hand. Drift between environments was constant.

4. **Classification boundary violations** — configs and infrastructure code in the same repo meant the entire repo got classified when touching SIPRNET. Couldn't iterate on unclassified side without a review process. Slowed everything down.

### The Decisions I Made

| Decision | Why | Tradeoff accepted |
|----------|-----|-------------------|
| Multi-repo split (CaC / IaC / packages / pipeline) | Classification boundary safety — CaC can be classified independently from IaC | More repos = more context switching, more coordination |
| Kapitan for config management | Class inheritance — one template compiles to many environments. New env = 5 lines referencing shared defaults | Learning curve for team, niche tool |
| Zarf for air-gap packaging | Declarative, versioned, content-addressed bundles. Build once, deploy to any disconnected cluster | Extra packaging step in the pipeline, bundle size management |
| UDS for orchestration | Handles dependency ordering (CRDs before resources, mesh before services). Decouples build from deploy | Another tool to learn, another layer of abstraction |
| Crossplane for self-service | Teams declare infrastructure needs as K8s claims — platform reconciles. Scales tenancy without platform team intervention | Complex XRD/Composition setup, TLS cert mounting for Vault provider |
| Toggle-based pipeline stages | Deploy only what changed — skip infra if only config changed. Saves 45+ minutes per run | More complex pipeline logic, toggle management |

### How to Explain the Motivation to Andy
"I inherited a monolithic platform that had no air-gap capability, no config inheritance, and classification boundary issues. The JCWA mandate required deploying across classification levels — NIPRNET and SIPRNET. The existing architecture couldn't do it. I split the repos by concern, introduced Kapitan for config inheritance so a new environment is five lines instead of hundreds, and built the air-gap packaging pipeline with Zarf. The result was a platform that deploys twenty-plus services across eight environments at two classification levels, and mission app teams onboard in hours instead of weeks."

---

## Motivations: Why I Chaired the Cloud Governance Board (NTConcepts)

> **Use when:** Asked about leadership, influencing without authority, cost management

### The 3 Pains

1. **Uncontrolled spend** — sixty cloud accounts (thirty AWS, thirty GCP) with no centralized visibility. Spend growing fifteen to twenty percent quarter over quarter. Nobody knew who was spending what.

2. **Aging security findings** — critical and high CVEs open for months with no owner. No accountability, no remediation cadence, no one tracking closure.

3. **No governance mechanism** — no tagging standards, no account lifecycle policies, no spend targets. Each team ran their account independently with zero coordination.

### The Decisions I Made

| Decision | Why |
|----------|-----|
| CUR ingestion pipeline first | You can't govern what you can't see. Built consolidated spend visibility before proposing any cuts. Data first, then decisions. |
| Monthly board with VP-level stakeholders | Created accountability at the executive level. Spend trends and security findings presented monthly — can't ignore what's on the slide. |
| Mandatory tagging in Terraform modules | Enforced at the code level, not by policy memo. You literally can't provision resources without tags. No exceptions, no volunteers. |
| FinOps automation (idle-shutdown, rightsizing) | Automated the easy wins — GPU instances left running, oversized Savings Plans. Saved tens of thousands per month without asking anyone to change behavior. |
| Tied security findings to governance cadence | Same board, same meeting. "Here's your spend AND here's your open findings." Security becomes part of operations, not a separate audit. |

### How to Explain the Motivation to Andy
"Nobody owned the cloud spend across sixty accounts, and critical security findings were aging out with no owner. I didn't wait for someone to assign it — I proposed a governance board, built the CUR pipeline to create visibility, and started chairing monthly meetings with VP Finance, VP Engineering, and the Head of IT Security. Led with data: here's what we're spending, here's where it's wasted, here's the plan. Cut spend thirty percent and drove a hundred percent closure on critical and high findings. The board continued after I left because the process was self-sustaining."

---

## Infrastructure Tradeoffs

### 1. "Why RKE2 over EKS or K3s for air-gap?"
- RKE2: bundled binaries, FIPS support, CIS hardened by default, no cloud dependency
- EKS: managed control plane, but requires internet for API calls, harder to air-gap
- K3s: lightweight, good for edge, but not FIPS compliant, less enterprise features
- **For Anduril:** RKE2 is the right choice for on-prem air-gap because it's self-contained

### 2. "Why Ansible over Terraform on the air-gap side?"
- Ansible: push-based (no state server needed), works offline, agentless (just SSH)
- Terraform: needs state file storage, needs provider plugins (which need internet to download)
- On air-gap: Ansible playbooks are self-contained YAML — transfer the playbook, run it
- Terraform needs: provider binaries, state backend, lock mechanism — all harder offline
- **Note:** Terraform is great for cloud infra (VPCs, EKS). Ansible is great for host config.

### 3. "Why separate IaC from CaC repos?"
- Classification boundary: if they share a repo, the whole repo gets classified on SIPRNET
- Prevents config values from leaking across classification levels
- Allows independent release cadence: config changes don't gate on infra changes
- Tradeoff: more repos = more context switching. Worth it for security.

### 4. "Why Zarf over manual tarballs?"
- Zarf: declarative manifest, versioned, content-addressed, includes validation
- Tarballs: no versioning, no validation, no dependency ordering, manual
- Zarf packages are self-contained: images + charts + manifests in one archive
- UDS handles deployment ordering: core services before enterprise services
- **Key:** hash verification catches corruption or tampering during transfer

### 5. "Why ArgoCD over FluxCD (or vice versa)?"
- ArgoCD: UI for visibility, Application CRD, good for operator visibility
- FluxCD: no UI, Kubernetes-native (HelmRelease CRDs), lighter weight
- At VivSoft: FluxCD for inner loop (Big Bang generates FluxCD resources natively), ArgoCD for mission app delivery
- **For Anduril:** depends on whether they want operator visibility (ArgoCD) or minimal footprint (Flux)

### 6. "Why Crossplane over Terraform for in-cluster resource management?"
- Crossplane: Kubernetes-native, continuously reconciles (if someone deletes a resource, it recreates it)
- Terraform: run-and-done, no continuous reconciliation
- Crossplane fits K8s workflow: declare a claim, platform reconciles
- Terraform fits infra provisioning: plan/apply workflow for VPCs, clusters
- **Use both:** Terraform for base infra, Crossplane for in-cluster self-service

## Operational Tradeoffs

### 7. "Toggle-based pipeline vs. separate pipelines per component?"
- Toggle: single pipeline, deployment order guaranteed, one view of state
- Separate: each component has its own pipeline, more flexible, but no ordering guarantee
- Toggle wins when components have dependencies (core must deploy before enterprise)

### 8. "Ephemeral clusters vs. long-lived dev environments?"
- Ephemeral: clean every time, no state drift, auto-destroy after TTL (8 hours)
- Long-lived: faster to iterate (no wait for provisioning), but drift accumulates
- Best: ephemeral for feature dev, persistent for staging/production

### 9. "Monorepo vs. multi-repo for platform code?"
- Monorepo: one place for everything, easier discovery, atomic commits
- Multi-repo: separation of concerns, classification boundaries, independent release
- Multi-repo won at VivSoft because of classification requirements
- Monorepo might be fine if you're single-classification

### 10. "Hardened custom AMIs vs. runtime hardening?"
- Custom AMIs (Packer + Ansible + OSCAP): hardened at build time, consistent, auditable
- Runtime hardening: apply at boot, slower, risk of drift if hardening fails
- **Always bake it in:** AMI is the baseline, runtime only for dynamic config
- STIG compliance should be measured at build time, not hoped for at runtime

## Air-Gap Specific

### 11. "Diode vs. USB for air-gap transfers?"
- Diode: automated, one-way network device, higher throughput, auditable
- USB: manual, requires physical security, human error risk, but works everywhere
- Diode is better when available — automate the transfer pipeline
- USB for highest classification or when no diode exists

### 12. "How do you handle package updates on air-gap networks?"
- Manifest-driven: maintain a list of all packages + versions
- Pipeline on connected side pulls, scans, bundles on schedule (weekly or on-demand)
- Transfer via diode
- On air-gap side: unpack, validate checksums, update local repos
- Old versions stay in registry for rollback safety

### 13. "Content-addressable storage vs. version-tagged transfers?"
- Content-addressed (hash-based): only transfer what actually changed
- Version-tagged: transfer the full bundle every time
- Content-addressed saves bandwidth on slow diodes
- But version-tagged is simpler and more auditable ("I deployed bundle v2.3.1")
- Best: tag versions AND validate with content hashes

## Security

### 14. "How do you enforce image provenance in K8s?"
- Kyverno admission policy: blocks any image not from Iron Bank / approved registry
- Enforced at API server level — kubectl apply is rejected before pod is created
- Combined with Trivy scanning in the pipeline — images are scanned before bundling
- Defense in depth: scan at build, enforce at admission, monitor at runtime (Neuvector)

### 15. "How do you handle secrets rotation?"
- Vault handles rotation via TTLs on dynamic secrets
- Static secrets: Vault audit log + alert on age
- Certificate rotation: Cert-Manager with automatic renewal
- Application restart: Vault Agent sidecar injects fresh secrets without pod restart
- Never store secrets in Git, env vars, or ConfigMaps
