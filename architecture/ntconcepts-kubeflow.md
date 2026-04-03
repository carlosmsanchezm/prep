# Architecture Practice: NTConcepts Kubeflow ML-Ops Platform

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the Kubeflow platform architecture from memory
2. Show the two platforms: Nightwatch (RKE2) and StudioDX (EKS)
3. Explain the GPU scheduling flow
4. Narrate out loud — 10 minutes

---

## What You Should Be Able to Draw

### Nightwatch Platform (RKE2 — On-Prem)

```
                    ┌─────────────────────────────────┐
                    │         NLB (Network LB)         │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │         Istio Ingress            │
                    │         (service mesh)           │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │       oauth2-proxy               │
                    │       → Keycloak SSO             │
                    └──────────────┬──────────────────┘
                                   │
                    ┌──────────────▼──────────────────┐
                    │       Kubeflow Dashboard         │
                    ├─────────────────────────────────┤
                    │  Notebooks │ Pipelines │ Runs    │
                    └──────────────┬──────────────────┘
                                   │
        ┌──────────────────────────┼──────────────────────┐
        │                          │                      │
┌───────▼───────┐    ┌─────────────▼──────────┐   ┌──────▼───────┐
│ GPU Node Pool │    │  Kubeflow Pipelines    │   │ EFS Shared   │
│ g4dn.xlarge   │    │  RDS PostgreSQL backend│   │ Notebook     │
│ NVIDIA GPU Op │    │  S3 artifact storage   │   │ Storage      │
│ Cluster       │    └────────────────────────┘   └──────────────┘
│ Autoscaler    │
└───────────────┘
```

### Key Components

**RKE2 Cluster:**
- Bare-metal / VM nodes
- Dedicated GPU node pools (g4dn.xlarge)
- NVIDIA GPU Operator for automatic driver injection
- Cluster Autoscaler: scales GPU nodes based on pending unschedulable pods

**Kubeflow Stack:**
- Kubeflow Pipelines: RDS PostgreSQL backend + S3 for artifact storage
- Kubeflow Notebooks: self-service notebook provisioning
- EFS for shared notebook storage across pods

**Auth Flow:**
NLB → Istio → oauth2-proxy → Keycloak → enterprise SSO
- Data scientists get SSO without managing credentials
- No credential management for end users

**GitOps:**
- ArgoCD syncs all platform manifests from Git repository
- Full GitOps lifecycle for platform components

### GPU Scheduling Flow (IMPORTANT — explains autoscaling)

```
1. Data scientist launches training job (requests GPU)
2. Scheduler checks: any node with free GPU? → NO
3. Pod goes to Pending Unschedulable state
4. Cluster Autoscaler detects pending GPU pod
5. Autoscaler provisions new g4dn.xlarge node
6. NVIDIA GPU Operator injects drivers onto new node
7. Pod is scheduled on new GPU node → training starts
8. Training completes → pod terminates
9. No more pending GPU pods → Autoscaler scales node back down
10. GPU cost controlled: nodes only exist during active training
```

### Scale
- 12 data scientists served
- Tripled model-training throughput
- Zero-downtime cluster upgrades every release
- GPU idle-shutdown automation (from FinOps work) stops forgotten instances

---

## Follow-Up Questions (Answer Aloud)

1. **"How did you handle GPU cost?"**
   - Cluster Autoscaler with scale-to-zero for GPU nodes
   - GPU idle-shutdown jobs from FinOps automation
   - GPUs only run when training jobs are active
   - Saves tens of thousands per month

2. **"Why RKE2 for Nightwatch instead of EKS?"**
   - On-prem / disconnected environment
   - No cloud dependency for control plane
   - FIPS support built-in
   - Self-contained binary — can be deployed air-gapped

3. **"How did you handle zero-downtime upgrades?"**
   - Rolling updates on node pools
   - Drain nodes one at a time (cordon + drain)
   - Training jobs have checkpointing — can resume on new node
   - Platform components upgraded via ArgoCD sync waves

4. **"What was the biggest challenge?"**
   - GPU driver compatibility: NVIDIA GPU Operator version must match node kernel
   - Solved by pinning operator version to node AMI kernel version
   - Test upgrades on ephemeral cluster before touching production

---

## Answer Keys + Coaching

- **Real architecture reference:** `ntconcepts-answers.md` — second mermaid chart (K8s namespaces, services, auth flow, cloud services)
- **How to present this:** `deep-dive-coaching-guide.md` — System 5
