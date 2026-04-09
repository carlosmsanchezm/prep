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

### YAML Anchors (DRY — Don't Repeat Yourself)

YAML anchors are a **YAML feature** (not GitLab-specific) that let you define a reusable block once and reference it in multiple places. GitLab CI uses them heavily to reduce duplication.

```yaml
# DEFINE an anchor with & — this is the template
.deploy_template: &deploy_defaults
  image: registry.local/rhel9:latest
  tags:
    - ansible
  before_script:
    - eval $(ssh-agent -s)
    - chmod 400 "$SSH_PRIVATE_KEY"
    - ssh-add "$SSH_PRIVATE_KEY"

# USE the anchor with << and * — merges all keys from the template
deploy_staging:
  <<: *deploy_defaults
  stage: deploy
  script:
    - ansible-playbook -i inventory/staging.yml deploy.yml
  environment: staging

deploy_production:
  <<: *deploy_defaults
  stage: deploy
  script:
    - ansible-playbook -i inventory/production.yml deploy.yml
  environment: production
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual
```

**How it works:**
- `&deploy_defaults` — **defines** the anchor (like a variable assignment)
- `*deploy_defaults` — **references** the anchor (inserts the content)
- `<<:` — **merge key** — merges the anchor's keys into the current mapping
- Any key you define in the job **overrides** the same key from the anchor (script, environment, rules)

**Hidden job trick:** Prefix with `.` (like `.deploy_template`) to make it a "hidden job" — GitLab won't run it as a pipeline job, it's purely a template.

```yaml
# You can also anchor just a list (not a full job)
.common_scripts: &setup_steps
  - echo "Setting up..."
  - source /etc/profile

build:
  script:
    - *setup_steps              # inserts the list here
    - make build

# Or anchor a variables block
.common_vars: &shared_vars
  ANSIBLE_HOST_KEY_CHECKING: "False"
  ANSIBLE_FORCE_COLOR: "true"

deploy:
  variables:
    <<: *shared_vars
    DEPLOY_ENV: "production"    # add job-specific vars alongside shared ones
```

**Why it matters for air-gap:** When every job needs the same local registry image, SSH setup, and runner tags, anchors prevent you from repeating (and potentially mistyping) those lines in every job.

### GitLab Monitoring with Prometheus + Grafana

GitLab exposes metrics natively at `/-/metrics` (Prometheus format). Prometheus scrapes these, Grafana visualizes them.

**What GitLab exposes:**
```
# GitLab built-in metrics endpoint
https://gitlab.dev.internal/-/metrics

# Key metrics:
gitlab_ci_pipeline_duration_seconds    — how long pipelines take
gitlab_ci_jobs_total                   — job count by status (success, failed, canceled)
gitlab_runner_jobs_total               — jobs per runner
gitlab_workhorse_http_requests_total   — HTTP request rates to GitLab
gitaly_disk_usage_bytes                — Git storage disk usage
```

**Runner metrics (separate endpoint):**
```
# GitLab Runner also exposes its own metrics:
http://runner-host:9252/metrics

# Key runner metrics:
gitlab_runner_jobs                       — current running/pending jobs
gitlab_runner_request_concurrency        — concurrent job requests
gitlab_runner_errors_total               — runner errors by type
process_cpu_seconds_total                — runner CPU usage
process_resident_memory_bytes            — runner memory usage
```

**Prometheus scrape config (prometheus.yml):**
```yaml
scrape_configs:
  - job_name: 'gitlab'
    metrics_path: '/-/metrics'
    static_configs:
      - targets: ['gitlab.dev.internal:443']
    scheme: https
    tls_config:
      insecure_skip_verify: true    # for self-signed certs in air-gap

  - job_name: 'gitlab-runner'
    static_configs:
      - targets: ['runner.dev.internal:9252']
```

**Grafana dashboards for GitLab — what to watch:**

| Dashboard panel | PromQL query | Why it matters |
|----------------|-------------|----------------|
| Pipeline duration trend | `gitlab_ci_pipeline_duration_seconds` | Spot slow pipelines — are builds getting slower over time? |
| Job failure rate | `rate(gitlab_ci_jobs_total{status="failed"}[1h])` | Track reliability — are failures increasing? |
| Runner utilization | `gitlab_runner_jobs{state="running"}` | Are runners overloaded? Need more? |
| Runner queue depth | `gitlab_runner_jobs{state="pending"}` | Jobs waiting = not enough runners |
| Gitaly disk usage | `gitaly_disk_usage_bytes` | Running out of Git storage? |
| Runner errors | `rate(gitlab_runner_errors_total[1h])` | Are runners failing to connect, pull images, etc? |

**How to use dashboards to tune GitLab (what Taylor asked):**
- **Pipeline too slow?** → Check which stage takes longest. Cache dependencies. Use parallel jobs.
- **Runners overloaded?** → Increase `concurrent` in runner config.toml. Add more runner instances.
- **Disk filling up?** → Set artifact `expire_in`, clean old pipelines, prune container registry.
- **Jobs stuck in pending?** → Runner queue depth high = add runners or fix tag mismatch.

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
