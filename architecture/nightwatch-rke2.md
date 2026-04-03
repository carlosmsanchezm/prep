# Architecture Practice: Nightwatch RKE2 Platform (NTConcepts)

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the Nightwatch architecture from memory — RKE2 cluster, AWS services, auth flow, GPU scheduling
2. Narrate as if Andy asked: "You mentioned RKE2 — walk me through what you built"
3. Time yourself: 8-10 minutes

---

## Coaching: How to Present This

### Opening Line
"At NTConcepts, I built an RKE2 Kubernetes cluster for classified ML workloads — air-gapped, GPU scheduling for data scientists, full GitOps with ArgoCD, and Keycloak SSO. It served twelve data scientists and tripled their model-training throughput."

### Drawing Order

**Step 1 — Draw the VPC boundary and AWS services (bottom of whiteboard):**
Draw a box labeled "VPC" with: ECR, S3 (terraform state, pipeline outputs, model zoo), Secrets Manager, IAM (OIDC/IRSA), RDS (PostgreSQL), EFS
Say: "Base layer is AWS — ECR for container images, S3 for state and artifacts, Secrets Manager for credentials, RDS for databases, EFS for shared notebook storage. All private subnets, no internet."

**Step 2 — Draw the RKE2 cluster inside the VPC (center):**
Draw: NLB (public subnet) → RKE2 cluster with: 3 control plane nodes (m5a.large), CPU worker nodes (m5a.2xlarge), GPU worker nodes (g4dn.xlarge with NVIDIA Operator)
Say: "Network Load Balancer in the public subnet routes to the cluster. Three control plane nodes for HA — RKE2 servers with embedded etcd. CPU node group for general workloads, GPU node group with g4dn instances and the NVIDIA GPU Operator for automatic driver injection."

**Step 3 — Draw the services running on the cluster (top):**
Draw boxes inside the cluster: ArgoCD, Istio (ingress gateway + istiod), Keycloak + oauth2-proxy, Kubeflow (dashboard, notebooks, pipelines, KServe), Monitoring (Prometheus, Grafana, Loki), Cluster Autoscaler, External Secrets Operator
Say: "ArgoCD syncs everything from Git — pure GitOps. Istio handles the service mesh and ingress. Auth flow goes NLB → Istio → oauth2-proxy → Keycloak — data scientists get SSO, no credential management. Kubeflow provides notebooks, pipelines, and model serving. Cluster Autoscaler watches for pending GPU pods and scales nodes automatically."

**Step 4 — Draw the data flow (arrows):**
- User → NLB → Istio → oauth2-proxy → Keycloak (auth) → Kubeflow dashboard
- Kubeflow spawns notebook pod → GPU node → mounts EFS
- Cluster Autoscaler → IAM → modifies ASG → new GPU node
- External Secrets → Secrets Manager
- KF Pipelines → S3 (artifacts) → RDS (metadata)
- ArgoCD ← Git repo (source of truth)

### What to Emphasize
1. **Air-gapped K8s is real** — "No internet access. All images from ECR, pre-transferred. ArgoCD syncs from local Git."
2. **GPU auto-scaling** — "Data scientist launches a training job, Cluster Autoscaler detects pending pod, spins up a g4dn node, NVIDIA Operator injects GPU drivers automatically. When training finishes, node scales back down."
3. **GitOps** — "I don't SSH in and kubectl apply. Everything is ArgoCD syncing manifests from Git. Drift is detected and reverted automatically."
4. **Self-service for data scientists** — "They don't file tickets for GPU access. They open a notebook, select a GPU profile, and the platform handles the rest."
5. **Tripled throughput** — concrete metric

### Component Deep-Dive Prep

