## Chart 3: Nightwatch RKE2 Platform — Full Reference

> This is the complete architecture. Use it to STUDY and memorize components. For whiteboarding, use the layered drawing guide below it.

```mermaid
---
config:
  layout: fixed
  theme: dark
  look: neo
---
flowchart TB
 subgraph subGraph3["Core AWS Services"]
    direction LR
        ECR["ECR<br>Container Registry"]
        S3["S3 Buckets<br>- terraform-state<br>- kubeflow-rke2<br>- pipeline-outputs<br>- model-zoo"]
        SecretsManager["Secrets Manager<br>Database Passwords<br>API Keys"]
        IAM["IAM<br>OIDC Provider<br>Service Roles IRSA"]
  end
 subgraph subGraph4["Public Subnets"]
        NLB["Network Load Balancer<br>nlb-kubeflow-c4b8b"]
  end
 subgraph subGraph5["Control Plane ASG: kubeflow-server-rke2-nodepool"]
        CP1["m5a.large<br>rke2-server"]
        CP2["m5a.large<br>rke2-server"]
        CP3["m5a.large<br>rke2-server"]
  end
 subgraph subGraph6["CPU Nodes ASG: kubeflow-cpu-agent-rke2-nodepool"]
        CPU_Node1["m5a.2xlarge<br>rke2-agent"]
  end
 subgraph subGraph7["GPU Nodes ASG: kubeflow-gpu-agent-rke2-nodepool"]
        GPU_Node1["g4dn.xlarge<br>rke2-agent<br>+ NVIDIA Operator"]
  end
 subgraph subGraph8["Worker Nodes"]
    direction LR
        subGraph6
        subGraph7
  end
 subgraph subGraph9["Cluster Services Running on Nodes"]
        ArgoCD["ArgoCD<br>argocd ns"]
        ClusterAutoscaler["Cluster Autoscaler<br>kube-system ns"]
        Istio["Istio Service Mesh<br>istiod, ingress-gateway<br>istio-system ns"]
        Keycloak["Keycloak<br>auth ns"]
        Oauth2Proxy["oauth2-proxy<br>auth ns"]
        KF_Core["Kubeflow Core<br>Dashboard, Notebooks<br>kubeflow ns"]
        KF_Pipelines["KF Pipelines<br>kubeflow ns"]
        KServe["KServe<br>kubeflow ns"]
        Knative["Knative Serving<br>knative-serving ns"]
        Monitoring["Monitoring Stack<br>Prometheus, Grafana, Loki<br>monitoring ns"]
        ExtSecrets["External Secrets Op.<br>kube-system ns"]
  end
 subgraph subGraph10["RKE2 Kubernetes Cluster"]
    direction TB
        subGraph5
        subGraph8
        subGraph9
  end
 subgraph subGraph11["Private Subnets"]
    direction TB
        subGraph10
  end
 subgraph subGraph12["Managed Data & Auth Services"]
    direction TB
        RDS["RDS PostgreSQL<br>- ArgoCD DB<br>- Keycloak DB<br>- Kubeflow DB"]
        EFS["EFS<br>Shared Notebook Storage"]
  end
 subgraph subGraph13["VPC: ntc-2023-studiodx-demo"]
    direction TB
        subGraph4
        subGraph11
        subGraph12
  end
 subgraph subGraph14["AWS Cloud us-east-1"]
    direction TB
        subGraph3
        subGraph13
  end
    Developer["DevSecOps Engineer"] -- git push --> GitRepo["argoflow<br>Git Repository<br>Source of Truth"]
    User["Data Scientist"] -- HTTPS --> NLB
    NLB -- TCP --> Istio
    GitRepo -.-> ArgoCD
    ArgoCD -. kubectl apply<br>Syncs Manifests .-> Istio & Keycloak & KF_Core & Monitoring
    Istio -- 1 Route traffic --> Oauth2Proxy
    Oauth2Proxy -- 2 Redirect to Login --> Keycloak
    Keycloak -- 3 Verify Credentials --> RDS
    Keycloak -- 4 Return Auth Token --> Oauth2Proxy
    Oauth2Proxy -- 5 Forward w/ Header --> KF_Core
    KF_Core -- Spawns Notebook Pod --> GPU_Node1
    GPU_Node1 -- Mounts Volume --> EFS
    KF_Core -- Unschedulable Pod? --> ClusterAutoscaler
    ClusterAutoscaler -- Update Desired --> IAM
    IAM -. Assumes Role .-> ClusterAutoscaler
    ClusterAutoscaler -. Modify ASG .-> GPU_Node1
    ExtSecrets -. Read Secrets .-> SecretsManager
    KF_Pipelines -- Reads/Writes Artifacts --> S3
    KF_Pipelines -- DB Connection --> RDS
    KServe -- Uses --> Knative
    CPU_Node1 -- Pull Image --> ECR
    GPU_Node1 -- Pull Image --> ECR

     ECR:::aws
     S3:::aws
     SecretsManager:::aws
     IAM:::aws
     NLB:::aws
     CP1:::k8s
     CP2:::k8s
     CP3:::k8s
     CPU_Node1:::k8s
     GPU_Node1:::k8s
     ArgoCD:::gitops
     ClusterAutoscaler:::k8s
     Istio:::k8s
     Keycloak:::app
     Oauth2Proxy:::app
     KF_Core:::app
     KF_Pipelines:::app
     KServe:::app
     Knative:::app
     Monitoring:::app
     ExtSecrets:::k8s
     RDS:::aws
     EFS:::aws
     Developer:::user
     GitRepo:::gitops
     User:::user
    classDef gitops fill:#cce5ff,stroke:#004085,stroke-width:2px
    classDef aws    fill:#fff3cd,stroke:#856404,stroke-width:2px
    classDef k8s    fill:#f8d7da,stroke:#721c24,stroke-width:2px
    classDef app    fill:#e2e3e5,stroke:#383d41,stroke-width:2px
    classDef user   fill:#d4edda,stroke:#155724,stroke-width:2px
```

