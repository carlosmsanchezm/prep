# Architecture Deep Dive — Coaching Guide

> **How to use:** Read this before each day's architecture practice. It teaches you HOW to present each system — what to say first, how to draw it, how to handle follow-ups. After practicing with this guide, check your work against the real answer files (vivsoft-answers.md, ntconcepts-answers.md).

---

## General Techniques

### The "Zoom Out Before Zoom In" Technique

ALWAYS start broad, then go deep when asked. Never lead with implementation details.

**BAD start:** "So I used Kapitan with Jinja2 class inheritance and we have 20+ default classes in the inventory..."

**GOOD start:** "I built a multi-tenant Kubernetes platform for DoD cyber operations on AWS GovCloud. It deploys 20+ services across air-gapped environments. Let me walk you through the layers."

Then draw. The interviewer will say "tell me more about X" — that's your cue to zoom in on that specific layer.

### The 5-3-1 Rule

- **Know 5 systems** you can talk about (platform, air-gap delivery, pipeline, network, Kubeflow)
- **Be able to draw 3** on a whiteboard with narration (platform layers, air-gap flow, Bird-Dog network)
- **Have 1 you can go 4 levels deep on** — the VivSoft JCRS-E platform is this one

### Drawing Rules

1. Draw BOXES first (major components), then ARROWS (data flow), then LABELS (tool names)
2. Use the whiteboard space: left = input/source, right = output/destination, top-to-bottom = layers
3. Label EVERY arrow — "gRPC", "HTTPS", "Zarf bundle", "TGW attachment"
4. Don't draw everything — draw what's relevant to the question being asked
5. Circle the part you're talking about as you narrate

### Handling Follow-Ups

| Follow-up type | How to respond |
|---------------|----------------|
| "Go deeper on X" | Add ONE level of detail. 2-3 sentences. Then stop and wait. |
| "Why did you choose X over Y?" | State the decision, the constraint that drove it, and the tradeoff you accepted. |
| "What would you do differently?" | Own it. State what you chose, why it was wrong, what you changed. (Use Story 19) |
| "How does this relate to what we do?" | Bridge: "At Anduril, this would map to your diode transfer flow..." |

### Bridging to Anduril

After ANY system explanation, be ready to connect it:
- Air-gap packaging → "Your diode transfer challenge is the same problem — bundling, validating, deploying without internet"
- RKE2 → "If you're rolling out Kubernetes on-prem, the bootstrap process I built with Ansible maps directly"
- Ansible roles → "Your pure-Ansible air-gap environment is where I've done my most hands-on role writing"
- Registry population → "The registry population problem I solved with Zarf + Harbor is what you're tackling with the diode now"

---

## System 1: VivSoft JCRS-E Platform (The Flagship)

> **When to use:** "Walk me through the most complex thing you've built" / "Describe your current platform" / "Tell me about your architecture"
> **Answer key:** vivsoft-answers.md — Sections 2 + 5

### Opening Line
"I built a multi-tenant Kubernetes platform for USCYBERCOM's cyber operations, deployed on AWS GovCloud in air-gapped environments. It runs 20+ services across 8 environments at 2 classification levels, serving 4 programs. Let me draw the layers."

### Drawing Order (what to draw first)

**Step 1 — Draw 6 horizontal boxes stacked vertically:**
```
[Mission Apps]
[Enterprise Services]
[Core Platform]
[Kubernetes / EKS]
[AWS Infrastructure]
[AWS GovCloud]
```
Say: "The platform is layered — each layer can be updated independently. Bottom up."

**Step 2 — Fill in Layer 0-1 (bottom):**
"At the base, AWS GovCloud — FedRAMP High, everything encrypted with KMS. Above that, infrastructure managed by Terraform — VPC, subnets, KMS, S3, Transit Gateway."

**Step 3 — Fill in Layer 2 (Kubernetes):**
"EKS with managed control plane. Worker nodes run on our STIG'd AMIs — RHEL 8 or 9, about ninety percent DISA STIG compliance, built with Packer and Ansible. I locked down IMDSv2 — every pod uses IRSA for AWS access, no instance profile leaking."

**Step 4 — Fill in Layer 3 (Core):**
"Core platform bundle: Istio for service mesh with automatic mTLS, Kyverno for admission policies — blocks any non-Iron Bank image, Prometheus plus Loki for observability, Neuvector for runtime security, Crossplane for cloud resource management."

