# DoD Kubernetes Platform — Architecture Reference


> **Purpose:** Principal engineer interview prep. Study this to explain the platform end-to-end with confidence and depth.
> Mermaid diagrams work as whiteboard references — open in VS Code (Mermaid extension), GitLab preview, or [mermaid.live](https://mermaid.live).


---


## Table of Contents


1. [Platform Overview](#1-platform-overview)
2. [Architecture Approach](#2-architecture-approach)
3. [Repository Ecosystem](#3-repository-ecosystem)
4. [Deployment Tools Hierarchy](#4-deployment-tools-hierarchy)
5. [Cluster Stack Layers](#5-cluster-stack-layers)
6. [Configuration-as-Code (Kapitan)](#6-configuration-as-code-kapitan)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Package & Bundle Build System](#8-package--bundle-build-system)
9. [Networking Architecture](#9-networking-architecture)
10. [Security Architecture](#10-security-architecture)
11. [Crossplane & Infrastructure Automation](#11-crossplane--infrastructure-automation)
12. [Environment Topology & GitOps Lifecycle](#12-environment-topology--gitops-lifecycle)
13. [Quick Reference](#13-quick-reference)


---


## 1. Platform Overview


This is a **multi-tenant Kubernetes platform for DoD cyber operations**, deployed on **AWS GovCloud** in **air-gapped environments**. The platform provides a standardized runtime that mission application teams deploy onto — they get identity, secrets, observability, GitOps delivery, and a hardened service mesh out of the box.


**What makes this platform technically interesting:**


- **Air-gapped by design** — clusters have zero internet access. Every container image, Helm chart, and manifest must be pre-packaged and transferred. This fundamentally shapes the tooling choices (Zarf, UDS, in-cluster registries).
- **Multi-environment, multi-tenant** — development, staging (left/right), and production environments across separate AWS accounts. Each environment is reproducible from Git configuration alone.
- **Defense-in-depth security** — hardened AMIs (~90% STIG compliance), Iron Bank container images, Istio mTLS everywhere, Kyverno admission policies, Neuvector runtime security, Vault for secrets, Keycloak for identity.
- **GitOps-driven lifecycle** — every environment is declared in Git. A pipeline compiles configuration, provisions infrastructure, and deploys 20+ services in sequence. No manual steps, no SSH-and-fix.
- **10+ repositories, 20+ deployed services** — the platform spans infrastructure provisioning (Terraform), configuration management (Kapitan), package building (Zarf/UDS), pipeline orchestration (GitLab CI), and in-cluster GitOps (FluxCD).


**Scope of responsibility:** I own the full platform — infrastructure through application delivery. This includes architecture direction, merge request reviews across all repos, cross-team coordination with application teams and security, release management, and hands-on engineering across every layer of the stack.


---


## 2. Architecture Approach


The platform follows a **layered design** with strict separation of concerns. Each layer can be updated independently, and the boundaries between layers are the key architectural decisions.


### Core Design Decisions


| Decision | Rationale |
|----------|-----------|
| **Separate configuration from infrastructure** | Configuration (Kapitan/jcrs-cac) and infrastructure (Terraform/kraken) live in different repos. This was a hard lesson from the legacy platform — when deploying to classified environments, configs can't move back down from high to low side. Tight coupling made that painful. |
| **Air-gap-first packaging** | Instead of retrofitting internet-connected tooling for air-gap, the entire deploy chain is built around Zarf packages that bundle images + manifests. This is the #1 constraint that drives tooling choices. |
| **Layered bundle deployment** | Core platform services (Istio, monitoring, policy) deploy as one bundle. Enterprise services (Vault, Keycloak, ArgoCD) deploy as a second bundle on top. Mission apps come last. Each layer has a clean dependency boundary. |
| **GitOps with FluxCD inside, GitLab CI outside** | GitLab CI handles the outer loop (infra provisioning, package deployment). FluxCD handles the inner loop (in-cluster reconciliation of Helm releases). This separation means Flux continuously enforces desired state even after the pipeline finishes. |
| **Crossplane for tenant self-service** | Instead of manually provisioning Vault policies or RDS instances, teams declare what they need as Kubernetes custom resources. Crossplane reconciles them. This scales multi-tenancy without requiring platform team intervention for every request. |


```mermaid
graph TB
   subgraph "Architecture Layers"
       direction TB
       APPS["Mission Applications<br/><i>Customer workloads deployed via ArgoCD</i>"]
       ENT["Enterprise Services<br/><i>Vault · Keycloak · ArgoCD · GitLab<br/>Mattermost · Grafana · Tempo</i>"]
       CORE["Core Platform Services<br/><i>Istio · Kyverno · Prometheus · Loki<br/>Neuvector · Authservice · Crossplane</i>"]
       K8S["Kubernetes (EKS)<br/><i>Managed control plane · STIG'd worker nodes<br/>IRSA · EKS addons</i>"]
       INFRA["AWS Infrastructure<br/><i>VPC · KMS · S3 · Transit Gateway<br/>Terraform-managed</i>"]
   end


   subgraph "Key Boundaries"
       direction TB
       B1["Enterprise bundle depends on Core bundle"]
       B2["Core runs on bare EKS + addons"]
       B3["EKS created by Terraform (kraken)"]
       B4["All infra in GovCloud (FedRAMP High)"]
   end


   APPS --> ENT
   ENT --> CORE
   CORE --> K8S
   K8S --> INFRA


   ENT -.- B1
   CORE -.- B2
   K8S -.- B3
   INFRA -.- B4


   style APPS fill:#975a16,color:#fff
   style ENT fill:#c53030,color:#fff
   style CORE fill:#2f855a,color:#fff
   style K8S fill:#2b6cb0,color:#fff
   style INFRA fill:#553c9a,color:#fff
```


### Why This Matters


The layered approach means I can upgrade Istio without touching Vault, roll out a new Keycloak version without rebuilding infrastructure, or spin up an entirely new environment by pointing the pipeline at a new Kapitan target. Each layer is independently versionable, testable, and deployable. This is what makes the platform maintainable at scale despite the complexity.


---


## 3. Repository Ecosystem


The platform spans 10+ repositories, each with a specific responsibility. No single repo does everything — the separation is deliberate and reflects the architecture layers.


| Repository | What It Owns | Key Output |
|------------|-------------|------------|
| **jcrs-cac** | Configuration-as-Code (Kapitan) | Compiled deployment scripts + config YAML |
| **leviathan** | Package factory (Zarf/UDS) | Zarf packages + UDS bundles uploaded to S3 |
| **release-automation** | CI/CD pipeline orchestration | End-to-end deployed environments |
| **kraken** | Infrastructure-as-Code (Terraform) | EKS clusters, VPC, IAM, security groups |
| **jcrs-e** | Deployment container image | Docker image containing all tools (kubectl, helm, zarf, terraform, kapitan) |
| **jcrs-e-docs** | Customer-facing documentation | Architecture docs, onboarding guides, networking diagrams |
| **jcrse-zarf-init** | Custom Zarf init package | In-cluster container registry + Zarf agent |
| **image-builder** | STIG'd AMI builder | RHEL 8/9 AMIs with ~90% DISA STIG compliance |
| **jcrs-profile-operator** | K8s operator for deployment profiles | Profile lifecycle management |
| **team-automation** | Automation bots | MR validation, registry cleanup, Renovate dependency updates |


```mermaid
graph LR
   subgraph "Configuration"
       CAC["jcrs-cac<br/><i>Kapitan config</i>"]
   end


   subgraph "Packaging"
       LEV["leviathan<br/><i>Zarf/UDS packages</i>"]
       INIT["jcrse-zarf-init<br/><i>Init package</i>"]
   end


   subgraph "Infrastructure"
       JCRSE["jcrs-e<br/><i>Deploy container</i>"]
       KRAKEN["kraken<br/><i>EKS Terraform</i>"]
       IMG["image-builder<br/><i>STIG'd AMIs</i>"]
   end


   subgraph "Orchestration"
       REL["release-automation<br/><i>GitLab CI pipeline</i>"]
   end


   S3["S3 Artifact Storage"]
   K8S["EKS Cluster"]


   REL -->|"1. clone + compile"| CAC
   CAC -->|"2. scripts + config"| JCRSE
   JCRSE -->|"3. terraform apply"| KRAKEN
   IMG -->|"AMI IDs"| KRAKEN
   KRAKEN -->|"4. cluster ready"| K8S
   LEV -->|"build + upload"| S3
   REL -->|"5. deploy init"| INIT
   INIT -->|"registry + agent"| K8S
   REL -->|"6. download bundles"| S3
   S3 -->|"7. UDS deploy"| K8S


   style REL fill:#c53030,color:#fff
   style CAC fill:#2f855a,color:#fff
   style LEV fill:#975a16,color:#fff
   style K8S fill:#2b6cb0,color:#fff
```


### Data Flow


1. **Leviathan** builds Zarf packages and UDS bundles → uploads to **S3**
2. **jcrs-cac** defines environment-specific config → **Kapitan** compiles to deployment scripts
3. **release-automation** pipeline clones jcrs-cac, runs Kapitan, executes compiled scripts
4. Scripts invoke **kraken** (Terraform) for infrastructure, download bundles from **S3**, deploy with **UDS/Zarf**


### Why This Matters


Every repo has a single responsibility. Configuration changes don't require rebuilding packages. Infrastructure changes don't require recompiling config. Package version bumps don't require infrastructure changes. This separation means different engineers can work on different layers concurrently, and the blast radius of any change is contained to its layer. I review MRs across all of these repos and ensure architectural consistency.


---


## 4. Deployment Tools Hierarchy


The tooling stack is layered, and **each layer exists because of a specific constraint**.


| Layer | Tool | What It Solves |
|-------|------|---------------|
| 5 | **Kapitan** | One template → many environments. DRY config via class inheritance + Jinja2 |
| 4 | **UDS** (Unicorn Delivery Service) | Orchestrate 20+ Zarf packages in correct dependency order |
| 3 | **Zarf** | Bundle Helm charts + container images for air-gapped deployment |
| 2 | **Helm** | Template Kubernetes manifests with variables and conditionals |
| 1 | **kubectl** | Apply raw YAML to the Kubernetes API — everything ends up here |


```mermaid
graph TB
   KAP["Kapitan<br/><i>Config generation per environment</i><br/>Jinja2 templates + class inheritance"]
   UDS["UDS Bundle<br/><i>Multi-package orchestration</i><br/>uds deploy bundle.tar.zst"]
   ZARF["Zarf Package<br/><i>Air-gap packaging</i><br/>Helm charts + container images in .tar.zst"]
   HELM["Helm Chart<br/><i>Templated K8s manifests</i><br/>Variables, conditionals, loops"]
   KUBE["kubectl apply<br/><i>Raw YAML → K8s API</i>"]


   KAP -->|"generates scripts that invoke"| UDS
   UDS -->|"unpacks + deploys each package via"| ZARF
   ZARF -->|"pushes images to in-cluster registry<br/>deploys charts via"| HELM
   HELM -->|"renders templates, applies via"| KUBE


   style KAP fill:#6b46c1,color:#fff
   style UDS fill:#c53030,color:#fff
   style ZARF fill:#2b6cb0,color:#fff
   style HELM fill:#2f855a,color:#fff
   style KUBE fill:#975a16,color:#fff
```


### Why This Matters


- **Air-gap is the fundamental constraint.** Clusters can't reach the internet, so Zarf pre-bundles every container image and Helm chart into a self-contained `.tar.zst` archive. At deploy time, Zarf pushes images to an in-cluster registry at `127.0.0.1:31999`.
- **UDS solves dependency ordering.** We deploy 20+ packages and they have ordering requirements — CRDs must exist before resources that use them, the service mesh must be up before services register with it. UDS handles this sequencing.
- **Kapitan prevents config drift.** Without it, we'd have separate shell scripts and YAML files per environment, maintained by hand. With Kapitan, one Jinja2 template compiles to environment-specific output — change the template once, all environments update.
- **Big Bang** is the DoD's reference architecture for hardened Kubernetes. Our Zarf packages wrap Big Bang's Helm charts with Iron Bank images. The Big Bang umbrella chart creates FluxCD resources that handle in-cluster reconciliation.


---


## 5. Cluster Stack Layers


Every cluster follows the same layered architecture. This is what I'd draw on a whiteboard when asked "walk me through your platform."


```mermaid
graph TB
   subgraph L5["Layer 5: Mission Applications"]
       APP1["Mission Apps<br/>JAWS, CyberAlly, OpenCTI"]
       APP2["Customer Services"]
   end


   subgraph L4["Layer 4: Enterprise Services — enterprise bundle"]
       ARGO["ArgoCD<br/><i>GitOps CD</i>"]
       VAULT["Vault<br/><i>Secrets (Raft HA)</i>"]
       KC["Keycloak<br/><i>Identity/SSO</i>"]
       MM["Mattermost<br/><i>Chat/ChatOps</i>"]
       VIZ["Grafana · Kiali · Tempo<br/><i>Visualization</i>"]
       GL["GitLab · Nexus<br/><i>DevOps lifecycle</i>"]
   end


   subgraph L3["Layer 3: Core Platform — core bundle"]
       ISTIO["Istio<br/><i>Service mesh + mTLS</i>"]
       PROM["Prometheus + Alloy<br/><i>Metrics + log collection</i>"]
       LOKI["Loki<br/><i>Log aggregation</i>"]
       KYV["Kyverno<br/><i>Policy engine</i>"]
       NEU["Neuvector<br/><i>Container security</i>"]
       AUTH["Authservice<br/><i>SSO proxy</i>"]
       CERT["Cert-Manager<br/><i>TLS certificates</i>"]
       XP["Crossplane<br/><i>Cloud resources</i>"]
   end


   subgraph L2["Layer 2: Kubernetes — kraken"]
       EKS["Amazon EKS<br/><i>Managed control plane</i>"]
       ADDONS["EKS Addons<br/><i>vpc-cni · coredns · efs-csi</i>"]
       IRSA["IRSA<br/><i>IAM Roles for Service Accounts</i>"]
       ASG["Cluster Autoscaler"]
   end


   subgraph L1["Layer 1: AWS Infrastructure — Terraform"]
       VPC["VPC + Private Subnets"]
       KMS["KMS Encryption"]
       S3["S3 Storage"]
       TGW["Transit Gateway"]
       RDS["RDS (via Crossplane)"]
   end


   subgraph L0["Layer 0: AWS GovCloud"]
       GOV["GovCloud Account<br/><i>FedRAMP High · us-gov-west-1</i>"]
   end


   L5 --> L4
   L4 --> L3
   L3 --> L2
   L2 --> L1
   L1 --> L0


   style L5 fill:#975a16,color:#fff
   style L4 fill:#c53030,color:#fff
   style L3 fill:#2f855a,color:#fff
   style L2 fill:#2b6cb0,color:#fff
   style L1 fill:#553c9a,color:#fff
   style L0 fill:#1a365d,color:#fff
```


### Layer Details


**Layer 0 — AWS GovCloud:** FedRAMP High authorized. Region `us-gov-west-1`. All resources encrypted with KMS.


**Layer 1 — Infrastructure (Terraform):** VPC with private subnets, KMS keys for encryption at rest, S3 for artifact storage, Transit Gateway connecting cluster VPCs to the parent organization's network. Managed by the **kraken** repo.


**Layer 2 — Kubernetes (EKS):** Managed EKS control plane, worker node groups running on STIG'd AMIs (RHEL 8/9), EKS addons (vpc-cni, coredns, efs-csi), Cluster Autoscaler. **IRSA is mandatory** — we lock down IMDSv2 with hop count = 1, which blocks all pod-level instance metadata access. Every pod must use IAM Roles for Service Accounts.


**Layer 3 — Core Platform (core bundle):** Istio service mesh with automatic mTLS, Kyverno for admission policy enforcement, Prometheus + Alloy + Loki for full observability stack, Neuvector for runtime container security, Authservice for SSO proxy, Cert-Manager + Trust-Manager for certificate lifecycle, Crossplane for cloud resource management, external-dns, aws-load-balancer-controller.


**Layer 4 — Enterprise Services (enterprise bundle):** ArgoCD for GitOps app delivery, Vault for secrets management (Raft HA, multi-tenant, Crossplane-automated policies), Keycloak for identity/SSO (OIDC, MFA, CAC auth, Crossplane-provisioned RDS backend), Mattermost for ChatOps, GitLab + Nexus for DevOps lifecycle, Grafana/Kiali/Tempo for visualization and tracing, Crossplane claims (RDS for Keycloak, Vault policies for tenants).


**Layer 5 — Mission Apps:** Customer workloads deployed via ArgoCD after security approval. Teams get the full platform (mesh, identity, secrets, observability) without managing any of it.


### Why This Matters


The layered model means mission app teams don't think about infrastructure, networking, or security plumbing — they get it all from the platform. When something breaks at Layer 3 (say, an Istio upgrade), the blast radius is contained and I can debug it without touching Layer 4 or 5. The clean layer boundaries also make it possible to version and release each layer independently.


---


## 6. Configuration-as-Code (Kapitan)


### The Problem Kapitan Solves


We have multiple environments (dev, staging-left, staging-right, production) plus per-developer ephemeral clusters. Each needs slightly different config (AWS account, domain, resource sizes, bundle versions) but the same overall structure. Without Kapitan, we'd maintain separate scripts and YAML files per environment — a recipe for drift and human error.


### Inventory Structure


```
jcrs-cac/
├── inventory/
│   ├── targets/                   ← Entry point: one file per cluster
│   │   ├── developers.yml             (shared dev cluster)
│   │   ├── release-test.yml           (release validation)
│   │   └── csanchez-vault-test.yml    (ephemeral test cluster)
│   └── classes/                   ← Reusable config modules
│       ├── defaults/              ← Service defaults (bb-vault.yml, bb-keycloak.yml, ...)
│       ├── environments/          ← AWS account/region settings
│       ├── releases/              ← Bundle version pins (latest.yml)
│       ├── outputs/               ← What files Kapitan generates
│       ├── persistent/            ← Persistent cluster settings (Vault HA, Keycloak RDS)
│       └── jcrse-common.yml       ← Aggregator: includes 20+ default classes
├── templates/                     ← Jinja2 templates → shell scripts + YAML
└── compiled/                      ← Output (one folder per target, not committed)
```


### CaC / IaC Separation


This repo is **configuration only** — zero Terraform, zero raw manifests. This was a deliberate architectural decision based on lessons from the legacy platform (Taurus). When we deploy to classified (high-side) environments, configuration overrides on the high side can't flow back down to the low side. If IaC and CaC are tightly coupled in one repo, this becomes extremely painful. Keeping them separate means:
- Infrastructure scripts live in **kraken** and **jcrs-e**
- Kubernetes manifests live in **leviathan** (as Zarf packages)
- Configuration and environment-specific values live in **jcrs-cac**


```mermaid
graph LR
   subgraph "Input: Target File"
       TARGET["targets/csanchez-vault-test.yml<br/><br/>classes:<br/>  - jcrse-common<br/>  - environments.up-k8s-app-spt<br/>  - releases.latest<br/><br/>parameters:<br/>  env_name: csanchez-vault<br/>  cluster_name: csanchez"]
   end


   subgraph "Class Resolution"
       COMMON["jcrse-common.yml<br/><i>includes 20+ defaults</i>"]
       DEFAULTS["defaults/<br/>bb-vault.yml<br/>bb-keycloak.yml<br/>bb-istio.yml<br/>bb-monitoring.yml<br/>..."]
       ENV["environments/<br/>up-k8s-app-spt.yml<br/><i>AWS account, region</i>"]
       REL["releases/<br/>latest.yml<br/><i>bundle versions</i>"]
   end


   subgraph "Templates"
       TPL["templates/<br/>build.sh<br/>install_core_profile.sh<br/>install_enterprise_profile.sh<br/>bb-inputs.yaml<br/>vault-crossplane.yaml"]
   end


   subgraph "Output"
       OUT["compiled/csanchez-vault-test/<br/>jcrse/<br/>├── build.sh<br/>├── install_core_profile.sh<br/>├── install_enterprise_profile.sh<br/>├── bb-inputs.yaml<br/>└── vault-crossplane.yaml"]
   end


   TARGET --> COMMON
   COMMON --> DEFAULTS
   TARGET --> ENV
   TARGET --> REL
   DEFAULTS -->|"merge parameters"| TPL
   ENV -->|"merge parameters"| TPL
   REL -->|"merge parameters"| TPL
   TPL -->|"Jinja2 render"| OUT


   style TARGET fill:#2f855a,color:#fff
   style OUT fill:#c53030,color:#fff
```


### How Compilation Works


1. **Read target** — loads `inventory/targets/<name>.yml`
2. **Resolve classes** — follows `classes:` list, recursively merging all parameters (20+ default classes)
3. **Merge parameters** — later classes override earlier; target params have highest priority
4. **Render templates** — Jinja2 substitution: `{{ i.release_info.bundle_version }}` → `v0.9.27-test`
5. **Write output** — compiled scripts and YAML files in `compiled/<target>/jcrse/`


### Why This Matters


Kapitan's class inheritance model is what makes the platform manageable. A new developer can create a target file in 5 lines (reference the common class, set an environment, pin a release version, set a cluster name) and get a fully compiled set of deployment scripts. When I need to change a Vault default across all environments, I change one file (`defaults/bb-vault.yml`) and every target picks it up. The alternative — maintaining per-environment scripts by hand — simply doesn't scale.


---


## 7. CI/CD Pipeline


### 7-Stage Pipeline Architecture


The release-automation repo defines a GitLab CI pipeline with **sequential stages**. Stages 2–4 use a **two-jobs-per-stage pattern**: one deployment job (toggled by a boolean variable) and one verification job (always runs). This design means you can deploy only the layers you need and verify everything is healthy before proceeding.


```mermaid
sequenceDiagram
   participant DEV as Developer
   participant GL as GitLab CI
   participant CAC as jcrs-cac
   participant KAP as Kapitan
   participant TF as Terraform (kraken)
   participant ZARF as Zarf/UDS
   participant S3 as S3 Artifacts
   participant EKS as EKS Cluster


   DEV->>GL: Trigger pipeline with toggle variables


   rect rgb(50, 50, 80)
       Note over GL,KAP: Stage 1: PREP
       GL->>CAC: Clone config repo (branch specified by variable)
       GL->>KAP: kapitan compile -t <target>
       KAP-->>GL: Compiled scripts + YAML
   end


   rect rgb(80, 50, 50)
       Note over GL,TF: Stage 2: INFRASTRUCTURE
       GL->>TF: build_infrastructure.sh
       TF-->>GL: VPC, subnets, IAM, KMS, S3
   end


   rect rgb(50, 80, 50)
       Note over GL,EKS: Stage 3: CLUSTER
       GL->>TF: build.sh (kraken Terraform)
       TF-->>EKS: EKS cluster + node groups on STIG'd AMIs
   end


   rect rgb(80, 80, 50)
       Note over GL,EKS: Stage 4: ZARF INIT
       GL->>S3: Download zarf-init package
       GL->>ZARF: zarf_initialize.sh
       ZARF-->>EKS: In-cluster registry + Gitea + Zarf agent
   end


   rect rgb(50, 80, 80)
       Note over GL,EKS: Stage 5: CORE PLATFORM
       GL->>S3: Download core bundle
       GL->>ZARF: install_core_profile.sh
       ZARF-->>EKS: Istio, Kyverno, Prometheus, Neuvector, Crossplane
   end


   rect rgb(80, 50, 80)
       Note over GL,EKS: Stage 6: ENTERPRISE SERVICES
       GL->>S3: Download enterprise bundle
       GL->>ZARF: install_enterprise_profile.sh
       ZARF-->>EKS: Vault, Keycloak, ArgoCD + Crossplane claims
   end


   rect rgb(60, 60, 60)
       Note over GL,EKS: Stage 7: DESTROY (after TTL expires)
       GL->>TF: destroy.sh
       TF-->>EKS: Cluster terminated
   end
```


### Pipeline Toggle Variables


| Variable | Default | What It Controls |
|----------|---------|-----------------|
| `DEPLOY_INFRASTRUCTURE` | `false` | VPC, IAM, S3, KMS via Terraform |
| `DEPLOY_CLUSTER` | `false` | EKS cluster creation via kraken |
| `DEPLOY_ZARF` | `false` | Zarf initialization (in-cluster registry) |
| `DEPLOY_JCRS_CORE` | `false` | Core platform bundle deployment |
| `DEPLOY_UPMS_BUNDLE` | `false` | Enterprise services bundle deployment |
| `JCRS_CAC_VERSION` | `main` | Branch/tag of config repo |
| `JCRS_CAC_TARGET` | `example` | Kapitan target to compile |
| `AUTO_DELETE_IN` | `8 hours` | Cluster TTL (or `never` for persistent) |
| `IS_PERSISTENT` | `false` | Enable Vault HA / Keycloak RDS |


### Why This Matters


- **Toggle-based deployment** is the key pattern. Need to update only Vault? Set `DEPLOY_UPMS_BUNDLE=true`, everything else `false`. The pipeline skips infrastructure and core, deploys only the enterprise bundle. This saves 45+ minutes on a full pipeline run.
- **Verification jobs always run** regardless of whether the deploy job ran. This catches configuration drift — if someone manually changed something in the cluster, verification detects it.
- **Idempotent stages** — every stage can be safely rerun. Terraform won't recreate existing resources, Zarf won't redeploy unchanged packages. This is critical for reliability.
- **Ephemeral clusters auto-delete** after TTL. Developers spin up test clusters that self-destruct in 8 hours. Persistent clusters (staging, production) use `never`. This keeps cloud costs under control.


---


## 8. Package & Bundle Build System


### The Build Pipeline (Leviathan)


Leviathan is the **package factory**. It defines every Zarf package and UDS bundle, builds them via GitLab CI's parallel matrix, and uploads artifacts to S3. The pipeline and deployment are decoupled — builds happen on an internet-connected runner, deployments happen in air-gapped environments.


```mermaid
graph TB
   subgraph "Leviathan Repo"
       BUILD["build.yaml<br/><i>Master version config<br/>for all packages + bundles</i>"]
       SVC["services/<br/>bb-core/ bb-vault/ bb-keycloak/<br/>crossplane/ cluster-autoscaler/<br/>external-dns/ ..."]
       BUNDLES["profile_bundles/<br/>jcrs-core/ jcrs-upms/"]
   end


   subgraph "Build Phase (Internet-Connected)"
       GLCI["GitLab CI<br/><i>Parallel matrix build</i>"]
       ZARF_CREATE["zarf package create<br/><i>Pull images from Iron Bank</i><br/><i>Download Helm charts</i><br/><i>Create .tar.zst archive</i>"]
       UDS_CREATE["uds bundle create<br/><i>Assemble packages into<br/>ordered bundle</i>"]
   end


   subgraph "S3 Artifact Storage"
       S3_PKG["S3: packages/<br/>bb-vault-3.6.1-lv.5.tar.zst<br/>crossplane-vault-claims-v1.22.0-1.tar.zst"]
       S3_BUN["S3: profile_bundles/<br/>uds-bundle-jcrs-core-v0.9.17.tar.zst<br/>uds-bundle-jcrs-upms-v0.9.27.tar.zst"]
   end


   subgraph "Deploy Phase (Air-Gapped)"
       DL["Download from S3"]
       UDS_DEPLOY["uds deploy bundle.tar.zst<br/><i>Push images to in-cluster registry<br/>Deploy Helm charts in order</i>"]
       CLUSTER["EKS Cluster"]
   end


   BUILD -->|"versions"| GLCI
   SVC -->|"package defs"| GLCI
   GLCI --> ZARF_CREATE
   ZARF_CREATE -->|"upload"| S3_PKG
   BUNDLES -->|"bundle defs"| UDS_CREATE
   S3_PKG -->|"referenced by"| UDS_CREATE
   UDS_CREATE -->|"upload"| S3_BUN
   S3_BUN --> DL
   DL --> UDS_DEPLOY
   UDS_DEPLOY --> CLUSTER


   style BUILD fill:#975a16,color:#fff
   style S3_BUN fill:#c53030,color:#fff
   style CLUSTER fill:#2b6cb0,color:#fff
```


### Version Flow


```
build.yaml (defines what gets built and at what version)
   ↓
Zarf packages built → uploaded to S3
   ↓
UDS bundles assembled from specific package versions → uploaded to S3
   ↓
jcrs-cac/inventory/classes/releases/latest.yml (pins what gets deployed)
   ↓
Kapitan compiles → deployment scripts reference exact bundle versions
```


### Bundle Architecture


| Order | Bundle | Contents | Depends On |
|-------|--------|----------|------------|
| 1st | **jcrs-core** (core bundle) | Istio, monitoring, cert-manager, Kyverno, Crossplane, Neuvector | None — this is the foundation |
| 2nd | **jcrs-upms** (enterprise bundle) | Keycloak, Vault, ArgoCD, Crossplane claims, visualization | Core bundle must be deployed first |


The core bundle **must** be deployed before the enterprise bundle. Core provides the service mesh, certificate infrastructure, and Crossplane providers that enterprise services depend on.


### Why This Matters


- **build.yaml is the single source of truth** for every package version. Version bumping is a one-file change with cascading effects — bump a package version in build.yaml, rebuild, and the new version flows through to bundles, then to deployment config.
- **Build and deploy are fully decoupled.** Packages are built once on an internet-connected runner and can be deployed to any number of air-gapped clusters. The S3 bucket acts as the artifact bridge.
- **Two package types exist**: BB-generated packages (created from the Big Bang umbrella chart using `generate-big-bang-zarf-package`) and custom Zarf packages (with explicit `zarf.yaml`). Understanding this distinction matters when troubleshooting or adding new services.


---


## 9. Networking Architecture


The platform handles four distinct traffic patterns. The network design reflects the security requirements of a DoD environment — defense in depth at every hop.


```mermaid
graph TB
   subgraph "External"
       USER["User Browser"]
       ADMIN["Admin / Installer<br/>(Bastion SSH)"]
   end


   subgraph "Entry Points"
       AG["AppGate SDP"]
       R53["Route53 DNS"]
   end


   subgraph "Parent Org VPC"
       FW["Fortigate Firewalls"]
       NAT["NAT Gateway"]
       TGW["Transit Gateway"]
   end


   subgraph "Cluster VPC"
       subgraph "Ingress"
           PUB_NLB["Public NLB<br/><i>:443 → :8443</i>"]
           PASS_NLB["Passthrough NLB<br/><i>:443 → :8443</i>"]
           PUB_GW["Istio Public Gateway<br/><i>TLS termination + mTLS</i>"]
           PASS_GW["Istio Passthrough Gateway<br/><i>TCP forward only</i>"]
       end


       subgraph "Cluster"
           EKS_API["EKS API Server<br/><i>Internal endpoint only</i>"]
           PODS["Application Pods<br/><i>Istio sidecar mTLS</i>"]
           KC_POD["Keycloak<br/><i>Handles own TLS</i>"]
           VAULT_POD["Vault<br/><i>Handles own TLS</i>"]
       end
   end


   USER --> AG
   AG --> R53
   R53 -->|"most apps"| PUB_NLB
   R53 -->|"keycloak/vault"| PASS_NLB
   PUB_NLB -->|"via TGW"| PUB_GW
   PASS_NLB -->|"via TGW"| PASS_GW
   PUB_GW -->|"mTLS"| PODS
   PASS_GW -->|"TCP passthrough"| KC_POD
   PASS_GW -->|"TCP passthrough"| VAULT_POD


   ADMIN --> AG --> FW --> TGW
   TGW -->|"SSH to bastion"| EKS_API


   PODS -->|"egress"| TGW
   TGW --> NAT


   style PUB_NLB fill:#2b6cb0,color:#fff
   style PASS_NLB fill:#2b6cb0,color:#fff
   style PUB_GW fill:#2f855a,color:#fff
   style PASS_GW fill:#975a16,color:#fff
   style EKS_API fill:#c53030,color:#fff
```


### Four Traffic Patterns


**1. Public Application Ingress (most services):**
Route53 → Public NLB (:443) → worker node :8443 → Istio Public Gateway → **TLS terminated, re-encrypted as mTLS** through the mesh → istio-proxy sidecar → app container.


**2. Passthrough Ingress (Keycloak, Vault):**
Route53 → Passthrough NLB (:443) → worker node :8443 → Istio Passthrough Gateway → **TCP forwarded directly** (no TLS termination) → app pod handles its own TLS. This is required because Keycloak and Vault need to handle client certificate authentication / PKI directly.


**3. Kubernetes API Access:**
Internal endpoint only — **never exposed to the internet**. Access is through bastion host: AppGate → parent org → Transit Gateway → bastion SSH → `kubectl` to internal EKS API. Engineers use `sshuttle` for routing.


**4. Cluster Egress:**
Cluster VPC → Transit Gateway → parent org VPC → NAT Gateway → internet. Each cluster sits on its own VPC with its own CIDR; egress routes through a shared Transit Gateway.


### IMDS and IRSA Security


We lock down **IMDSv2** with hop count = 1 on all worker node launch templates. This blocks pod-level access to instance metadata, which means **every pod must use IRSA** (IAM Roles for Service Accounts) for any AWS API access — including cluster services like the node join agent, EBS CSI driver, EFS CSI driver, cluster autoscaler, load balancer controller, and external-dns.


### Why This Matters


The two-gateway pattern (public vs passthrough) is an architectural decision I can explain in detail. Most services get TLS terminated at the mesh gateway, which gives us centralized certificate management and uniform mTLS. But Keycloak and Vault need end-to-end TLS because they support direct client certificate authentication — if we terminated TLS at the gateway, we'd lose the client cert. This is a security tradeoff that shows understanding of both networking and application requirements.


---


## 10. Security Architecture


### Defense-in-Depth


Security isn't a single layer — it's baked into every level of the stack.


```mermaid
graph TB
   subgraph "Image Supply Chain"
       IB["Iron Bank Images<br/><i>DoD hardened containers</i><br/><i>Scanned, signed, STIG'd</i>"]
   end


   subgraph "Host Hardening"
       AMI["STIG'd AMIs<br/><i>RHEL 8/9 · ~90% DISA STIG</i><br/><i>Packer + Ansible + OSCAP</i>"]
   end


   subgraph "Identity & Access"
       KC2["Keycloak<br/><i>OIDC/SSO · MFA · CAC auth</i><br/><i>RDS backend via Crossplane</i>"]
       AUTH2["Authservice<br/><i>Envoy-based SSO proxy</i><br/><i>Transparent auth for all services</i>"]
       IRSA2["IRSA<br/><i>Pod-level AWS IAM</i><br/><i>IMDSv2 blocked (hop=1)</i>"]
   end


   subgraph "Secrets Management"
       VAULT2["Vault<br/><i>Multi-tenant · Raft HA</i><br/><i>Crossplane-automated policies</i>"]
   end


   subgraph "Network Security"
       ISTIO2["Istio mTLS<br/><i>All pod-to-pod traffic encrypted</i>"]
       NP["Network Policies<br/><i>Kyverno + Calico enforcement</i>"]
   end


   subgraph "Policy Enforcement"
       KYV2["Kyverno<br/><i>Admission control</i><br/><i>Image registry restrictions</i><br/><i>Resource limits enforcement</i>"]
   end


   subgraph "Runtime Security"
       NEU2["Neuvector<br/><i>Container process/file monitoring</i><br/><i>Network segmentation</i>"]
   end


   IB --> AMI --> KC2
   KC2 --> AUTH2
   AUTH2 --> IRSA2
   IRSA2 --> VAULT2
   VAULT2 --> ISTIO2
   ISTIO2 --> NP
   NP --> KYV2
   KYV2 --> NEU2


   style IB fill:#1a365d,color:#fff
   style AMI fill:#553c9a,color:#fff
   style VAULT2 fill:#c53030,color:#fff
   style ISTIO2 fill:#2f855a,color:#fff
   style KYV2 fill:#975a16,color:#fff
   style NEU2 fill:#2b6cb0,color:#fff
```


### Security Components


| Component | What It Does | Key Detail |
|-----------|-------------|------------|
| **Iron Bank** | Hardened container images | All images from `registry1.dso.mil/ironbank/` — DoD-scanned, signed, STIG'd |
| **STIG'd AMIs** | Hardened node OS | RHEL 8/9 via Packer + Ansible, ~90% DISA STIG compliance, OSCAP report at build time |
| **Keycloak** | Identity provider | OIDC/SSO, MFA, CAC smart card auth. RDS backend provisioned by Crossplane |
| **Authservice** | SSO proxy | Envoy-based transparent auth injected via Istio — services don't implement auth themselves |
| **Vault** | Secrets management | Multi-tenant with per-team policies automated via Crossplane XRDs. Raft HA for persistent clusters |
| **Istio** | Service mesh | Automatic mTLS on all pod-to-pod traffic. Zero-trust networking |
| **Kyverno** | Policy engine | Admission control at the API server: blocks non-Iron Bank images, enforces resource limits and labels |
| **Neuvector** | Runtime security | Container process/file monitoring, vulnerability scanning, network micro-segmentation |
| **IRSA** | Pod IAM roles | IMDSv2 locked down (hop=1). Every pod authenticates to AWS via service account, not instance profile |


### Why This Matters


This is a **zero-trust architecture**. Istio mTLS means every service-to-service call is encrypted and mutually authenticated — even within the same cluster. Kyverno blocks any image not from Iron Bank at the admission controller level — it never even gets scheduled. Vault ensures secrets are never stored in Git. The STIG'd AMIs mean the host OS meets DoD baselines before a single container runs. When I talk about security, I can trace the trust chain from the container image provenance (Iron Bank) through the host OS (STIG'd AMI) through the network (Istio mTLS) through access control (Keycloak + Authservice) through secrets (Vault) to runtime monitoring (Neuvector).


---


## 11. Crossplane & Infrastructure Automation


### The Problem


Without Crossplane, every time a new application team needs a Vault policy or an RDS database, the platform team has to manually provision it. This doesn't scale when you have multiple tenants.


### How It Works


Crossplane extends Kubernetes so that cloud resources (Vault policies, RDS instances, S3 buckets) can be managed as Kubernetes custom resources. Teams declare what they need in YAML, and Crossplane reconciles it.


| Crossplane Concept | What It Does | Example |
|--------------------|-------------|---------|
| **XRD** (CompositeResourceDefinition) | Defines a new custom resource type | Creates a `VaultPolicy` kind in the K8s API |
| **Composition** | Maps the custom resource to actual cloud API calls | VaultPolicy claim → Vault HTTP API `POST /v1/sys/policies` |
| **ProviderConfig** | Auth config for the cloud provider | Vault token or AWS IRSA credentials |
| **Claim** | The resource request a team creates | "Create a policy named 'admin' in Vault" |


```mermaid
graph LR
   subgraph "Configuration (jcrs-cac)"
       TARGET["Target file defines<br/>Vault policies per team:<br/>- name: admin<br/>  path: '*'<br/>  capabilities: [read,list]"]
   end


   subgraph "Kapitan"
       YAML["vault-crossplane.yaml<br/><i>Compiled claim definitions</i>"]
   end


   subgraph "Deployment"
       UDS_D["uds deploy --set<br/>CUSTOM_CLAIM_INPUT_FILE=<br/>vault-crossplane.yaml"]
   end


   subgraph "Kubernetes Cluster"
       XRD["XRD: XVaultPolicy<br/><i>Schema definition</i>"]
       COMP["Composition<br/><i>Maps claim → Vault API</i>"]
       CLAIM["VaultPolicy Claim<br/><i>Created by deployment</i>"]
       PROV["Vault Provider<br/><i>Authenticated via SA</i>"]
   end


   subgraph "Vault"
       POLICY["Policy Created<br/>via Vault HTTP API"]
   end


   TARGET -->|"compile"| YAML
   YAML -->|"passed to"| UDS_D
   UDS_D -->|"creates"| CLAIM
   XRD -->|"validates"| CLAIM
   CLAIM -->|"reconciled by"| COMP
   COMP -->|"calls via"| PROV
   PROV -->|"HTTP API"| POLICY


   style TARGET fill:#2f855a,color:#fff
   style CLAIM fill:#2b6cb0,color:#fff
   style POLICY fill:#c53030,color:#fff
```


### Use Cases


| Use Case | Mechanism | What Gets Created |
|----------|-----------|------------------|
| **Vault policies** | XVaultPolicy XRD + Composition | ACL policies for each tenant team — automated per-cluster |
| **Keycloak database** | Crossplane AWS provider + Claims | RDS PostgreSQL instance as Keycloak's backend |
| **S3 buckets** | Crossplane AWS provider + Claims | Per-team artifact storage buckets |


### Why This Matters


Crossplane turns infrastructure provisioning into a Kubernetes-native, declarative, GitOps-compatible workflow. Teams don't need AWS console access or Vault admin privileges. They define what they need in their Kapitan target, the pipeline compiles it into claim YAML, and Crossplane reconciles it. The DeploymentRuntimeConfig handles TLS certificate mounting so the Crossplane provider can securely communicate with Vault. This is a key part of our multi-tenancy story — platform self-service at scale.


---


## 12. Environment Topology & GitOps Lifecycle


### Environment Promotion


```mermaid
graph LR
   subgraph "Development"
       DEV["Dev Account<br/><i>Ephemeral + persistent clusters</i>"]
       DEVCLUSTER["Shared dev cluster<br/><i>Always running</i>"]
       EPHEMERAL["Ephemeral clusters<br/><i>8h TTL · per-developer</i>"]
   end


   subgraph "Staging"
       LEFT["Left cluster<br/><i>Pre-production validation</i>"]
       RIGHT["Right cluster<br/><i>Pre-production validation</i>"]
   end


   subgraph "Production"
       PROD["Production<br/><i>Mission operations</i>"]
   end


   subgraph "Artifact Sources"
       S3ART["S3 Artifact Storage<br/><i>Zarf packages + UDS bundles</i>"]
       REG["Iron Bank Registry<br/><i>Hardened container images</i>"]
   end


   S3ART -->|"packages"| DEV
   REG -->|"images baked in"| S3ART
   DEV --> DEVCLUSTER
   DEV --> EPHEMERAL
   DEVCLUSTER -->|"promote"| LEFT
   DEVCLUSTER -->|"promote"| RIGHT
   LEFT -->|"validate"| PROD
   RIGHT -->|"validate"| PROD


   style DEV fill:#2f855a,color:#fff
   style LEFT fill:#975a16,color:#fff
   style RIGHT fill:#975a16,color:#fff
   style PROD fill:#c53030,color:#fff
```


### Environment Types


| Environment | Purpose | Cluster Lifetime |
|-------------|---------|-----------------|
| **Development** | Feature development, integration testing | Ephemeral (8h auto-delete) + persistent shared cluster |
| **Staging Left/Right** | Pre-production validation with full stack | Persistent |
| **Production** | Mission operations | Persistent (Vault HA, Keycloak RDS) |


### Release Cadence


- **Friday:** Release kickoff — tag repos, trigger package builds
- **Monday:** Deploy to staging (left/right) for validation
- **Tuesday:** Promote to production


### End-to-End GitOps Flow


This is how a change flows from a developer's keyboard to a running cluster.


```mermaid
sequenceDiagram
   participant DEV as Developer
   participant GIT as Git (config repo)
   participant CI as GitLab CI Pipeline
   participant KAP as Kapitan
   participant CONT as Deploy Container
   participant AWS as AWS GovCloud
   participant K8S as EKS Cluster
   participant ZARF as Zarf/UDS
   participant FLUX as FluxCD


   DEV->>GIT: 1. Push config change via MR
   GIT->>CI: 2. Pipeline triggered
   CI->>KAP: 3. Compile Kapitan target
   KAP-->>CI: 4. Compiled scripts + YAML


   CI->>CONT: 5. Run deploy container
   CONT->>AWS: 6. Terraform: VPC, EKS, IAM
   AWS-->>K8S: 7. Cluster ready


   CI->>ZARF: 8. Initialize Zarf (in-cluster registry + Gitea)
   CI->>ZARF: 9. Deploy core bundle from S3
   ZARF->>K8S: 10. Push images → registry, charts → Gitea
   K8S->>FLUX: 11. FluxCD reconciles HelmReleases
   FLUX->>K8S: 12. Istio, Kyverno, Prometheus, Neuvector online


   CI->>ZARF: 13. Deploy enterprise bundle from S3
   ZARF->>K8S: 14. Vault, Keycloak, ArgoCD deployed
   K8S->>K8S: 15. Crossplane reconciles VaultPolicies, RDS


   K8S-->>CI: 16. Health checks pass
   CI-->>DEV: 17. Deployment complete
```


### In-Cluster GitOps (FluxCD)


Once Zarf deploys packages, **FluxCD takes over** inside the cluster for continuous reconciliation:


```mermaid
graph TB
   subgraph "Zarf Namespace"
       REG["In-Cluster Registry<br/><i>127.0.0.1:31999</i><br/>All container images"]
       GITEA["In-Cluster Gitea<br/><i>Git server</i><br/>Big Bang chart repo"]
   end


   subgraph "Flux-System"
       SRC["source-controller<br/><i>Watches GitRepository CRDs</i>"]
       HELM_C["helm-controller<br/><i>Reconciles HelmRelease CRDs</i>"]
   end


   subgraph "Big Bang Namespace"
       BB_HR["HelmRelease: bigbang<br/><i>Umbrella chart</i>"]
       CM["ConfigMaps<br/>istio-overrides<br/>kyverno-overrides<br/>bb-inputs-overrides"]
   end


   subgraph "Service Namespaces"
       ISTIO_NS["istio-system"]
       KYV_NS["kyverno"]
       NEU_NS["neuvector"]
       PROM_NS["monitoring"]
       KC_NS["keycloak"]
       VAULT_NS["vault"]
   end


   GITEA -->|"fetch chart"| SRC
   SRC -->|"artifact ready"| HELM_C
   CM -->|"values"| BB_HR
   HELM_C -->|"reconcile"| BB_HR
   BB_HR -->|"creates sub-HelmReleases"| ISTIO_NS
   BB_HR --> KYV_NS
   BB_HR --> NEU_NS
   BB_HR --> PROM_NS
   BB_HR --> KC_NS
   BB_HR --> VAULT_NS
   REG -->|"images pulled from"| ISTIO_NS


   style REG fill:#2b6cb0,color:#fff
   style GITEA fill:#2f855a,color:#fff
   style BB_HR fill:#c53030,color:#fff
```


### Key Architectural Insight


The Big Bang umbrella chart **does not directly deploy applications**. It creates FluxCD resources (GitRepository + HelmRelease) for each component. FluxCD then independently reconciles each one. This gives us:
- **Selective upgrades** — update Istio without touching Vault
- **Failure isolation** — if Neuvector fails to reconcile, Keycloak is unaffected
- **Drift detection** — if someone manually changes something in-cluster, FluxCD reverts it


### Configuration Override Precedence


Values merge in this order (later overrides earlier):
1. Big Bang chart defaults
2. Package-level overrides (`gen-*.yaml` — baked into Zarf packages at build time)
3. Deploy-time overrides (`bb-inputs.yaml` — compiled by Kapitan from environment config)
4. Individual package ConfigMaps/Secrets


### Why This Matters


GitOps means **every environment change starts as a merge request**. There's a full audit trail. The pipeline is the only path to production — no SSH-and-fix. Inside the cluster, FluxCD provides continuous reconciliation, so the cluster always converges to the declared state. The in-cluster registry and Gitea enable all of this to work in air-gapped environments where there's no access to external registries or repos. Understanding this dual-loop (GitLab CI outer loop + FluxCD inner loop) is key to explaining the platform's reliability model.


---


## 13. Quick Reference


### Technology Stack


| Category | Components |
|----------|-----------|
| **Cloud** | AWS GovCloud, EKS, S3, KMS, RDS, Route53, IAM, VPC, Transit Gateway |
| **Infrastructure-as-Code** | Terraform, Packer, Ansible |
| **Configuration Management** | Kapitan (Jinja2 + YAML class inheritance) |
| **Packaging** | Zarf (air-gap), UDS (orchestration), Helm (templating) |
| **GitOps** | FluxCD (in-cluster reconciliation), ArgoCD (app delivery) |
| **Service Mesh** | Istio (automatic mTLS, traffic management, ingress gateways) |
| **Identity** | Keycloak (OIDC/SSO/MFA/CAC), Authservice (Envoy SSO proxy) |
| **Secrets** | HashiCorp Vault (Raft HA, multi-tenant, Crossplane-automated) |
| **Policy** | Kyverno (Kubernetes admission control) |
| **Security** | Neuvector (runtime), Iron Bank (images), STIG'd AMIs (hosts) |
| **Observability** | Prometheus, Grafana, Loki, Alloy, Tempo, Kiali |
| **Cloud Resources** | Crossplane (XRDs, Compositions, Claims) |
| **CI/CD** | GitLab CI/CD (7-stage release pipeline) |
| **Collaboration** | Mattermost, GitLab |


### Repository One-Liners


| Repo | What It Does |
|------|-------------|
| `jcrs-cac` | Kapitan config → compiled deployment scripts per environment |
| `leviathan` | Builds Zarf packages + UDS bundles → uploads to S3 |
| `release-automation` | 7-stage GitLab CI pipeline that orchestrates everything |
| `kraken` | Terraform modules for EKS + VPC + IAM |
| `jcrs-e` | Docker image with all deployment tools (kubectl, helm, zarf, terraform, kapitan) |
| `jcrs-e-docs` | Customer-facing architecture, networking, and onboarding documentation |
| `jcrse-zarf-init` | Custom Zarf init package (in-cluster registry + agent) |
| `image-builder` | STIG'd RHEL 8/9 AMIs via Packer + Ansible (~90% DISA STIG) |
| `team-automation` | Automation bots for MR validation, registry cleanup, Renovate |


### Pipeline Stages at a Glance


```
1. PREP         → Clone config repo, compile Kapitan target
2. INFRA        → Terraform: VPC, IAM, S3, KMS
3. CLUSTER      → Terraform (kraken): EKS + STIG'd node groups
4. ZARF INIT    → In-cluster registry + Gitea + Zarf agent
5. CORE         → UDS deploy: Istio, Kyverno, Prometheus, Neuvector, Crossplane
6. ENTERPRISE   → UDS deploy: Vault, Keycloak, ArgoCD, Crossplane claims
7. DESTROY      → Terraform destroy (after TTL expires)
```


---


*All Mermaid diagrams render in VS Code (Mermaid extension), GitLab markdown preview, or [mermaid.live](https://mermaid.live).*



