# Architecture Practice: VivSoft JCRS-E Platform

## Exercise: Draw and Narrate

**Instructions:**
1. Get a blank sheet of paper (or whiteboard)
2. Set a timer for 10 minutes
3. Draw the 6-layer platform architecture from memory
4. Narrate out loud as you draw — explain what each layer does and WHY
5. After drawing, answer the follow-up questions below out loud (3-5 min each)

---

## HOW TO DRAW — The Question Method (16 Questions)

> Same approach as Nightwatch and IBM. Walk through these questions in order. Each one forces you to draw a section with relationships — not flat boxes.

**"Walk me through the platform you built for USCYBERCOM."**

### Infrastructure Foundation (Questions 1-4)

| # | Question | What you draw | What you say |
|---|----------|--------------|-------------|
| 1 | "Where does this run?" | AWS GovCloud box (us-gov-west-1). Label: FedRAMP High, KMS encryption on everything | "AWS GovCloud — FedRAMP High authorized. Region us-gov-west-1. Every resource encrypted with KMS. This is the foundation." |
| 2 | "What infrastructure supports the cluster?" | Inside GovCloud: VPC with private subnets, KMS, S3 (artifacts + state), Transit Gateway connecting to parent org. Label: "Terraform — kraken repo" | "Infrastructure managed by Terraform in the kraken repo — separate from config, stays unclassified. VPC with private subnets only, KMS keys for encryption, S3 for artifacts and Terraform state, Transit Gateway connecting us to the parent org network." |
| 3 | "What does the K8s cluster look like?" | EKS box inside VPC: managed control plane, worker nodes on STIG'd AMIs. Labels: "Packer + Ansible + OSCAP, 90% DISA STIG", "IMDSv2 hop=1 → forces IRSA" | "EKS with managed control plane. Worker nodes run on our custom STIG'd AMIs — built with Packer, hardened by Ansible, scanned by OSCAP at build time. Ninety percent DISA STIG before a single container runs. I locked IMDSv2 to hop count one — blocks pod-level metadata access. Every pod must use IRSA for AWS access. Pod-level least-privilege." |
| 4 | "How do nodes get their images?" | In-cluster registry box (127.0.0.1:31999). Arrow from Zarf → pushes images to registry. Arrow from nodes → pull from in-cluster registry. Label: "air-gap — no Docker Hub, no internet" | "Air-gapped. Zarf bundles include every container image. At deploy time, Zarf pushes them to an in-cluster registry at 127.0.0.1:31999. Nodes pull from there — never from Docker Hub or the internet. Every image comes from Iron Bank — DoD-hardened, scanned, signed." |

### Core Platform Services (Questions 5-8)

| # | Question | What you draw | What you say |
|---|----------|--------------|-------------|
| 5 | "How is traffic secured between pods?" | Istio box with labels: "automatic mTLS, ingress gateway, Envoy sidecars". Arrow showing pod-to-pod mTLS | "Istio service mesh — every pod-to-pod call is mTLS encrypted automatically. Envoy sidecars injected by admission webhook. App code makes plain HTTP calls, sidecars handle encryption transparently. Zero-trust: nothing is trusted based on network location." |
| 6 | "How do you enforce what runs in the cluster?" | Kyverno box. Arrow from API server → Kyverno → "blocks non-Iron Bank images". Neuvector box → "runtime container security" | "Two layers. Kyverno admission policies — if someone tries to deploy an image not from Iron Bank, the API server rejects it before the pod even creates. Neuvector for runtime — monitors container processes, file access, network behavior. Catches anomalies after deployment." |
| 7 | "How do you observe what's happening?" | Prometheus + Alloy + Loki box → Grafana/Kiali/Tempo for visualization | "Full observability stack running inside the cluster — zero internet dependency. Prometheus for metrics, Alloy for collection, Loki for log aggregation. Grafana for dashboards, Kiali for service mesh visualization, Tempo for distributed tracing. All deployed via Zarf bundles." |
| 8 | "How do teams get cloud resources without tickets?" | Crossplane box with arrows: team writes Kapitan target → compiles to Crossplane claim → Crossplane calls Vault API → policy created. Also: Crossplane → RDS for Keycloak backend | "Crossplane for self-service. Teams declare what they need in their Kapitan target — five lines: 'I need a Vault policy and secrets access.' Pipeline compiles it to a Crossplane claim. Crossplane reconciles by calling the Vault HTTP API — creates the policy automatically. Same pattern for RDS: Keycloak's PostgreSQL backend is provisioned via Crossplane claim. No tickets, no waiting on the platform team." |

### Enterprise Services (Questions 9-11)