**Step 5 — Fill in Layer 4 (Enterprise):**
"Enterprise bundle on top: Vault for multi-tenant secrets in Raft HA, Keycloak for identity with OIDC and CAC auth, ArgoCD for GitOps app delivery, Grafana for visualization."

**Step 6 — Fill in Layer 5 (Apps):**
"Mission app teams deploy here via ArgoCD. They get identity, secrets, observability, and service mesh automatically — they don't manage any of it."

### What to Emphasize (the 4 points that show ownership)
1. **Air-gap-first design** — Zarf bundles every image and chart, nothing assumes internet
2. **Classification boundary separation** — separate repos for IaC and CaC because SIPRNET classifies everything in a repo
3. **Self-service via Crossplane** — teams declare needs in YAML, platform reconciles (went from weeks to hours)
4. **I own it end-to-end** — architecture direction, code reviews across 10+ repos, release management, team of 6

### Likely Follow-Ups

**"How do you handle air-gap deployment?"**
→ "Zarf pre-bundles every container image and Helm chart into a self-contained archive. UDS orchestrates deployment order. Build happens on an internet-connected runner, then the bundle is transferred to the air-gapped environment and deployed. No internet access needed at deploy time."
→ Offer to draw the air-gap delivery flow (System 2)

**"Why Kapitan over Kustomize?"**
→ "Kapitan uses class inheritance — one template compiles to many environments. A new environment is 5 lines that reference shared defaults. Kustomize is patch-based — you modify a base, which gets messy when you have 8+ environments with different classification levels."

**"How do you handle secrets?"**
→ "Vault in Raft HA mode. Per-tenant policies automated through Crossplane — teams declare access needs in their config, pipeline compiles it to a Kubernetes claim, Crossplane reconciles via Vault's HTTP API. Secrets never touch Git."

**"What would you do differently?"**
→ Use Story 19: "Initially kept CaC and IaC in the same repo for simplicity. Cost us when deploying to SIPRNET — everything got classified. Split them within two weeks but it cost a sprint of rework. Lesson: design for classification constraints from day one."

### Memory Anchors
- **Layers:** GovCloud → Infra → K8s → Core → Enterprise → Apps (bottom to top)
- **Core bundle = security foundation:** mesh, monitoring, policy, runtime security
- **Enterprise bundle = user-facing:** secrets, identity, GitOps, visualization
- **Repos:** CAC (config), Kraken (infra), Leviathan (packages), Release-automation (pipeline)

---

## System 2: Air-Gap Delivery Flow (Most Anduril-Relevant)

> **When to use:** "How did you handle air-gap?" / "How do you get software to disconnected networks?" / "Design a registry population system"
> **Answer key:** vivsoft-answers.md — Section 8

### Opening Line
"Build and deploy are completely decoupled. Packages are built once on an internet-connected runner, stored in S3, then deployed to any air-gapped cluster. Let me draw the flow."

### Drawing Order

**Step 1 — Draw two sides with a barrier:**
```
[Connected Side]  ║ TRANSFER ║  [Air-Gap Side]
```

**Step 2 — Connected side (left):**
"Leviathan repo triggers GitLab CI. It pulls images from Iron Bank, downloads Helm charts, and runs Zarf package create — which bundles everything into a content-addressed tar archive. Trivy scans for CVEs. Bundles upload to S3."

**Step 3 — Transfer (middle):**
"S3 is the artifact bridge. In practice, for classified networks, this could be a diode, USB, or cross-account S3 sync. The key: every bundle has a SHA256 hash, and we validate on the receiving side."

**Step 4 — Air-gap side (right):**
"The pipeline downloads bundles from S3, runs UDS deploy, which pushes images to an in-cluster registry at 127.0.0.1:31999 and deploys Helm charts via FluxCD. From there, FluxCD handles continuous reconciliation — if anything drifts, Flux reverts it."

### What to Emphasize
1. **Build once, deploy anywhere** — same bundle goes to dev, staging, production, different classification levels
2. **Content-addressed** — SHA256 hashes verify nothing was corrupted or tampered during transfer
3. **Dependency ordering** — UDS deploys packages in the right sequence (CRDs before resources that use them)
4. **Dual-loop GitOps** — GitLab CI is the outer loop (orchestration), FluxCD is the inner loop (continuous reconciliation)