**RKE2 — study these specifics:**
- Air-gap install: download tarball on connected side, transfer binary + images, run `rke2 server` / `rke2 agent`
- `registries.yaml` at `/etc/rancher/rke2/registries.yaml` — mirrors image pulls to local registry
- Default CNI: Canal (Calico policies + Flannel VXLAN overlay)
- Embedded etcd: no external etcd cluster needed, simpler HA
- Agent join: agents connect to server on port 9345 with a shared token
- FIPS mode: `--profile=cis-1.6` for CIS hardening, FIPS-validated crypto
- Ports: 6443 (API), 9345 (supervisor), 10250 (kubelet), 2379-2380 (etcd), 8472/UDP (VXLAN)

**Cluster Autoscaler — study how GPU scaling works:**
- HPA creates pod → scheduler can't find node with GPU → pod goes Pending
- Cluster Autoscaler detects pending pod → checks ASG capacity → increases desired count
- New g4dn node joins cluster → NVIDIA GPU Operator installs drivers → pod schedules
- When no GPU pods are pending → Autoscaler scales ASG back down
- Combined with idle-shutdown automation for cost control

**ArgoCD in Air-Gap — study these specifics:**
- ArgoCD Application CRD points to LOCAL Git repo (not github.com)
- Images pulled from LOCAL ECR (registries.yaml redirect)
- No webhooks — ArgoCD polls on a 3-minute interval
- Sync waves for ordering: CRDs first, then operators, then apps
- Auto-prune: removes resources deleted from Git
- Self-heal: reverts manual changes in cluster to match Git state

**Istio Auth Flow — study this chain:**
NLB → Istio IngressGateway → VirtualService routes → oauth2-proxy → Keycloak (validates creds against RDS) → returns token → oauth2-proxy injects header → Kubeflow dashboard
- oauth2-proxy handles the OIDC flow transparently
- Data scientists never manage tokens — SSO handles it

**External Secrets Operator:**
- Syncs AWS Secrets Manager entries into K8s Secret objects
- Pods reference native K8s Secrets — don't need AWS SDK
- Auto-refreshes when secrets change in AWS

### Tradeoffs to Know

**"Why RKE2 over EKS?"**
"On-prem, air-gapped, no AWS API access from inside the cluster. EKS requires internet for control plane. RKE2 bundles everything — one binary, embedded etcd, runs disconnected. Plus FIPS mode and CIS hardening built-in."

**"Why RKE2 over K3s?"**
"K3s is lightweight but trades features for simplicity — no FIPS, less enterprise support, sqlite instead of etcd by default. RKE2 is CIS hardened, FIPS-ready, and designed for government workloads. The extra weight is worth it for compliance."

**"Why ArgoCD over FluxCD?"**
"ArgoCD gives us a UI — operators and data scientists can see sync status, health, and drift without kubectl. In a classified environment where not everyone has cluster access, that visibility matters."

**"Why NVIDIA GPU Operator instead of pre-installing drivers?"**
"GPU Operator auto-detects GPU hardware and installs the right driver version on node boot. If we add a new GPU node type or upgrade drivers, the operator handles it. Pre-installing would mean rebuilding AMIs for every driver change."

**"What would you change?"**
"I'd add a Kyverno or OPA admission policy layer from the start. We had a few cases where data scientists deployed pods with no resource limits, consuming all GPU memory. Admission policies would catch that at deploy time instead of after a training job crashed."

### Bridging to Anduril
"This is exactly what your aircraft network deployment could look like. RKE2 runs air-gapped — no internet dependency. You'd transfer the binary and images via diode, Ansible bootstraps the nodes, ArgoCD syncs from local Git. Start with a single-node for testing, prove it works, then scale to HA. The Nightwatch platform I built is the reference architecture for how to do K8s in a classified, disconnected environment."

---

## Answer Keys

- **Real architecture diagram:** `ntconcepts-answers.md` (Nightwatch RKE2 mermaid chart — to be added)
- **How to present this system:** this file's coaching section above
- **Related:** `anduril-scenarios.md` Scenario 4 + `anduril-k8s-migration-pitch.md`