| # | Question | What you draw | What you say |
|---|----------|--------------|-------------|
| 9 | "How are secrets managed?" | Vault box: Raft HA, multi-tenant, per-team policies via Crossplane. Arrow from pods → Vault (service account tokens). Label: "secrets never in Git" | "Vault in Raft HA mode — persistent, survives restarts. Multi-tenant: each team gets their own policy, automated by Crossplane. Pods access secrets through service account tokens mapped to Vault policies. Secrets never live in Git, never in env vars. TLS passthrough through Istio — Vault handles its own certs end-to-end." |
| 10 | "How do users authenticate?" | Keycloak box: OIDC, MFA, CAC smart card. Authservice box → "Envoy-based SSO proxy, transparent to apps". Arrow: Crossplane → RDS (provisions Keycloak's database) | "Keycloak for identity — OIDC, MFA, CAC smart card authentication. Authservice is an Envoy-based SSO proxy injected via Istio — services don't implement their own auth. Every request is authenticated before it reaches the app. Keycloak's PostgreSQL backend is provisioned by Crossplane automatically." |
| 11 | "How are apps deployed inside the cluster?" | ArgoCD box → watches Git → deploys to cluster. FluxCD box → reconciles HelmReleases inside cluster. Label: "dual-loop GitOps — GitLab CI outer, FluxCD inner" | "Dual-loop GitOps. GitLab CI is the outer loop — orchestrates the pipeline, runs Zarf/UDS deploys. Inside the cluster, FluxCD handles continuous reconciliation — it watches HelmRelease CRDs and keeps services in sync. If something drifts, FluxCD reverts it. ArgoCD is used for mission app delivery — teams deploy their apps via ArgoCD projects." |

### Air-Gap Packaging & Delivery (Questions 12-14)

| # | Question | What you draw | What you say |
|---|----------|--------------|-------------|
| 12 | "How does software get into an air-gapped cluster?" | Left side: "Connected build runner" → pulls from Iron Bank → scans with Trivy → bundles with Zarf → uploads to S3. Right side: "Air-gap cluster" → pipeline pulls from S3 via VPC endpoint → UDS deploys bundles in order → images pushed to in-cluster registry | "Build and deploy are completely decoupled. Connected side: GitLab CI pulls images from Iron Bank, scans with Trivy, bundles everything into Zarf archives, uploads to S3. Air-gap side: pipeline pulls bundles from S3 through a VPC endpoint — private path, no internet. UDS deploys in dependency order: core bundle first, then enterprise. Images land in the in-cluster registry. Build once, deploy to any cluster." |
| 13 | "How do you manage config across 8 environments?" | Kapitan box: classes (shared defaults) → targets (5-line per-env files) → compile → output scripts + values + claims. Arrow: "One change to a class → all 8 targets update" | "Kapitan with class inheritance. Shared defaults in classes — bb-vault.yml says port 8200, Raft HA. Per-environment targets are five lines: reference the classes, override what's different. Compile once, get output for all eight environments. Change a default? All environments inherit the change. No patching, no drift between environments." |
| 14 | "Why are the repos separated?" | 4 repo boxes: kraken (Terraform), jcrs-cac (Kapitan), leviathan (Zarf packages), release-automation (pipeline). Arrows showing data flow between them. Label: "classification boundary — IaC stays unclassified" | "Four repos by design. kraken for Terraform — stays unclassified, developers work freely. jcrs-cac for Kapitan config — generates output for all environments including SIPRNET, heightened review for SIPRNET changes only. leviathan builds Zarf packages and bundles, uploads to S3. release-automation is the seven-stage pipeline that orchestrates everything. The split prevents infrastructure work from getting blocked by classification reviews." |

### Pipeline & Operations (Questions 15-16)

| # | Question | What you draw | What you say |
|---|----------|--------------|-------------|
| 15 | "How does the pipeline work?" | 7 boxes in a row: PREP → INFRA → CLUSTER → ZARF INIT → CORE → ENTERPRISE → DESTROY. Toggle switches on each. Verification bar underneath. | "Seven-stage GitLab CI pipeline with toggle-based deployment. Each stage has a boolean — flip one, skip the rest. Need to update only Vault? Toggle enterprise on, everything else off. Saves forty-five minutes versus a full run. Every stage is idempotent — safe to rerun. Verification jobs run after every stage whether it deployed or not — catches drift." |
| 16 | "How do mission app teams use the platform?" | Mission app team box → writes 5-line Kapitan target → pipeline creates: namespace, RBAC, Vault policies, Crossplane claims → ArgoCD syncs their app → they get mesh, identity, secrets, observability automatically | "Self-service. Team writes a five-line Kapitan target: 'I'm the JAWS team, I need a namespace with Vault access.' Pipeline compiles it, Crossplane provisions the namespace, RBAC, Vault policies. ArgoCD syncs their app from their Git repo. They get Istio mesh, Keycloak SSO, Vault secrets, Prometheus monitoring — all out of the box, no tickets. Onboarding went from weeks to hours." |

**After all 16:** Write the scale metrics: "20+ services, 8 environments, 2 classification levels, 4 programs, team of 6. Delivered in 8 months from blank slate."

---

## GAPS — Review Before Each Drawing Attempt

> Add gaps here after each attempt. Read FIRST before redrawing.

*(empty — fill in after your first attempt)*

---

## Reference: The 6 Layers (quick reference only — use the 16 questions to draw)

**Layer 0 — AWS GovCloud**
- Region: us-gov-west-1
- FedRAMP High authorized
- Everything encrypted with KMS

**Layer 1 — Infrastructure (Terraform — "kraken" repo)**
- VPC with private subnets
- KMS keys for encryption
- S3 for artifacts
- Transit Gateway connecting to parent org network

**Layer 2 — Kubernetes (EKS)**
- Managed control plane
- Worker nodes on STIG'd AMIs (RHEL 8/9, ~90% DISA STIG, Packer + Ansible + OSCAP)
- IMDSv2 locked down (hop count = 1) — forces IRSA for all pods
- Cluster Autoscaler
- EKS addons: vpc-cni, coredns, efs-csi

**Layer 3 — Core Platform (core bundle)**
- Istio service mesh (automatic mTLS)
- Kyverno admission policies (blocks non-Iron Bank images)
- Prometheus + Alloy + Loki (observability)
- Neuvector (runtime container security)
- Authservice (SSO proxy)
- Cert-Manager + Trust-Manager (certificate lifecycle)
- Crossplane (cloud resource management)

**Layer 4 — Enterprise Services (enterprise bundle)**
- ArgoCD (GitOps app delivery)
- Vault (secrets — Raft HA, multi-tenant, Crossplane-automated policies)
- Keycloak (identity — OIDC, MFA, CAC auth, Crossplane-provisioned RDS)
- Mattermost (ChatOps)
- GitLab + Nexus (DevOps lifecycle)
- Grafana / Kiali / Tempo (visualization)

**Layer 5 — Mission Applications**
- JAWS, CyberAlly, OpenCTI
- Deploy via ArgoCD
- Get identity, secrets, observability, service mesh automatically

### The Multi-Repo Architecture (draw as boxes)

| Repo | Purpose |
|------|---------|
| **jcrs-cac** | Configuration-as-Code (Kapitan classes, targets, inventory) |
| **kraken** | Infrastructure-as-Code (Terraform modules, state, provisioning) |
| **leviathan** | Zarf/UDS packages (air-gap bundles, container images, Helm charts) |
| **release-automation** | 7-stage pipeline (orchestration, toggles, verification) |

**Why separate repos?** Classification boundary requirement — if IaC and CaC share a repo, the entire repo becomes classified when touching SIPRNET.

### Scale
- 20+ services
- 8 environments
- 2 classification levels
- 4 JCWA programs (CNMF, COF, JCC2, PCTE)
- Team of 6 engineers

---

## Follow-Up Questions (Answer Aloud)

1. **"Why did you choose Kapitan over Kustomize or Helm for configuration?"**
   - Kapitan provides class inheritance — a new environment target is defined in 5 lines that reference shared defaults
   - Kustomize is patch-based (what to change), Kapitan is inventory-based (what to include)
   - For multi-env, multi-classification deployments, inheritance beats patching

2. **"Why Zarf for air-gap instead of just tarballs?"**
   - Zarf creates declarative, versioned, content-addressable bundles
   - Includes images + charts + manifests in one self-contained archive
   - UDS orchestrates deployment order based on dependencies
   - Hash-verified — you know nothing drifted during transfer
   - Manual tarballs have no validation, no ordering, no rollback

3. **"How do you handle secrets in air-gap?"**
   - Vault in Raft HA mode (no external dependency)
   - Per-tenant policies automated via Crossplane
   - Teams declare access needs in Kapitan config → compiled to K8s claims → Crossplane reconciles via Vault HTTP API
   - Secrets never in Git

4. **"What would you do differently?"**
   - Story 19: Initially kept CaC and IaC in the same repo for simplicity
   - This created classification boundary issues when touching SIPRNET
   - A staging RDS endpoint leaked into a production bundle
   - Split repos within 2 weeks, but it cost a sprint of rework
   - Lesson: design for classification constraints from day one

5. **"How does the pipeline work?"**
   → See vivsoft-cicd-pipeline.md

6. **"How do teams onboard to the platform?"**
   - Crossplane self-service: team defines needs in Kapitan target (5 lines of YAML)
   - Pipeline compiles → creates namespace, Vault policies, RBAC, secrets access
   - ArgoCD syncs their app from their Git repo
   - They get identity, secrets, observability, service mesh out of the box
   - Went from weeks to hours

---

## Answer Keys + Coaching

- **Real architecture reference:** `vivsoft-answers.md` — Sections 2 + 5
- **How to present this:** `deep-dive-coaching-guide.md` — System 1
