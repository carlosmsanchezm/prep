# Kubernetes Refresher — Foundations & Mechanics

> **Purpose:** Refresh your understanding of K8s concepts you've used but need to explain clearly to Andy. Each section answers: what is it, how does it work mechanically, and why did you choose it.

---

## 1. High Availability (HA) & etcd Quorum

**What is etcd?**
etcd is the database that stores ALL K8s cluster state — every Deployment, Service, ConfigMap, Secret, pod status, everything. If etcd dies, the cluster is braindead — the API server can't read or write anything.

**Why 3 control plane nodes?**
etcd uses a consensus algorithm (Raft) that requires a MAJORITY of nodes to agree on every write. This majority is called a "quorum."

| Nodes | Quorum (majority) | Can lose | What happens if you lose more |
|-------|-------------------|----------|-------------------------------|
| 1 | 1 | 0 — single point of failure | Cluster is dead |
| 2 | 2 | 0 — WORSE than 1 (both must agree) | Cluster is dead |
| **3** | **2** | **1 node** | Still works — 2 out of 3 agree |
| 5 | 3 | 2 nodes | Still works — overkill for most setups |

**Why 3, not 5?**
"Three is the sweet spot. You survive one node failure, which covers hardware issues, upgrades, and maintenance. Five survives two failures but adds latency to every write (more nodes must agree) and costs more. For the Nightwatch platform, three was sufficient — we weren't running a thousand-node cluster."

**How it works in RKE2:**
- First server node starts with `cluster-init: true` — creates the etcd cluster
- Second and third join via port 9345 — etcd automatically forms a 3-node cluster
- Embedded etcd means no separate etcd cluster to manage — RKE2 handles it
- If one control plane node dies: the other two still have quorum, API server keeps working
- Recovery: bring the dead node back, it rejoins etcd and catches up automatically

**How to explain to Andy:**
"Three control plane nodes with embedded etcd. Raft consensus requires two out of three to agree on every write — that's quorum. We can lose one node and the cluster keeps running. I chose embedded etcd over external because it's simpler to operate — RKE2 manages the etcd lifecycle. No separate cluster to monitor, back up, or upgrade."

---

## 2. Persistent Volumes — How They Connect to AWS

**The chain:**
```
Pod → PVC (request) → StorageClass (provisioner) → PV (actual storage) → AWS (EBS/EFS)
```

**How dynamic provisioning works step by step:**

1. You define a **StorageClass** that says "use the AWS EBS provisioner, GP3 type, encrypted":
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3-encrypted
provisioner: ebs.csi.aws.com        # AWS EBS CSI driver handles the actual API call
parameters:
  type: gp3                          # GP3 SSD
  encrypted: "true"                  # encrypt at rest with KMS
reclaimPolicy: Retain                # keep the volume when PVC is deleted
volumeBindingMode: WaitForFirstConsumer  # don't create until a pod needs it
```

2. A Helm chart declares a **PVC** — "I need 50Gi":
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: jira-data
spec:
  storageClassName: gp3-encrypted    # use this StorageClass
  accessModes: [ReadWriteOnce]       # one pod at a time
  resources:
    requests:
      storage: 50Gi
```

3. When a pod mounts this PVC, K8s tells the **EBS CSI driver**: "create a 50Gi GP3 encrypted EBS volume in the same AZ as this pod"

4. The CSI driver calls the **AWS API** (`ec2:CreateVolume`), creates the EBS volume, attaches it to the node

5. K8s creates a **PV** automatically (dynamic provisioning) that represents this EBS volume

6. The PV **binds** to the PVC, and the pod mounts it at the specified path

**EBS vs EFS — when to use which:**

