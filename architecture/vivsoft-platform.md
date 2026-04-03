# Architecture Practice: VivSoft JCRS-E Platform

## Exercise: Draw and Narrate

**Instructions:**
1. Get a blank sheet of paper (or whiteboard)
2. Set a timer for 10 minutes
3. Draw the 6-layer platform architecture from memory
4. Narrate out loud as you draw — explain what each layer does and WHY
5. After drawing, answer the follow-up questions below out loud (3-5 min each)

---

## What You Should Be Able to Draw

### The 6 Layers (bottom to top)

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
