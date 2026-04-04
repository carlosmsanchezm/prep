# Architecture Practice: Nightwatch RKE2 Platform (NTConcepts)

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the Nightwatch infrastructure from memory — focus on RKE2 cluster setup, AWS integration, and how you operated it
2. Narrate as if Andy asked: "You mentioned RKE2 — walk me through how you set that up"
3. Time yourself: 8-10 minutes
4. Do NOT get lost in application-level details (Kubeflow workflows, auth chains). Andy is a DevOps hiring manager — he cares about the INFRASTRUCTURE, not the ML pipelines.

---

## GAPS — Review Before Each Drawing Attempt

> Add gaps here after each attempt. Read this FIRST before redrawing.

*(empty — fill in after your first attempt)*

---

## Coaching: How to Present This

### The DevOps Focus

Andy cares about HOW you built and operated the K8s infrastructure — not about Kubeflow's notebook UI or the data scientist's auth flow. Focus on:

| Andy cares about (draw this) | Andy doesn't need (mention briefly) |
|------------------------------|--------------------------------------|
| RKE2 bootstrap — air-gap binary install, config, HA | Kubeflow dashboard features |
| Node groups — control plane, CPU, GPU ASGs | KServe, Knative, KF Pipelines internals |
| AWS integration — IRSA, ECR, S3, Secrets Manager | oauth2-proxy → Keycloak auth chain steps |
| Networking — VPC, private subnets, NLB entry point | TensorBoard, MLflow |
| GitOps — ArgoCD syncing from local Git | Data scientist notebook workflow |
| Storage — EFS, RDS, how PVs connect to AWS | Kubeflow pipeline artifact storage |
| registries.yaml — how images are pulled air-gapped | |
| Cluster Autoscaler — how nodes scale | |
| Secrets — External Secrets Operator → Secrets Manager | |

### Opening Line
"At NTConcepts, I built and operated an RKE2 Kubernetes cluster on AWS — air-gapped, three control plane nodes for HA, CPU and GPU worker pools with auto-scaling, full GitOps with ArgoCD. The workload was an ML platform for twelve data scientists, but the infrastructure story is what matters: how I bootstrapped RKE2 in a disconnected environment, integrated it with AWS services, and kept it running."

### Drawing Order (DevOps-focused)

**Step 1 — Draw the AWS foundation (bottom of whiteboard):**

```
┌─── AWS Cloud (us-east-1) ────────────────────────────────────────┐
│                                                                    │
│  ┌── Core AWS Services ─────────────────────────────────────────┐  │
│  │  ECR (container images)    S3 (terraform state, artifacts)   │  │
│  │  Secrets Manager (DB passwords, API keys)                    │  │
│  │  IAM (OIDC provider, IRSA roles for pods)                   │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌── VPC ───────────────────────────────────────────────────────┐  │
│  │  Public Subnet:  NLB (only entry point from outside)         │  │
│  │  Private Subnets: everything else                            │  │
│  │                                                              │  │
│  │  Managed Data Services:                                      │  │
│  │    RDS PostgreSQL (3 databases: ArgoCD, Keycloak, Kubeflow)  │  │
│  │    EFS (shared storage mounted by pods)                      │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

Say: "Everything runs on AWS. ECR stores container images — in air-gap, we pre-push images here and RKE2 pulls from it via registries.yaml. S3 holds Terraform state and pipeline artifacts. Secrets Manager stores database passwords and API keys — External Secrets Operator syncs them into the cluster as K8s Secrets. IAM provides IRSA — pods assume IAM roles via service accounts instead of using instance credentials.

VPC has public and private subnets. The NLB in the public subnet is the ONLY entry point from outside. Everything else — the cluster, databases, storage — lives in private subnets. RDS PostgreSQL backs three services: ArgoCD, Keycloak, and Kubeflow. EFS provides shared storage that multiple pods mount simultaneously."

**Step 2 — Draw the RKE2 cluster (center — this is the main event):**

```
┌─── RKE2 Kubernetes Cluster (private subnets) ────────────────────┐
│                                                                    │
│  ┌── Control Plane (ASG: 3 nodes) ──────────────────────────────┐  │
│  │  m5a.large × 3                                               │  │
│  │  rke2-server with embedded etcd                              │  │
│  │  HA: 3 nodes = etcd quorum survives 1 node loss             │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌── Worker Nodes ──────────────────────────────────────────────┐  │
│  │                                                              │  │
│  │  CPU ASG: m5a.2xlarge                GPU ASG: g4dn.xlarge    │  │
│  │  (general workloads)                 (ML training)           │  │
│  │                                      + NVIDIA GPU Operator   │  │
│  │                                      (auto driver install)   │  │
│  │                                                              │  │
│  │  Both managed by Cluster Autoscaler                          │  │
│  │  (scales based on pending pods)                              │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌── Infrastructure Services (what I deployed + managed) ───────┐  │
│  │  ArgoCD          — GitOps: syncs all manifests from Git      │  │
│  │  Istio           — service mesh + ingress gateway            │  │
│  │  Cluster Autoscaler — scales node ASGs                       │  │
│  │  External Secrets — syncs Secrets Manager → K8s Secrets      │  │
│  │  Keycloak        — SSO/identity for all services             │  │
│  │  Monitoring      — Prometheus + Grafana + Loki               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
│  ┌── Application Workloads (ran on top — not my focus) ─────────┐  │
│  │  Kubeflow (notebooks, pipelines, model serving)              │  │
│  │  "ML platform for 12 data scientists — tripled throughput"   │  │
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