| | EBS (Elastic Block Store) | EFS (Elastic File System / NFS) |
|-|--------------------------|-------------------------------|
| **Access** | ReadWriteOnce — ONE pod at a time | ReadWriteMany — MULTIPLE pods simultaneously |
| **Think of it as** | A virtual hard drive attached to one server | A shared network folder everyone can access |
| **Use for** | Databases (PostgreSQL, etcd), single-instance apps | Shared data: notebooks, datasets, model files, config |
| **Speed** | Fast — direct attached block storage | Slower — network-based, but scales automatically |
| **Size management** | Fixed size — you provision 50Gi, you get 50Gi | Auto-scaling — grows as you add data, no pre-provisioning |
| **AZ constraint** | YES — EBS is tied to one AZ. Pod must be in the same AZ. | NO — EFS spans all AZs |
| **Nightwatch usage** | PostgreSQL databases (ArgoCD, Keycloak, Kubeflow) | Shared notebook storage for data scientists |

**How to explain to Andy:**
"PVCs are the request, StorageClass is the provisioner, PVs are the actual storage. For the Nightwatch platform, I used two StorageClasses: one for EBS — GP3 encrypted for databases, single-writer, fast — and one for EFS — shared storage that all notebook pods mount simultaneously. The EBS CSI driver handles the AWS API calls to create and attach volumes. Dynamic provisioning means I don't pre-create volumes — K8s creates them on demand when a pod needs storage."

---

## 3. Cluster Autoscaler — How Nodes Scale

**The problem it solves:**
K8s schedules pods onto nodes based on available resources (CPU, memory, GPU). When there aren't enough resources on any node, the pod goes "Pending." Without Cluster Autoscaler, it stays Pending forever.

**The flow — step by step:**

```
1. New pod created (e.g., GPU training job)
   → Pod spec says: "I need 1 GPU, 4 CPU, 16Gi memory"

2. K8s Scheduler checks all nodes
   → No node has a free GPU → Pod status: Pending (Unschedulable)

3. Cluster Autoscaler runs every 10 seconds, checks for Pending pods
   → Finds the GPU training pod
   → Checks which ASG could satisfy it (GPU ASG has g4dn.xlarge with 1 GPU)

4. Autoscaler calls AWS API (via IRSA): "increase GPU ASG desired count from 1 to 2"
   → Uses its IAM role to call autoscaling:SetDesiredCapacity

5. AWS launches a new g4dn.xlarge instance
   → Instance boots, rke2-agent starts (pre-configured in AMI or user-data)
   → Node registers with K8s API server

6. NVIDIA GPU Operator detects GPU hardware on new node
   → Installs CUDA drivers as a DaemonSet pod
   → Node becomes GPU-ready

7. K8s Scheduler sees the new node with available GPU
   → Schedules the Pending pod onto it → Training starts

8. Training completes → Pod terminates
   → No more Pending GPU pods
   → Autoscaler waits for cooldown period (default 10 min)
   → If still no GPU pods: "decrease GPU ASG desired count from 2 to 1"
   → AWS terminates the idle instance → Cost saved
```

**What Cluster Autoscaler does NOT do:**
- Does NOT scale PODS — that's HPA (Horizontal Pod Autoscaler)
- Does NOT monitor CPU usage on nodes — it ONLY watches for Pending pods
- Does NOT scale DOWN while pods are running — only removes EMPTY nodes

**How to explain to Andy:**
"Cluster Autoscaler doesn't watch CPU usage — it watches for Pending pods. When a pod can't schedule because no node has enough resources, Autoscaler increases the ASG desired count. AWS launches the instance, it joins the cluster, pod schedules. When no more pods need that node, Autoscaler scales it back down. It's reactive, not predictive — scales based on actual demand, not forecasted load."

---

## 4. GPU Nodes & CUDA

**What is a GPU node?**
An EC2 instance with a physical NVIDIA GPU attached. Example: g4dn.xlarge has 1 NVIDIA T4 GPU, 4 vCPUs, 16 GiB memory. The GPU is a hardware chip optimized for parallel math — matrix operations that ML training needs.

**What is CUDA?**
CUDA is NVIDIA's software toolkit that lets programs use the GPU for computation. Without CUDA drivers installed on the node, the GPU is just unused hardware — K8s doesn't know it exists.

