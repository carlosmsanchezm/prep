# CI/CD Cheatsheet — Memorize This

## GitLab CI (.gitlab-ci.yml)

### Basic Structure
```yaml
stages:
  - lint
  - build
  - scan
  - test
  - deploy

variables:
  REGISTRY: registry.local:5000
  IMAGE_NAME: my-app

# Lint stage
lint:
  stage: lint
  image: hadolint/hadolint
  script:
    - hadolint Dockerfile

# Build stage
build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA .
    - docker push $REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
  artifacts:
    paths:
      - build/

# Scan stage
scan:
  stage: scan
  image: aquasec/trivy
  script:
    - trivy image --exit-code 1 --severity HIGH,CRITICAL $REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
  allow_failure: false

# Test stage
test:
  stage: test
  image: python:3.11
  script:
    - pip install -r requirements.txt
    - pytest tests/ -v
  artifacts:
    reports:
      junit: report.xml

# Deploy stage
deploy:
  stage: deploy
  script:
    - kubectl set image deployment/my-app my-app=$REGISTRY/$IMAGE_NAME:$CI_COMMIT_SHA
    - kubectl rollout status deployment/my-app --timeout=120s
  environment:
    name: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual                     # require manual approval
```

### Key Concepts
```yaml
# Run only on specific branches
rules:
  - if: $CI_COMMIT_BRANCH == "main"
  - if: $CI_MERGE_REQUEST_IID         # merge requests only

# Dependencies between jobs
deploy:
  stage: deploy
  needs: ["build", "scan"]             # only run after these succeed

# Cache (persist between pipeline runs)
cache:
  key: ${CI_COMMIT_REF_SLUG}
  paths:
    - node_modules/
    - .pip-cache/

# Artifacts (pass between stages)
artifacts:
  paths:
    - build/
  expire_in: 1 hour

# Before/after scripts (run for every job)
default:
  before_script:
    - echo "Starting job $CI_JOB_NAME"
  after_script:
    - echo "Finished job $CI_JOB_NAME"

# Tags (run on specific runners)
build:
  tags:
    - docker
    - linux
```

### Common Variables
```
$CI_COMMIT_SHA          — full commit hash
$CI_COMMIT_SHORT_SHA    — short commit hash
$CI_COMMIT_BRANCH       — branch name
$CI_COMMIT_TAG          — tag name (if tagged)
$CI_PIPELINE_ID         — pipeline ID
$CI_JOB_NAME            — job name
$CI_PROJECT_DIR         — project checkout directory
$CI_REGISTRY_IMAGE      — project container registry path
```

## ArgoCD

### Application CRD
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://git.local/my-org/my-app.git
    targetRevision: main
    path: k8s/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true              # delete resources removed from Git
      selfHeal: true           # revert manual changes to match Git
    syncOptions:
      - CreateNamespace=true
```

### Key Concepts
- **GitOps**: Git is the single source of truth. ArgoCD watches Git and syncs cluster state.
- **Sync**: ArgoCD compares desired state (Git) vs live state (cluster) and reconciles.
- **Prune**: Delete resources from cluster that were removed from Git.
- **Self-Heal**: Revert manual changes made directly to the cluster.
- **Health Check**: ArgoCD checks resource health (Pod Running, Deployment Available, etc.).
- **Sync Waves**: Control order of resource creation (e.g., namespace before deployment).
- **App of Apps**: One ArgoCD Application that manages other Applications.

### ArgoCD in Air-Gap
- Git repo is LOCAL (not github.com) — pushed via diode or manual transfer
- Container images come from LOCAL registry (Harbor, Nexus)
- ArgoCD watches local Git, pulls images from local registry
- No external webhooks — ArgoCD polls on an interval (default 3 min)

## Pipeline Design Pattern

### Standard Flow
```
lint → build → scan → test → push → deploy → verify
```

### What Each Stage Does

| Stage | Purpose | Tools |
|-------|---------|-------|
| **lint** | Check code style, config syntax | hadolint, yamllint, shellcheck, ansible-lint |
| **build** | Compile code, build container image | docker build, buildah, kaniko, nix build |
| **scan** | Find vulnerabilities in image/code | trivy, grype, sonarqube, snyk |
| **test** | Run unit/integration tests | pytest, go test, bats |
| **push** | Store artifacts in registry | docker push, helm push, zarf create |
| **deploy** | Apply to target environment | kubectl apply, argocd sync, helm upgrade |
| **verify** | Confirm deploy succeeded | kubectl rollout status, health checks, smoke tests |

### Air-Gap Pipeline Pattern
```
[Connected Side]                    [Air-Gap Side]
build → scan → bundle → transfer → unpack → deploy → verify
                  ↓         ↓
              Zarf/tar    diode/
                          USB/S3
```

### Pipeline Properties to Know
- **Idempotent** — running the pipeline twice produces the same result
- **Immutable artifacts** — images are tagged with commit SHA, never overwritten
- **Fail fast** — lint and scan run early, before expensive deploy
- **Rollback** — `kubectl rollout undo` or revert Git commit
- **Toggle-based** — can skip stages that haven't changed (VivSoft pattern)

## Trivy (Scanner)

```bash
# Scan container image
trivy image my-image:latest

# Fail on HIGH/CRITICAL
trivy image --exit-code 1 --severity HIGH,CRITICAL my-image:latest

# Scan filesystem
trivy fs /path/to/project

# Scan Kubernetes manifests
trivy config /path/to/manifests/

# Output as JSON
trivy image -f json -o results.json my-image:latest
```