---

### Whiteboard Drawing Guide: 4 Layers (draw progressively)

The full diagram has ~25 components. On a whiteboard you can't draw all of it. Instead, draw it in 4 layers — each takes 2-3 minutes. Andy will stop you on the layer he wants to dig into.

#### Layer 1: Infrastructure Skeleton (draw this first — 2 min)

Draw the physical layout: VPC, subnets, node groups, AWS services.

```
On the whiteboard:

┌─────────────────── AWS Cloud (us-east-1) ───────────────────┐
│                                                              │
│  ┌── Core AWS Services ──────────────────────────────────┐   │
│  │  ECR (images)   S3 (state/artifacts)   IAM (IRSA)    │   │
│  │  Secrets Manager                                       │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌── VPC ────────────────────────────────────────────────┐   │
│  │  [Public Subnet: NLB]                                  │   │
│  │                                                        │   │
│  │  ┌── Private Subnets: RKE2 Cluster ───────────────┐   │   │
│  │  │  Control Plane: 3x m5a.large (HA)              │   │   │
│  │  │  CPU Workers:   m5a.2xlarge                     │   │   │
│  │  │  GPU Workers:   g4dn.xlarge + NVIDIA Operator   │   │   │
│  │  │                                                 │   │   │
│  │  │  [Cluster Services - draw in Layer 2]           │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  │                                                        │   │
│  │  ┌── Managed Data Services ────────────────────────┐   │   │
│  │  │  RDS PostgreSQL (ArgoCD, Keycloak, Kubeflow)    │   │   │
│  │  │  EFS (shared notebook storage)                  │   │   │
│  │  └─────────────────────────────────────────────────┘   │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

Say: "The platform runs on AWS. Three control plane nodes for HA — m5a.large running rke2-server with embedded etcd. CPU worker pool on m5a.2xlarge for general workloads. GPU worker pool on g4dn.xlarge with the NVIDIA GPU Operator for automatic driver injection. Everything in private subnets — NLB in the public subnet is the only entry point. RDS PostgreSQL backs ArgoCD, Keycloak, and Kubeflow. EFS provides shared notebook storage across pods."

#### Layer 2: Cluster Services (add inside the cluster box — 2 min)

Now fill in what runs ON the cluster. Group by function:

```
Inside the RKE2 Cluster box, write:

  Networking:    Istio (service mesh + ingress gateway)
  Auth:          Keycloak + oauth2-proxy
  GitOps:        ArgoCD (syncs from Git)
  ML Platform:   Kubeflow (notebooks, pipelines, KServe, Knative)
  Monitoring:    Prometheus + Grafana + Loki
  Scaling:       Cluster Autoscaler
  Secrets:       External Secrets Operator → AWS Secrets Manager