**How the NVIDIA GPU Operator works:**
1. GPU Operator runs as a DaemonSet — a pod on EVERY node in the cluster
2. On nodes WITHOUT a GPU: the operator pod does nothing
3. On nodes WITH a GPU (g4dn): the operator detects the hardware and:
   - Installs CUDA drivers
   - Installs the NVIDIA container runtime
   - Registers the GPU as a schedulable resource: `nvidia.com/gpu: 1`
4. Now K8s scheduler knows: "this node has 1 GPU available"
5. A pod that requests `nvidia.com/gpu: 1` gets scheduled to this node

**Why use the GPU Operator instead of pre-installing CUDA?**
"If I pre-install CUDA on the AMI, I have to rebuild the AMI every time there's a driver update. The GPU Operator handles it at runtime — new node joins, operator detects GPU, installs the right driver version. If NVIDIA releases a security patch, I update the operator's config and it rolls out new drivers across all GPU nodes. No AMI rebuild."

---

## 5. ArgoCD & GitOps — Deep Refresher

**What is GitOps?**
One rule: **Git is the source of truth for what should be running in the cluster.** Nothing gets deployed by running kubectl manually. Everything goes through Git.

**What is ArgoCD?**
A K8s controller (runs as pods in the cluster) that continuously syncs the cluster state to match what's in a Git repository.

**The complete flow — what happens when you push to Git:**

```
1. YOU: git push a change to the argoflow repo
   (e.g., update Kubeflow image tag from v1.8 to v1.9)

2. ARGOCD: polls the repo every 3 minutes (no webhooks — air-gap friendly)
   → Detects: "Git says image should be v1.9, cluster is running v1.8"
   → Status changes from "Synced" to "OutOfSync"

3. ARGOCD: automatically syncs (if auto-sync is enabled)
   → Runs the equivalent of: kubectl apply -f <all manifests from Git>
   → K8s sees: "Deployment says image v1.9, running pods have v1.8"
   → K8s starts a rolling update: new pod with v1.9, old pod with v1.8 terminated

4. ARGOCD: watches the rollout
   → Checks health: are the new pods Running? Passing readiness probes?
   → If healthy: status → "Synced" and "Healthy"
   → If unhealthy: status → "Degraded" — you see it in the ArgoCD UI

5. DRIFT DETECTION: if someone manually runs kubectl edit on a resource
   → ArgoCD detects: "cluster doesn't match Git"
   → If self-heal is enabled: ArgoCD reverts the manual change back to Git state
   → Nobody can make permanent changes without going through Git
```

**Key ArgoCD concepts:**

| Concept | What it means |
|---------|--------------|
| **Application** | An ArgoCD resource that says "sync THIS Git repo path to THIS cluster namespace" |
| **Sync** | Make the cluster match Git — kubectl apply all manifests |
| **OutOfSync** | Cluster doesn't match Git — something changed or Git was updated |
| **Self-Heal** | Automatically revert manual cluster changes to match Git |
| **Auto-Prune** | Delete resources from cluster that were removed from Git |
| **Sync Waves** | Order of deployment — CRDs first (wave 0), then operators (wave 1), then apps (wave 2) |
| **Health Check** | ArgoCD checks if resources are actually working, not just applied |

**Why ArgoCD in air-gap works:**
"ArgoCD polls — it doesn't need webhooks. No inbound connections required. The Git repo is LOCAL (inside the network), not github.com. Images are pulled from LOCAL ECR via registries.yaml. ArgoCD just compares Git to cluster state and reconciles. Zero internet dependency."

**How to explain GitOps to Andy:**
"Git is the source of truth. I push manifests to the argoflow repo. ArgoCD polls it every three minutes, detects changes, and syncs the cluster — runs kubectl apply under the hood. If the cluster drifts from Git — someone manually edits something — ArgoCD detects it and reverts. Nobody can make permanent changes without going through Git. Full audit trail, every change is a commit."