Say: "The cluster. Three control plane nodes — m5a.large running rke2-server with embedded etcd. Three gives us quorum — survives one node loss. No external etcd cluster to manage.

Worker nodes in two ASGs. CPU pool on m5a.2xlarge for general workloads. GPU pool on g4dn.xlarge with the NVIDIA GPU Operator — when a new GPU node joins, the operator auto-detects the hardware and installs the right driver. No manual CUDA setup. Both pools managed by Cluster Autoscaler — it watches for pending pods and scales the ASG up or down.

Infrastructure services that I deployed and managed: ArgoCD for GitOps — everything syncs from a Git repo, no manual kubectl. Istio for the service mesh and ingress gateway — all traffic enters through Istio. External Secrets Operator syncs credentials from AWS Secrets Manager into K8s Secrets. Keycloak for SSO. Prometheus, Grafana, Loki for monitoring.

On top of all this, the data science team ran Kubeflow — notebooks, pipelines, model serving. But that's the application layer. The infrastructure underneath is what I owned."

**Step 3 — Draw the two key flows (arrows — pick ONE based on what Andy asks):**

**Flow A: GitOps deployment (if Andy asks "how do you deploy?")**

```
[DevOps Engineer] → git push → [argoflow Git Repo]
                                       ↓
                              [ArgoCD watches repo]
                                       ↓
                        [ArgoCD syncs to cluster]
                                       ↓
                    deploys: Istio, Keycloak, Kubeflow, Monitoring
                                       ↓
                    images pulled from ECR (via registries.yaml)
```

Say: "Pure GitOps. I push manifests to the argoflow Git repo. ArgoCD detects the change, syncs to the cluster — kubectl apply under the hood but automated. If someone manually changes something in the cluster, ArgoCD detects drift and reverts it. Images come from ECR — registries.yaml tells containerd to pull from ECR instead of Docker Hub."

**Flow B: Node scaling (if Andy asks "how does scaling work?")**

```
[New workload requests GPU] → Pod goes Pending (no GPU node available)
                                       ↓
                    [Cluster Autoscaler detects pending pod]
                                       ↓
                    [Assumes IAM role via IRSA]
                                       ↓
                    [Increases GPU ASG desired count]
                                       ↓
                    [New g4dn node joins cluster]
                                       ↓
                    [NVIDIA Operator installs GPU drivers]
                                       ↓
                    [Pod schedules → workload runs]
                                       ↓
                    [Workload completes → Autoscaler scales down]
```

Say: "When a workload needs a GPU and none's available, the pod goes Pending. Cluster Autoscaler sees it, assumes an IAM role via IRSA, and bumps the ASG desired count. New g4dn node launches, NVIDIA Operator installs drivers automatically, pod schedules. When the workload finishes and no more GPU pods are pending, Autoscaler scales the node back down. Nodes only exist when there's work — keeps costs controlled."

### What to Emphasize (DevOps perspective)

1. **RKE2 air-gap bootstrap** — "One binary, embedded etcd, runs disconnected. registries.yaml redirects all image pulls to ECR."
2. **AWS integration via IRSA** — "Pods don't use instance credentials. Each service account maps to an IAM role — least-privilege at the pod level."
3. **GitOps with ArgoCD** — "No manual kubectl. Everything in Git. Drift detected and reverted automatically."
4. **Infrastructure as code** — "Terraform for VPC, subnets, ASGs, RDS, EFS. Cluster bootstrapped via Ansible. Services deployed via ArgoCD."
5. **Monitoring** — "Prometheus for metrics, Grafana for dashboards, Loki for logs. Full observability without internet."
6. **Result** — "Tripled throughput" — but frame it as an infrastructure win: "The platform I built enabled twelve data scientists to self-serve GPU access without tickets. Tripled their throughput."

### Component Deep-Dive Prep

**RKE2 Bootstrap (know this cold — Andy asked about it):**