### Bridging to Anduril
"This is exactly what you're building with the diode. You need: declarative bundling, checksum validation, automated unpacking into local registries, and something watching the local repo to deploy changes. I've built every piece of this chain."

---

## System 3: 7-Stage CI/CD Pipeline

> **When to use:** "Walk me through your CI/CD" / "How do you deploy?" / "Tell me about your pipeline"
> **Answer key:** vivsoft-answers.md — Section 7

### Opening Line
"I built a 7-stage GitLab CI pipeline with a toggle-based deployment pattern. Each stage has a boolean — if I only need to update Vault, I flip one toggle and skip everything else. Saves forty-five minutes compared to a full run."

### Drawing Order

**Draw 7 boxes in a row:**
```
[PREP] → [INFRA] → [CLUSTER] → [ZARF INIT] → [CORE] → [ENTERPRISE] → [DESTROY]
```

**Under each, write what it does:**
- PREP: Clone config repo, compile Kapitan target
- INFRA: Terraform — VPC, IAM, KMS
- CLUSTER: Terraform (kraken) — EKS + STIG'd node groups
- ZARF INIT: In-cluster registry + Gitea + Zarf agent
- CORE: UDS deploy core bundle (Istio, Kyverno, Prometheus, Neuvector)
- ENTERPRISE: UDS deploy enterprise bundle (Vault, Keycloak, ArgoCD)
- DESTROY: Terraform destroy (after TTL expires — ephemeral only)

**Draw a "VERIFY" bar underneath stages 2-6:**
"Verification jobs run after every stage, whether the stage deployed or not. This catches drift."

### What to Emphasize
1. **Toggle-based** — skip what hasn't changed, deploy only what's needed
2. **Idempotent** — every stage is safe to rerun
3. **Verification after every stage** — catches drift, doesn't just trust the deploy
4. **Two-job pattern** — one deploy job (toggled) + one verify job (always runs)

---

## System 4: Bird-Dog Network Architecture

> **When to use:** "Tell me about your networking experience" / "Describe a network you designed" / "Packet trace"
> **Answer key:** ntconcepts-answers.md — first mermaid chart

### Opening Line
"At NTConcepts, I designed Bird-Dog — a hub-and-spoke network in AWS GovCloud with centralized egress inspection through Network Firewall. Every outbound packet from any spoke goes through the firewall before reaching the internet."

### Drawing Order

**Step 1 — Draw the hub in the center:**
"Infrastructure account owns the Transit Gateway, shared via RAM to all spokes."

**Step 2 — Draw 3-4 spoke boxes around it:**
"Spokes: Directory account for Active Directory and Workspaces, Collab account with EKS clusters running GitLab and ArgoCD, and Proj64 StudioDX with Kubeflow and GPU nodes. Each spoke has its own VPC."

**Step 3 — Draw the Inspection VPC:**
"The hub has an Inspection VPC with Network Firewall. All spoke egress flows through TGW → NFW → NAT Gateway → IGW."

**Step 4 — Draw TGW route tables:**
"Two route tables: Inspection RT sends all 0.0.0.0/0 to the firewall. Return RT sends responses back to the correct spoke CIDR."

**Step 5 — Note appliance mode:**
"Appliance mode MUST be enabled on the TGW attachment — without it, return traffic can bypass the firewall via a different AZ. Asymmetric routing."

### What to Emphasize
1. **Deny by default** — firewall default action is drop. Only allowlisted domains pass.
2. **Appliance mode** — critical for symmetric routing through the firewall
3. **VPC Endpoints in every spoke** — AWS API traffic stays private, never hits the firewall
4. **Real CIDRs** — 10.10.0.0/16 (main VPC), 10.50.0.0/16 (Proj64), 10.70.0.0/16 (NFW VPC)

### The Packet Trace (practice this aloud)
"Pod in Proj64 calls an external API. DNS resolves through CoreDNS → upstream VPC DNS. Packet leaves pod via CNI, hits the node, node route table sends to VPC router. VPC route table says 0.0.0.0/0 → TGW attachment. TGW Inspection route table forwards to Network Firewall. Firewall checks stateful rules — if the domain is allowlisted, passes to NAT Gateway. NAT does source NAT, sends through IGW to the internet. Response follows the reverse path through the TGW Return route table back to the correct spoke."

---

## System 5: Kubeflow / StudioDX ML-Ops Platform