### 5b. Inside the ArgoFlow Repo — What It Looks Like and How It Works

> This is the missing piece: you know ArgoCD syncs from a Git repo, but what does that repo ACTUALLY contain?

**The argoflow repo structure:**

```
argoflow/
├── apps/                              # ArgoCD Application definitions
│   ├── istio.yaml                     #   "deploy Istio from charts/istio to istio-system namespace"
│   ├── keycloak.yaml                  #   "deploy Keycloak from charts/keycloak to keycloak namespace"
│   ├── monitoring.yaml                #   "deploy Prometheus stack to monitoring namespace"
│   ├── external-secrets.yaml          #   "deploy ESO to kube-system namespace"
│   ├── cluster-autoscaler.yaml        #   "deploy autoscaler to kube-system namespace"
│   └── kubeflow.yaml                  #   "deploy Kubeflow to kubeflow namespace"
│
├── charts/                            # Helm charts (or plain manifests) for each service
│   ├── istio/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── keycloak/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   ├── monitoring/
│   │   └── ...
│   └── kubeflow/
│       └── ...
│
├── base/                              # Shared manifests (namespaces, RBAC, network policies)
│   ├── namespaces.yaml                #   creates: istio-system, keycloak, monitoring, kubeflow
│   ├── rbac.yaml                      #   cluster-wide RBAC rules
│   └── network-policies.yaml          #   default deny + allowed paths
│
└── README.md
```

**What's an ArgoCD Application definition?**

This is the KEY file — it tells ArgoCD: "watch THIS path in THIS repo, deploy it to THIS namespace on THIS cluster."

```yaml
# apps/keycloak.yaml — this is an ArgoCD Application

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: keycloak                         # name shown in ArgoCD UI
  namespace: argocd                      # ArgoCD's own namespace
  annotations:
    argocd.argoproj.io/sync-wave: "2"    # deploy AFTER wave 0 and 1
spec:
  project: default                       # ArgoCD project (RBAC boundary)

  # SOURCE: where to read manifests FROM
  source:
    repoURL: https://gitea.local/argoflow.git   # LOCAL Git — not github.com
    targetRevision: main                          # branch to watch
    path: charts/keycloak                         # directory in the repo
    helm:                                         # it's a Helm chart
      valueFiles:
        - values.yaml                             # default values
      # Can override values inline too:
      parameters:
        - name: replicas
          value: "2"

  # DESTINATION: where to deploy TO
  destination:
    server: https://kubernetes.default.svc   # this cluster (in-cluster)
    namespace: keycloak                       # target namespace

  # SYNC POLICY: how ArgoCD manages this application
  syncPolicy:
    automated:
      prune: true          # delete resources removed from Git
      selfHeal: true       # revert manual changes back to Git state
    syncOptions:
      - CreateNamespace=true   # create namespace if it doesn't exist
```

**What each field means:**

| Field | What it does | Why it matters |
|-------|-------------|----------------|
| `source.repoURL` | Git repo ArgoCD watches | LOCAL repo — not github.com. Air-gap safe. |
| `source.path` | Directory in the repo containing manifests or Helm chart | Each service has its own directory. ArgoCD only watches THIS path. |
| `source.targetRevision` | Branch or tag to sync from | `main` = always latest. Could be `v1.2.0` for pinned versions. |
| `source.helm.valueFiles` | Helm values file to use | Environment-specific config lives here. |
| `destination.server` | Which K8s cluster to deploy to | `https://kubernetes.default.svc` = the cluster ArgoCD is running on. |
| `destination.namespace` | Target namespace | Each service gets its own namespace — isolation. |
| `syncPolicy.automated.prune` | Delete resources removed from Git | If you remove a ConfigMap from Git, ArgoCD deletes it from the cluster. Keeps things clean. |
| `syncPolicy.automated.selfHeal` | Revert manual cluster changes | Someone runs `kubectl edit` to change replicas? ArgoCD reverts it. Git is truth. |
| `sync-wave` annotation | Ordering — which apps deploy first | Wave 0 = CRDs and namespaces. Wave 1 = Istio (mesh must exist before services register). Wave 2 = everything else. |