| Step | What happens | Air-gap detail |
|------|-------------|----------------|
| 1. Transfer binary | Download `rke2.linux-amd64` on connected side, transfer to air-gapped host | Binary + images tarball via diode or USB |
| 2. Place images | Put images tarball at `/var/lib/rancher/rke2/agent/images/` | Pre-loaded — no internet pull needed |
| 3. Configure | Write `/etc/rancher/rke2/config.yaml` — server URL, token, node labels | Ansible template renders this per node |
| 4. Configure registry | Write `/etc/rancher/rke2/registries.yaml` — point to ECR/local registry | All image pulls redirected to local |
| 5. Start server | `systemctl enable --now rke2-server` on first control plane node | Embedded etcd starts, API server comes up |
| 6. Join servers | Same on nodes 2 and 3 — they join via port 9345 with the shared token | etcd quorum forms at 3 nodes |
| 7. Join agents | `systemctl enable --now rke2-agent` on worker nodes | Workers register with API server |
| 8. Verify | `/var/lib/rancher/rke2/bin/kubectl get nodes` | All nodes Ready |

**registries.yaml (know this file — it's how air-gap works):**
```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://account-id.dkr.ecr.us-east-1.amazonaws.com"
  "ghcr.io":
    endpoint:
      - "https://account-id.dkr.ecr.us-east-1.amazonaws.com"
configs:
  "account-id.dkr.ecr.us-east-1.amazonaws.com":
    auth:
      # ECR auth handled by IAM role on the node
```
"This file tells containerd: when something requests an image from docker.io or ghcr.io, redirect the pull to our ECR. The images are pre-pushed to ECR on the connected side. No internet access needed from inside the cluster."

**RKE2 Ports (memorize):**

| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 9345 | TCP | RKE2 supervisor (agent/server join) |
| 10250 | TCP | kubelet metrics |
| 2379-2380 | TCP | etcd client + peer (server nodes only) |
| 8472 | UDP | VXLAN (Canal CNI) |

**IRSA (IAM Roles for Service Accounts) — how pods get AWS access:**
1. OIDC provider configured in IAM — trusts the cluster's service account tokens
2. IAM role created with a trust policy: "only pods with service account X in namespace Y can assume this role"
3. Pod spec includes `serviceAccountName: my-sa` — K8s injects a token
4. AWS SDK in the pod exchanges the token for temporary IAM credentials
5. Result: pod-level least-privilege. Cluster Autoscaler has a role that can modify ASGs. External Secrets has a role that can read Secrets Manager. Neither can do the other's job.

"This replaces putting AWS credentials in environment variables or using instance profiles where every pod on the node gets the same permissions. IRSA means each pod gets only the AWS access it needs."

**External Secrets Operator — how secrets flow from AWS to pods:**
1. ExternalSecret CRD references a Secrets Manager entry: "get the secret named `prod/rds/password`"
2. Operator reads it from Secrets Manager (using its own IRSA role)
3. Creates a native K8s Secret with the value
4. Pod mounts the K8s Secret as an env var or file
5. Operator auto-refreshes when the source changes
"No secrets in Git. No manual creation. One source of truth in Secrets Manager, automatically synced to the cluster."

### Tradeoffs to Know

**"Why RKE2 over EKS?"**
"On-prem, air-gapped, no AWS API access from inside the cluster. EKS requires internet for the managed control plane. RKE2 bundles everything — one binary, embedded etcd, runs disconnected. Plus FIPS mode and CIS hardening built-in."

**"Why RKE2 over K3s?"**
"K3s is lighter but trades features — no FIPS, sqlite instead of etcd by default, less enterprise support. RKE2 is CIS hardened, FIPS-ready, designed for government workloads."

**"Why embedded etcd instead of external?"**
"Simpler operations — no separate etcd cluster to manage, monitor, back up. RKE2 handles etcd lifecycle automatically. For three control plane nodes, embedded etcd is the recommended approach. External etcd makes sense at much larger scale or when you need etcd shared across clusters."

**"Why ArgoCD over FluxCD?"**
"ArgoCD gives a UI — operators can see sync status, health, drift without kubectl. In a classified environment where not everyone has cluster access, that visibility matters."

**"Why NVIDIA GPU Operator instead of pre-installing drivers?"**
"Operator auto-detects GPU hardware and installs the right driver. New node type or driver upgrade? Operator handles it. Pre-installing means rebuilding AMIs for every driver change."

**"What would you change?"**
"I'd add admission policies from the start — Kyverno or OPA. We had cases where pods were deployed with no resource limits, consuming all GPU memory. Policy enforcement at the API server would catch that before it affects other workloads."

### Bridging to Anduril

"This is exactly what your aircraft network deployment could look like. RKE2 runs air-gapped — one binary, no internet dependency. You'd transfer the binary and images via diode, Ansible bootstraps the nodes, registries.yaml points to your local Nexus instead of ECR, ArgoCD syncs from local GitLab. Start with a single-node for testing, prove it works, then scale to HA. I've done every step of this."

---

## Answer Keys

- **Full architecture diagram (all components):** `ntconcepts-answers.md` Chart 3 — use this to study ALL components including the application layer
- **Whiteboard layering guide:** `ntconcepts-answers.md` Chart 3 whiteboard section — 4 layers to draw progressively
- **How to present this system:** this file's coaching section above (DevOps-focused)
- **Related:** `anduril-scenarios.md` Scenario 4 + `anduril-k8s-migration-pitch.md`