```

Say: "Inside the cluster: Istio handles the service mesh and ingress. Keycloak with oauth2-proxy for SSO — data scientists don't manage credentials. ArgoCD syncs everything from a Git repo — pure GitOps, no manual kubectl. Kubeflow provides notebooks, pipelines, and model serving. Monitoring stack is Prometheus, Grafana, and Loki. Cluster Autoscaler watches for pending GPU pods. External Secrets Operator syncs credentials from AWS Secrets Manager."

#### Layer 3: Data Scientist User Flow (draw the numbered auth chain — 2 min)

Draw the user path with numbered steps:

```
[Data Scientist] --HTTPS--> [NLB] --TCP--> [Istio Ingress]
                                                  |
                                            1. Route traffic
                                                  ↓
                                           [oauth2-proxy]
                                                  |
                                          2. Redirect to login
                                                  ↓
                                            [Keycloak]
                                                  |
                                        3. Verify creds → [RDS]
                                                  |
                                        4. Return auth token
                                                  ↓
                                           [oauth2-proxy]
                                                  |
                                        5. Forward with header
                                                  ↓
                                        [Kubeflow Dashboard]
                                                  |
                                          Spawns notebook pod
                                                  ↓
                                           [GPU Node] → mounts [EFS]
```

Say: "Data scientist hits the NLB, Istio routes to oauth2-proxy, which redirects to Keycloak for login. Keycloak verifies against RDS, returns a token, oauth2-proxy injects the auth header, and the request reaches the Kubeflow dashboard. From there, the scientist launches a notebook — Kubeflow spawns a pod on a GPU node, mounts EFS for shared storage. Completely self-service — no tickets, no admin intervention."

#### Layer 4: GPU Auto-Scaling Flow (the impressive part — 2 min)

Draw the scaling loop:

```
[Kubeflow: spawn notebook requesting GPU]
            |
    Pod goes Pending (no GPU node available)
            ↓
[Cluster Autoscaler detects pending pod]
            |
    Assumes IAM role (IRSA)
            ↓
[Modifies ASG desired count]
            |
    New g4dn.xlarge node launches
            ↓
[NVIDIA GPU Operator installs drivers]
            |
    Pod schedules on new node → training starts
            ↓
[Training completes → pod terminates]
            |
    No pending GPU pods → Autoscaler scales down
```

Say: "This is the part that tripled throughput. Data scientist requests a GPU notebook. If no GPU node has capacity, the pod goes Pending. Cluster Autoscaler detects it, assumes an IAM role via IRSA, and increases the ASG desired count. New g4dn node comes up, NVIDIA Operator auto-installs GPU drivers, pod schedules, training starts. When training completes and no more GPU pods are pending, Autoscaler scales the node back down. GPU costs are controlled — nodes only exist during active training."

#### Layer 5 (optional, only if time): GitOps Flow

```
[Developer] --git push--> [argoflow Git Repo]
                                   |
                          ArgoCD watches repo
                                   ↓
                    [ArgoCD syncs manifests to cluster]
                                   |
                    Deploys: Istio, Keycloak, Kubeflow, Monitoring
                                   |
                    Images pulled from ECR
```

Say: "Everything is GitOps. I push manifests to the argoflow Git repo, ArgoCD detects the change and syncs to the cluster. No manual kubectl — drift is detected and reverted automatically. Images come from ECR."

---

### When to Stop Drawing

- If Andy says "tell me more about the auth flow" → you've already drawn Layer 3, point to it and elaborate
- If Andy says "how does the GPU scaling work?" → draw Layer 4 and explain
- If Andy says "interesting, what about the networking?" → point to Layer 1 (NLB, private subnets, Istio) and explain
- **Don't try to draw all 4 layers unprompted.** Draw Layer 1, narrate it, pause. Let Andy direct where to go deeper.
    ClusterAutoscaler -- scale ASG --> IAM
    ExtSecrets -- read --> SecretsManager
    KF_Pipelines -- artifacts --> S3
    KF_Pipelines -- metadata --> RDS
    CPU_Node1 -- pull image --> ECR
    GPU_Node1 -- pull image --> ECR
```