**How ArgoCD processes this:**

```
1. ArgoCD starts up, reads all Application YAMLs in the apps/ directory
2. For each Application, ArgoCD:
   a. Clones the repo (or pulls latest if already cloned)
   b. Reads the manifests at the specified path
   c. If it's Helm: runs helm template with the values file → produces K8s YAML
   d. Compares the rendered YAML to what's actually in the cluster
   e. If they match: status = "Synced"
   f. If they differ: status = "OutOfSync" → auto-sync runs kubectl apply
3. Every 3 minutes, repeats step 2 (polling)
4. If someone manually changes something in the cluster:
   → Next poll detects drift
   → selfHeal reverts it back to Git state
```

**Sync Waves — controlling deployment order:**

Some services MUST deploy before others. CRDs must exist before resources that use them. Istio's mesh must be running before services register with it.

```
Wave 0: Namespaces + CRDs (must exist first)
  └── base/namespaces.yaml creates: istio-system, keycloak, monitoring, kubeflow
  └── CRD definitions for any custom resources

Wave 1: Core infrastructure (mesh, policies)
  └── apps/istio.yaml (sync-wave: "1")
  └── apps/external-secrets.yaml (sync-wave: "1")

Wave 2: Services that depend on core
  └── apps/keycloak.yaml (sync-wave: "2")
  └── apps/monitoring.yaml (sync-wave: "2")
  └── apps/cluster-autoscaler.yaml (sync-wave: "2")

Wave 3: Application workloads
  └── apps/kubeflow.yaml (sync-wave: "3")
```

