# Architecture Practice: VivSoft 7-Stage CI/CD Pipeline

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the 7 pipeline stages as boxes in a flow
2. Show the toggle mechanism (how stages can be skipped)
3. Explain what each stage does and WHY
4. Explain the verification pattern

---

## What You Should Be Able to Draw

### The 7 Stages

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 1. CONFIG    │──→│ 2. INFRA     │──→│ 3. CLUSTER   │──→│ 4. REGISTRY  │
│ Compile      │   │ Terraform    │   │ EKS + AMIs   │   │ Init in-     │
│ Kapitan      │   │ plan/apply   │   │              │   │ cluster reg  │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
       │                  │                  │                  │
       ▼                  ▼                  ▼                  ▼
   [TOGGLE]          [TOGGLE]          [TOGGLE]          [TOGGLE]

┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ 5. CORE      │──→│ 6. ENTERPRISE│──→│ 7. DESTROY   │
│ Platform     │   │ Services     │   │ (optional)   │
│ bundle       │   │ bundle       │   │ TTL-based    │
└──────────────┘   └──────────────┘   └──────────────┘
       │                  │
       ▼                  ▼
   [TOGGLE]          [TOGGLE]

       ┌──────────────────────┐
       │ VERIFICATION JOBS    │ ← runs after EVERY stage
       │ (regardless of       │    regardless of whether
       │  whether stage ran)  │    the stage deployed
       └──────────────────────┘
```

### Stage Details

| Stage | What It Does | Inputs | Outputs |
|-------|-------------|--------|---------|
| **1. Config Compile** | Clones jcrs-cac repo, runs Kapitan compile for target environment | Target name (e.g., `staging-left`) | Compiled scripts, manifests, values |
| **2. Infrastructure** | Terraform plan/apply for VPC, KMS, S3, TGW | Compiled Terraform vars | AWS resources provisioned |
| **3. Cluster** | Provisions EKS cluster on STIG'd AMIs | AMI ID, cluster config | Running K8s cluster |
| **4. Registry** | Initializes in-cluster container registry | Registry config | Local registry ready for images |
| **5. Core Bundle** | Deploys core platform: Istio, Kyverno, Prometheus, Neuvector, etc. | Zarf/UDS core package | Core services running |
| **6. Enterprise Bundle** | Deploys enterprise services: Vault, Keycloak, ArgoCD, GitLab, etc. | Zarf/UDS enterprise package | Enterprise services running |
| **7. Destroy** | Tears down environment (for ephemeral clusters) | TTL expiry or manual trigger | Resources cleaned up |

### Toggle Mechanism

```yaml
# In pipeline config (GitLab CI variables)
DEPLOY_INFRA: "true"           # flip to "false" to skip
DEPLOY_CLUSTER: "true"
DEPLOY_CORE: "true"
DEPLOY_ENTERPRISE: "true"

# Each stage checks its toggle
deploy_enterprise:
  stage: enterprise
  script:
    - ./deploy-enterprise.sh
  rules:
    - if: $DEPLOY_ENTERPRISE == "true"
```

**Why toggles?**
- If you only need to update Vault → flip DEPLOY_ENTERPRISE to true, everything else false
- Saves 45+ minutes compared to full run
- Each stage is idempotent — safe to run again if interrupted
- Reduces blast radius: only deploy what changed

### Verification Pattern

- Runs after EVERY stage, whether the stage deployed or not
- Catches drift between what the pipeline expects and what the cluster is actually running
- Compares: compiled config vs. running state
- If drift detected → flag it before proceeding

### Environment Types

| Type | TTL | Use |
|------|-----|-----|
| Ephemeral | 8 hours | Feature development, integration testing |
| Staging | Persistent | Pre-production validation (staging-left, staging-right) |
| Production | Persistent | Live workloads |

**Promotion flow:**
- Friday: Release branch cut
- Monday: Pipeline deploys to staging
- Tuesday: Promote to production after staging validation passes

---

## Follow-Up Questions (Answer Aloud)

1. **"Why GitLab CI over GitHub Actions or Buildkite?"**
   - GitLab is the standard in DoD environments (Iron Bank has official images)
   - Self-hosted — no external dependencies
   - Built-in container registry, artifacts, and environments
   - Runners can operate in air-gap with local image pulls

2. **"Why toggle-based instead of separate pipelines per component?"**
   - Single pipeline maintains deployment order guarantees
   - Toggles are simpler than orchestrating multiple pipelines
   - Idempotent stages mean no harm in running a stage that's already up-to-date
   - One place to see the full deployment state

3. **"How do you handle rollbacks?"**
   - Each stage is independently rollable
   - Config changes: revert the Kapitan config in Git, rerun pipeline
   - Infrastructure: Terraform state-managed with plan/apply
   - Bundles: Zarf packages are versioned and pinned — deploy previous version
   - Git is the source of truth — revert commit = revert deployment

4. **"What happens if Stage 5 (Core) fails mid-deploy?"**
   - Stage is idempotent — rerun picks up where it left off
   - Verification catches partial deploys
   - Core bundle uses UDS which handles dependency ordering
   - If a specific component fails, fix it and rerun — other components are untouched

---

## Answer Keys + Coaching

- **Real architecture reference:** `vivsoft-answers.md` — Section 7 (CI/CD Pipeline)
- **How to present this:** `deep-dive-coaching-guide.md` — System 3