> **When to use:** "Tell me about something you built from scratch" / "ML experience?" / "Customer-facing platform?"
> **Answer key:** ntconcepts-answers.md — second mermaid chart

### Opening Line
"At NTConcepts, I was product owner for the ML-Ops platform serving 12 data scientists. I deployed Kubeflow on EKS with GPU node pools that auto-scale based on training demand. Tripled model-training throughput."

### Drawing Order

**Step 1 — Draw the user path:**
"Engineers connect through AWS Workspaces with a web browser. They access two environments: Collab for dev tools, and StudioDX for ML workloads."

**Step 2 — Draw StudioDX cluster:**
"EKS cluster with three node group types: CPU nodes for general compute, g4dn.2xlarge for standard GPU training, and g4dn.12xlarge for large GPU jobs."

**Step 3 — Draw Kubeflow components:**
"Inside the cluster: Kubeflow with Jupyter notebooks, TensorBoard for monitoring, MLflow for model registry, and training operators for distributed jobs."

**Step 4 — Draw the auth flow:**
"NLB → Istio ingress → oauth2-proxy → Keycloak. Enterprise SSO — data scientists don't manage credentials."

**Step 5 — Draw the infrastructure services:**
"ArgoCD deploys everything via GitOps. Cert-manager for TLS. External-secrets syncs from AWS Secrets Manager. External-dns manages Route53 records."

### What to Emphasize
1. **Self-service GPU scheduling** — data scientists launch a job, Cluster Autoscaler provisions a GPU node automatically
2. **Built from scratch** — not inheriting an existing platform. Greenfield.
3. **Tripled throughput** — concrete metric, directly attributable to the platform
4. **GitOps everything** — ArgoCD syncs from Git, no manual deploys

---

## System 6: Crossplane Self-Service

> **When to use:** "How do you handle multi-tenancy?" / "How do teams provision resources?" / "Platform engineering approach"
> **Answer key:** vivsoft-answers.md — Section 11

### Opening Line
"The platform team was becoming a bottleneck — every new team needed Vault policies, RDS databases, S3 buckets. I implemented Crossplane to make it self-service. Teams declare what they need in 5 lines of YAML, and the platform reconciles it."

### Key Concept (explain this clearly)
"Crossplane extends Kubernetes with custom resource definitions. I created an XRD called VaultPolicy — when a team creates a VaultPolicy claim in their namespace, Crossplane translates it into Vault HTTP API calls and creates the actual policy. The team never touches Vault directly. Same pattern for RDS databases — Keycloak's PostgreSQL backend is automatically provisioned per-cluster via a claim."

### What to Emphasize
1. **Kubernetes-native** — Crossplane continuously reconciles. If someone deletes a Vault policy, Crossplane recreates it.
2. **GitOps-compatible** — claims are YAML in Git, deployed by the pipeline
3. **Replaces manual provisioning** — went from ticket-based to declarative
4. **Scales multi-tenancy** — adding a new team is adding config to their Kapitan target, not filing a request

---

## How to Memorize All of This

### Daily Practice Routine (during Architecture block)

1. **Pick one system** from the rotation
2. **Close everything** — no screens, no notes
3. **Draw it on paper** — boxes, arrows, labels
4. **Narrate aloud** — use the opening lines and drawing orders from this guide
5. **Open the answer key** — compare. What did you miss?
6. **Open this coaching guide** — review the emphasis points and follow-up answers
7. **Redo the parts you missed** — draw and narrate again

### The "Elevator Pitch" Test

For each system, you should be able to explain it in 30 seconds:
- **Platform:** "Multi-tenant K8s for DoD on GovCloud, 6 layers, air-gapped, 20+ services, team of 6"
- **Air-gap:** "Build on internet side, bundle with Zarf, transfer, deploy to disconnected clusters"
- **Pipeline:** "7-stage GitLab CI with toggles — skip what hasn't changed, verify after every stage"
- **Bird-Dog:** "Hub-and-spoke with TGW, centralized egress through Network Firewall, deny-by-default"
- **Kubeflow:** "ML-Ops platform, GPU auto-scaling, Kubeflow on EKS, tripled throughput for 12 data scientists"
- **Crossplane:** "Self-service infrastructure — teams declare needs in YAML, Crossplane provisions it"

If you can say these 6 elevator pitches from memory, you have the foundation. The deep details come from practice.