ArgoCD deploys ALL wave 0 apps first, waits for them to be healthy, then wave 1, then wave 2, then wave 3. If wave 1 fails (Istio won't start), wave 2 never deploys — prevents cascading failures.

**App of Apps pattern — how ArgoCD discovers Application definitions:**

Instead of manually creating each Application in ArgoCD, you create ONE "parent" Application that points to the `apps/` directory:

```yaml
# The ONE Application you create manually (or via Helm during cluster bootstrap):

apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  source:
    repoURL: https://gitea.local/argoflow.git
    path: apps                            # directory containing ALL Application YAMLs
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

ArgoCD reads this, finds all the YAML files in `apps/`, creates Application resources for each one. Those Applications then each sync their own service. ONE manual step → everything else is automated.

**How to add a NEW service:**

1. Create the Helm chart or manifests in `charts/my-new-service/`
2. Create an Application YAML in `apps/my-new-service.yaml` pointing to that path
3. Git commit and push
4. ArgoCD detects the new Application definition (via app-of-apps)
5. ArgoCD creates the Application, syncs the chart, deploys the service
6. Done — no kubectl, no manual apply

**How to UPDATE a service:**

1. Change `values.yaml` in `charts/keycloak/` (e.g., bump image tag)
2. Git commit and push
3. ArgoCD polls, detects: "keycloak chart changed"
4. ArgoCD re-renders the Helm template with new values
5. ArgoCD compares rendered output to cluster state → "OutOfSync"
6. ArgoCD runs kubectl apply → K8s does rolling update
7. ArgoCD watches rollout → "Synced" and "Healthy"

**How to DELETE a service:**

1. Delete `apps/my-service.yaml` from Git
2. Git commit and push
3. ArgoCD detects: "Application definition gone"
4. With prune=true: ArgoCD deletes all resources it created for that service
5. Service is gone — clean, no orphans

**How to explain to Andy:**
"The argoflow repo has two directories: apps/ and charts/. Charts/ has the Helm chart for each service — Istio, Keycloak, monitoring, Kubeflow. Apps/ has one ArgoCD Application YAML per service — each one says 'watch this chart, deploy to this namespace, auto-sync, self-heal.' An app-of-apps parent Application points to the apps/ directory, so ArgoCD discovers all services automatically. Adding a new service is: write the chart, write the Application YAML, push to Git. ArgoCD handles the rest. Sync waves control ordering — CRDs first, mesh second, services third, apps last."

---

## 6. Istio Service Mesh — What It Does and How

**What is a service mesh?**
A layer that handles service-to-service communication TRANSPARENTLY. Your application code doesn't change — Istio injects a sidecar proxy (Envoy) into every pod that handles encryption, routing, retries, and observability.

**How Istio works mechanically:**

```
WITHOUT Istio:
  Pod A → HTTP request → Pod B (plain text, no encryption, no visibility)

WITH Istio:
  Pod A → Envoy sidecar (in Pod A) → mTLS encrypted → Envoy sidecar (in Pod B) → Pod B
           ↓                                              ↓
      reports metrics                               reports metrics
      to Istio control plane                        to Istio control plane
```

1. **Sidecar injection:** When you deploy a pod, Istio's admission webhook automatically adds an Envoy container to the pod (the "sidecar"). The app doesn't know it's there.
2. **mTLS:** Every sidecar has a certificate issued by Istio's CA (istiod). When Pod A calls Pod B, the sidecars handle the TLS handshake — encrypted, mutually authenticated. App code just makes plain HTTP calls.
3. **Ingress Gateway:** External traffic enters through Istio's ingress gateway (a dedicated Envoy pod). The NLB forwards to this gateway, which routes to the right service based on rules (VirtualService CRDs).
4. **Observability:** Every sidecar reports request metrics — who called who, latency, error rate. This feeds Prometheus/Grafana without any app code changes.

**Key Istio components:**

| Component | What it does | Where it runs |
|-----------|-------------|---------------|
| **istiod** | Control plane — issues certificates, configures sidecars, manages routing rules | Pod in istio-system namespace |
| **Envoy sidecar** | Data plane — handles actual traffic between pods | Injected into EVERY application pod |
| **Ingress Gateway** | Entry point for external traffic | Pod in istio-system, NLB points to it |
| **VirtualService** | Routing rules — "send /api traffic to service-a, /web to service-b" | K8s CRD (YAML in Git, deployed by ArgoCD) |

**Why Istio for Nightwatch:**
"Zero-trust networking. Every pod-to-pod call is mTLS encrypted without changing application code. Plus observability — I can see which service called which, latency, error rates, all in Grafana. And the ingress gateway handles external traffic routing so I don't need separate nginx or HAProxy."

---

## 7. IRSA (IAM Roles for Service Accounts) — Explained Simply

**The problem IRSA solves:**
Pods need to call AWS APIs (Cluster Autoscaler needs to scale ASGs, External Secrets needs to read Secrets Manager). Without IRSA, every pod on the node uses the NODE's IAM instance profile — meaning every pod has the SAME AWS permissions. That's way too broad.

**The analogy:**
Think of it like office building security. Without IRSA: everyone who enters the building gets the master key (node instance profile). WITH IRSA: each person gets a badge that only opens the doors they need (pod-level IAM role).

**How it works — the complete chain:**

```
SETUP (done once by Terraform):

1. Terraform creates an OIDC Provider in IAM:
   "Trust tokens signed by this K8s cluster's service account issuer"
   (Think: "IAM, here's the cluster's ID — trust anyone who shows a token from this cluster")

2. Terraform creates an IAM Role (e.g., cluster-autoscaler-role):
   Trust policy says: "Only accept tokens from service account 'cluster-autoscaler'
   in namespace 'kube-system' from THIS specific cluster's OIDC provider"
   Permissions: autoscaling:SetDesiredCapacity, autoscaling:DescribeAutoScalingGroups

3. In the Helm chart / ArgoCD manifest, the ServiceAccount is annotated:
   annotations:
     eks.amazonaws.com/role-arn: arn:aws:iam::123456:role/cluster-autoscaler-role
```

```
RUNTIME (happens automatically every time the pod starts):

4. Pod starts with serviceAccountName: cluster-autoscaler
   → K8s injects a JWT token into the pod at /var/run/secrets/...
   → This token says: "I am cluster-autoscaler in kube-system"

5. AWS SDK in the pod reads the token and calls AWS STS:
   "Here's my K8s token, give me temporary credentials for my annotated role"

6. AWS STS checks:
   - Is the token from a trusted OIDC provider? ✓
   - Does the service account name match the role's trust policy? ✓
   → Returns temporary AWS credentials (access key + secret + session token)
   → Credentials expire in 1 hour, automatically refreshed

7. Pod uses temporary credentials to call AWS APIs:
   Cluster Autoscaler → autoscaling:SetDesiredCapacity ✓
   Cluster Autoscaler → s3:GetObject ✗ (not in the role's permissions — denied)
```

**What Terraform provisions:**
- The OIDC provider (links the K8s cluster to IAM)
- Each IAM role + trust policy (one per service that needs AWS access)
- The role permissions (what AWS APIs the service can call)

**What the Helm chart / ArgoCD provides:**
- The ServiceAccount with the role ARN annotation
- The pod spec that references the ServiceAccount

**How to explain to Andy:**
"IRSA gives each pod its own IAM role instead of sharing the node's instance profile. Terraform creates an OIDC provider that makes IAM trust the cluster's tokens, then creates a role per service — Cluster Autoscaler gets a role that can scale ASGs, External Secrets gets a role that can read Secrets Manager. Neither can do the other's job. The pod gets a K8s token injected automatically, exchanges it with AWS STS for temporary credentials. Pod-level least-privilege, no shared keys, no hardcoded credentials."

---

## 8. Why Prometheus Over CloudWatch (Architectural Thinking)

**The question behind the question:** Andy isn't asking which tool is better — he's testing whether you evaluate tradeoffs or just pick what you know.

| | Prometheus + Grafana + Loki | AWS CloudWatch + CloudTrail |
|-|-----------------------------|-----------------------------|
| **Runs where** | Inside the cluster as pods | AWS-managed service (external) |
| **Egress needed** | No — everything is local | Yes — metrics/logs sent to AWS API endpoint |
| **Cost** | Free (open-source) | Per metric, per log group, per API call — adds up fast |
| **K8s integration** | Native — scrapes pod metrics, knows about Deployments, Services | Requires CloudWatch agent installed, less K8s-aware |
| **Customization** | Full control — custom dashboards, alerting rules, retention | Limited to CloudWatch's UI and metric types |
| **Air-gap friendly** | Yes — zero external dependency | Needs egress to CloudWatch endpoint (even in GovCloud) |
| **What it monitors** | Cluster internals: pod CPU/memory, request latency, error rates, logs | AWS resources: EC2 metrics, RDS performance, API calls |

**The answer: we used BOTH, for different things.**

"Prometheus for cluster-level observability — pod metrics, service latency, K8s events. It runs inside the cluster, zero egress, free. CloudWatch for AWS-level monitoring — EC2 instance health, RDS performance, ASG scaling events. CloudTrail for audit logging — who called what AWS API, when. They complement each other: Prometheus sees inside the cluster, CloudWatch sees the AWS infrastructure underneath."

**Why not JUST CloudWatch?**
"CloudWatch charges per metric and per API call. With nine services, dozens of pods, and custom metrics, the cost would be significant. Prometheus is free and gives us better K8s integration — it understands Deployments, pod labels, service meshes natively. Plus, in a controlled-egress environment, every CloudWatch API call goes through the Network Firewall. Prometheus stays entirely local."

---

## 9. cert-manager — Certificate Lifecycle

**What it does:**
cert-manager is a K8s controller that automates TLS certificate creation, renewal, and distribution. Without it, you'd manually generate certs, copy them to the right pods, and remember to renew them before they expire.

**How it works:**

```
1. You create a Certificate CRD:
   "I need a TLS cert for kubeflow.nightwatch.internal, valid 90 days"

2. cert-manager reads the Certificate resource
   → Talks to a CA (Certificate Authority) — could be:
     - Let's Encrypt (internet-connected)
     - Self-signed CA (air-gap — no external dependency)
     - AWS Private CA
     - Vault PKI

3. cert-manager generates the cert
   → Stores it as a K8s Secret (tls type: cert + private key)
   → The Ingress or pod that needs it mounts the Secret

4. 30 days before expiry: cert-manager auto-renews
   → Generates new cert, updates the Secret
   → Pods pick up the new cert on next restart or volume refresh
```

**For Nightwatch (air-gapped):**
"We used a self-signed CA with cert-manager. No Let's Encrypt — that requires internet. cert-manager generated certs for Istio's ingress gateway, Keycloak's HTTPS, and internal service-to-service TLS. Auto-renewal meant we never had a cert expire unexpectedly."

---

## 10. Where Everything Runs (It's All Pods)

**A common confusion:** diagrams show boxes for ArgoCD, Istio, Keycloak, Monitoring, External Secrets — they look like separate systems. But they're ALL pods running inside the K8s cluster on the worker nodes.

```
Worker Node (m5a.2xlarge — one of many)
├── kubelet (manages pods on this node)
├── containerd (runs containers)
├── kube-proxy (iptables rules for Service routing)
│
├── Pod: argocd-server (ArgoCD UI + API)
├── Pod: argocd-repo-server (clones Git repos)
├── Pod: argocd-application-controller (syncs manifests)
│
├── Pod: istiod (Istio control plane)
├── Pod: istio-ingressgateway (Envoy — external traffic entry)
│
├── Pod: prometheus-server (scrapes metrics)
├── Pod: grafana (dashboards)
├── Pod: loki (log aggregation)
│
├── Pod: keycloak (SSO — backed by RDS)
├── Pod: external-secrets (syncs AWS Secrets → K8s Secrets)
├── Pod: cluster-autoscaler (watches pending pods, scales ASGs)
│
├── Pod: kubeflow-dashboard (user-facing)
├── Pod: kubeflow-pipelines-api (pipeline orchestration)
├── Pod: user-notebook-abc123 (data scientist's Jupyter notebook)
│
└── (Envoy sidecar injected into most pods by Istio)
```

**Key understanding:** The "Infrastructure Services" and "Application Workloads" boxes in the diagram are LOGICAL groupings — they help YOU understand what's YOUR responsibility vs what the data science team uses. But physically, they're all pods on the same worker nodes, managed by the same K8s scheduler, deployed by the same ArgoCD.

**How to explain to Andy:**
"Everything inside the cluster is pods. ArgoCD, Istio, Keycloak, Prometheus, Kubeflow — they're all Deployments running on the worker nodes. The K8s scheduler decides which node they land on based on resource availability. I separate them logically — infrastructure services that I manage vs application workloads that the data science team uses — but physically they share the same nodes, same container runtime, same network."

---

## Quick Reference: What Provisions What

| Tool | What it creates | Layer |
|------|----------------|-------|
| **Terraform** | VPC, subnets, ASGs, RDS, EFS, ECR, IAM roles, OIDC provider, TGW attachment, NFW rules, security groups | AWS infrastructure |
| **Ansible** | Installs RKE2 binary, writes config.yaml + registries.yaml, opens firewall ports, starts rke2-server/agent systemd service | Node configuration |
| **ArgoCD** | Deploys all K8s resources: Deployments, Services, ConfigMaps, Secrets, CRDs, operators, application workloads | Everything inside the cluster |
| **Cluster Autoscaler** | Scales AWS ASGs up/down based on pending pods | Node count |
| **External Secrets Operator** | Creates K8s Secrets from AWS Secrets Manager entries | Secrets bridge (AWS → K8s) |
| **cert-manager** | Creates and renews TLS certificates as K8s Secrets | Certificate lifecycle |
| **NVIDIA GPU Operator** | Installs CUDA drivers on GPU nodes | GPU readiness |
