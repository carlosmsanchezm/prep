# Architecture Practice: IBM Helm Migration

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the BEFORE state, the migration plan, and the AFTER state
2. Narrate as if Andy asked: "Have you migrated a team to Kubernetes before?"
3. Time yourself: 8-10 minutes for the full story

---

## Coaching: How to Present This

### Opening Line
"At IBM Federal, I inherited a dev tool platform running on Docker Compose and Swarm — nine services serving six hundred users, deployed through Makefiles, Python scripts, shell scripts, and a custom templating engine called Gomplate. Five layers of indirection, no rollback, no drift detection. I led the migration to Kubernetes with Helm charts, cut release prep forty percent, and hardened it to STIG/FIPS baselines."

### Drawing Order

**Step 1 — Draw the BEFORE (top half of whiteboard):**

Draw two big boxes side by side:

Left box — **"Config Layer":**
- Inside: Git Repo, values.yaml, config files, templates
- All feed into a box labeled "Gomplate (custom templating)"
- Gomplate outputs to "make command"

Right box — **"Build Layer":**
- "make command" is the central node (big, draw it prominent)
- Branching off make: Makefiles, Shell scripts, Python scripts
- All feed down into "docker-compose / docker stack deploy"

Below both — **"Docker Swarm":**
- Draw a box with the 9 services inside: Jira, Bitbucket, Confluence, Jenkins, Artifactory, Crowd, Accounts-API, Mailman, HTTPD-UI
- Write "600+ users" next to it

Draw a dotted line from the services back up to make — label it "manual monitoring (docker logs)"

Write pain points on the side:
- No rollback — if deploy fails, SSH in and fix manually
- No drift detection — running state might not match code
- Gomplate is custom — nobody else uses it
- Five layers of indirection — config change touches everything
- Every release = multi-hour manual checklist

Say: "This is what I inherited. A single Git repo, per-service configs and templates that feed through Gomplate — a custom templating engine nobody outside this team uses. Gomplate generates config files that feed into the make command, which is the single entry point for everything. Make triggers per-service Makefiles, Python scripts, and shell scripts, which eventually call docker-compose up or docker stack deploy. Five layers of indirection before a container starts. Nine services, six hundred users, no rollback, no drift detection. If something broke, you'd docker-log your way through, trace back through the scripts, and fix by hand."

**Step 2 — Draw the AFTER (bottom half — two parts: the K8s architecture + the workflow):**

This step has two pieces. First draw what each service BECAME in K8s (the architecture), then draw the workflow (how developers and CI/CD interact with it).

**Step 2a — The K8s Architecture (what each service looks like):**

Draw a box labeled "K8s Cluster" and inside it, show one service as an example (Jira):

```
┌─── K8s Cluster ──────────────────────────────────────────────────────┐
│                                                                       │
│  ┌── Jira (example — same pattern for all 9 services) ───────────┐   │
│  │                                                                │   │
│  │  [Deployment]          [Service]           [ConfigMap]          │   │
│  │  - image: jira:8.x     - ClusterIP        - DB_HOST: postgres  │   │
│  │  - replicas: 1         - port 8080         - MEMORY: 4g        │   │
│  │  - resource limits     - selector: app=jira - FEATURE_FLAGS     │   │
│  │  - health checks                                                │   │
│  │     liveness: /healthz                     [Secret]             │   │
│  │     readiness: /ready                      - DB_PASSWORD        │   │
│  │                                            - LICENSE_KEY        │   │
│  │  [PersistentVolumeClaim]                                        │   │
│  │  - 50Gi for Jira data                                           │   │
│  │  - StorageClass: standard                                       │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                       │
│  Same pattern x9: Bitbucket, Confluence, Jenkins, Artifactory,       │
│                    Crowd, Accounts-API, Mailman, HTTPD-UI             │
│                                                                       │
│  [Shared Library Chart]                                               │
│  - Common templates: health checks, resource limits, labels          │
│  - Every service chart inherits from this                            │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

Say: "Each service became the same pattern in Kubernetes. Take Jira: a Deployment defines the container image, replicas, resource limits, and health checks — liveness and readiness probes that didn't exist in Swarm. A Service gives it a stable DNS name so other services find it without hardcoded IPs — replaces Compose's depends_on. A ConfigMap holds the non-sensitive config that used to be in Gomplate templates. A Secret holds passwords and license keys — no more plain text in env files. And a PersistentVolumeClaim for data that survives pod restarts — this was the hardest part for stateful services like Jira and Bitbucket.

I built a shared library chart with common templates — health checks, resource limits, standard labels — so every service chart inherits the same patterns. No copy-paste between charts."

**The Compose-to-K8s translation (know this for when Andy asks "how did you actually make it work?"):**

| Docker Compose field | K8s equivalent | Notes |
|---------------------|----------------|-------|
| `image:` | Deployment `.spec.containers[].image` | Same image, just referenced differently |
| `ports:` | Service (ClusterIP or NodePort) | Service provides stable DNS name + load balancing |
| `volumes:` | PersistentVolumeClaim + PersistentVolume | Hardest part — need StorageClass, reclaim policy |
| `environment:` | ConfigMap (non-sensitive) + Secret (sensitive) | Replaces .env files and Gomplate substitution |
| `depends_on:` | Not needed — K8s services use DNS discovery | `jira` calls `postgres-jira.default.svc.cluster.local` |
| `restart: always` | Default in K8s (restartPolicy: Always) | Plus health checks that Swarm didn't have |
| `deploy.replicas:` | Deployment `.spec.replicas` | Same concept, but K8s adds HPA for auto-scaling |
| `deploy.resources:` | Deployment `.spec.containers[].resources` | requests + limits — K8s enforces these, Swarm didn't |

**What was hardest:**
"Persistent storage for stateful services. In Compose, a named volume is one line. In K8s, it's a PersistentVolumeClaim bound to a PersistentVolume with the right StorageClass and reclaim policy. Wrong reclaim policy and you lose the database on pod restart. I had to design the storage layer carefully — Retain policy for production databases, Delete for ephemeral test data. And migrating existing Jira data from Docker volumes into K8s PVs without downtime required a data sync script I wrote specifically for the migration."

**Step 2b — The Workflow (how developers and CI/CD interact):**

Draw the workflow flow:

```
[Developer] → [Git Repo] → [Helm Charts] → [CI/CD Pipeline] → [Dev Cluster] → [Test Cluster]
                             values.yaml     build/lint/          auto-deploy     promote
                             per env         test/package
```

Say: "The workflow is clean now. Developer clones, modifies Helm chart values, runs helm lint and helm template locally to validate, pushes to Git. CI/CD triggers on push — builds the image, lints the chart, packages it, deploys to the dev cluster automatically. After tests pass on dev, promote to the test cluster. Production promotion is a single helm upgrade command with the production values file."

**Step 3 — Draw the migration plan (side or separate area):**

```
[1. Planning] → [2. Service Migration] → [3. Testing] → [4. Training]
 2 weeks          9 weeks (1/week)         parallel        2 weeks
 standards        service by service       unit/int/UAT    brown-bags
 chart template   controlled blast         at every layer  runbooks
```

Say: "Four phases. Two weeks defining Helm chart standards and a shared template. Nine weeks migrating one service per week — Bitbucket first as the pilot, then Jira, Confluence, and so on. Controlled blast radius — if Bitbucket's migration breaks, only Bitbucket is affected. Testing ran in parallel: unit tests on Helm template output, integration tests per service, full stack system tests. Final two weeks were training — brown-bag sessions, runbooks, and self-healing guides so ops could handle eighty percent of incidents without me."

### What to Emphasize
1. **The before state mirrors Anduril** — "Your Podman Compose and manual deploys? That's exactly where IBM was."
2. **Service-by-service, not big-bang** — "I never migrated everything at once. One service per week, tested, validated, then next."
3. **40% release prep reduction** — concrete metric
4. **600+ users never went down** — migration happened under live production
5. **Team training** — "I didn't just migrate and leave. Brown-bag sessions, runbooks, self-healing docs — eighty percent of incidents could be resolved without me."

### Component Deep-Dive Prep

**Helm Charts — study these concepts:**
- Chart structure: Chart.yaml, values.yaml, templates/, helpers
- Values override chain: default → per-environment → per-release
- Hooks: pre-install, post-install, pre-upgrade (used for DB migrations)
- Dependencies: how charts depend on other charts (requirements.yaml / Chart.yaml dependencies)
- Library charts: shared templates across services
- helm template (dry-run render), helm lint (validation), helm diff (show changes)
- helm rollback: how it works (reverts to previous release revision)

**Jenkins Pipeline — study these concepts:**
- Declarative pipeline: stages, steps, post actions
- Azure DevOps agents (IBM used these as build agents)
- Artifact storage: pushing Helm packages to a chart repo
- Test harnesses: unit (helm template output validation), integration (deploy to dev), system (full stack test)

**The 9 Services — know them:**
| Service | What It Does | Migration Notes |
|---------|-------------|-----------------|
| Bitbucket | Git hosting | Needed persistent volume for repos |
| Jira | Issue tracking | Complex config, custom plugins |
| Confluence | Wiki/docs | Large persistent storage |
| Jenkins | CI/CD | Pipeline configs as code |
| Artifactory | Artifact registry | Critical — other services depend on it |
| Accounts-API | User management | Custom app, needed health checks |
| Crowd | SSO/directory | Replaced later by Keycloak |
| Mailman | Email lists | Simple service, migrated first as proof |
| HTTPD-UI | Web frontend | Nginx-based, straightforward |

### Tradeoffs to Know

**"Why Helm over Kustomize?"**
"Helm gives us packaging — a chart is a self-contained artifact you can version, share, and deploy. Kustomize patches existing YAML but doesn't package it. For nine services with shared patterns, Helm's templating and library charts saved us from maintaining nine separate Kustomize bases."

**"Why one service per week?"**
"Controlled blast radius. If the Bitbucket migration breaks, only Bitbucket is affected — not all nine services. It also let the team learn Helm incrementally instead of drinking from the firehose."

**"Why not just Docker Compose to Docker Compose with better scripts?"**
"Compose doesn't give you orchestration — no auto-restart, no rolling updates, no resource limits, no health checks. K8s with Helm gives us all of that plus declarative state. The gap between 'working Compose' and 'reliable production' was what kept causing outages."

**"What would you change?"**
"I'd have started with a shared library chart from day one. We ended up with duplicated template patterns across the first four services, then refactored into a library. Starting with the library would have saved two weeks of rework."

### Bridging to Anduril
"Your setup today — Podman Compose files, manual deploys, Makefiles maybe — that's exactly where IBM was when I started. The path I'd propose is the same: define standards, pick a pilot service, convert to Helm, validate, then service by service. With your pace, we could have the first service migrated in two weeks, and if it doesn't add value, we stop. No big-bang risk."

---

## Deep Understanding: Know This Cold

> If you can't answer these questions conversationally, you can't survive Andy's probing. Study this section until you can explain each concept without looking.

### The Config Layer — What Are All These Files?

**Q: What are .tmpl files?**
Template files — config files with placeholder variables like `{{ .Env.DB_HOST }}`. They're NOT the final configs. Gomplate reads these templates and substitutes the variables with real values to produce the actual config files that services use. Think of them as Jinja2 templates but in Gomplate's syntax.

**Q: What are "individual config files per service"?**
Each of the 9 services (Jira, Bitbucket, etc.) had its own config files — like `jira-config.yaml`, `bitbucket-settings.env`, etc. These contained service-specific settings: database URLs, ports, memory limits, feature flags. They were separate from the templates.

**Q: What is `config/local/values.yaml`?**
A single YAML file containing the variables that Gomplate substitutes into the templates. Things like: `DB_HOST: postgres-jira`, `JIRA_PORT: 8080`, `MEMORY_LIMIT: 4g`. Different environments (local, staging) had different values files — but the templates were the same.

**Q: So how does the config flow work?**
1. Templates (.tmpl files) define the STRUCTURE: "database host is {{ .Env.DB_HOST }}"
2. Values (values.yaml) define the DATA: "DB_HOST: postgres-jira"
3. Individual config files provide service-specific overrides
4. Gomplate reads all three, substitutes variables, outputs the FINAL config files
5. These final configs get used by the make/deploy process

**Q: What is Gomplate?**
Gomplate is a command-line template engine — like Jinja2 or Helm's Go templates, but standalone. You feed it a template file + data sources (env vars, YAML, JSON), it substitutes and outputs the result. The problem: it's niche. Nobody outside a few Go projects uses it. No community, hard to debug, hard to hire for. Kapitan (which you used at VivSoft) solves the same problem but with class inheritance and is more widely used in the DoD/platform space.

**Q: How to explain Gomplate if Andy asks:**
"Gomplate is a standalone template engine — think Jinja2 but for Go. You give it template files with placeholders and a data source like a YAML values file, and it outputs the final configs. The problem was it's extremely niche — no community, no IDE support, debugging was manual. When I migrated to Helm, Helm's built-in Go templating replaced Gomplate entirely. Same concept, industry-standard tool."

### The Dev & Config Layer — Where Does This Run?

**Q: Is the "Development & Configuration Layer" a developer's laptop or a server?**
Both. The Git repo lives on a remote server (Bitbucket — they used their own Bitbucket instance for source control). But the config layer (running Gomplate, running make) happens on a developer's local machine OR on a shared build server. There was no proper CI/CD for the Compose/Swarm setup — it was manually triggered.

**Q: What were the environments?**
Three environments, simple separation:
- **Dev (local machines):** Each developer clones the repo, runs `docker-compose up` on their laptop to bring up the services locally. Tests changes against the local stack. Pushes code to Bitbucket when ready.
- **Test (shared environment):** A shared server running the full 9-service stack via Docker Swarm. Used for integration testing and validation before production.
- **Production:** The live environment that six hundred engineers used daily. Same infrastructure as test but separate — production values, production data.

**Q: How did the 2-week release cycle work?**
Releases happened every two weeks on a sprint cadence:
1. **Weeks 1-2:** Development. Changes accumulate in Git. Developers test locally with `docker-compose up`.
2. **End of sprint:** Code freeze. I pull the latest code on the test server, run `make deploy` with test environment values. Gomplate generates the test configs, scripts execute `docker stack deploy`. All nine services come up on the test instance.
3. **Validation (1-2 days):** Team validates — hit each service's web UI, verify integrations work (Jira connects to its database, Bitbucket syncs with Crowd SSO, Jenkins builds trigger correctly). Manual smoke testing.
4. **Production deploy:** After test passes, same process on the production infrastructure. Pull code, run `make deploy` with production values.yaml. Same Gomplate → Makefiles → scripts → `docker stack deploy` chain, just pointing at production.
5. **Verification:** Check all nine services are up — `docker ps`, hit each web UI, verify six hundred users can access everything.
6. **Rollback plan:** If something breaks — revert the Git commit, re-run `make deploy` with the previous code. Not automated, not fast, but it worked. The gap: no revision history on the deployment itself. You had to know WHICH commit to revert to.

**Q: How did `make deploy` know which environment to target?**
The values files. `config/local/values.yaml` for local dev, `config/test/values.yaml` for the test environment, `config/prod/values.yaml` for production. Gomplate reads the right values file based on an environment variable or a make target: `make deploy-test` vs `make deploy-prod`. Same templates, different values — that's the one thing Gomplate did well.

**Q: What was the pain with this release process?**
1. **Manual promotion** — a person had to SSH to the test server, pull code, run make. Then do it again on production. No pipeline, no automation.
2. **No atomic rollback** — reverting meant finding the right Git commit, re-running make, and hoping the same Gomplate configs generated the same output. No `helm rollback` equivalent.
3. **Config drift** — between the time you deployed to test and deployed to production, someone might have changed a config file. No way to detect it.
4. **Downtime risk** — `docker stack deploy` replaces containers one by one, but Swarm's rolling update strategy was basic. No health checks gating the rollout. If the new container crashed, users saw errors until someone noticed and rolled back manually.
5. **Release prep took hours** — manually checking each service, verifying configs, running make targets in order. This is the "forty percent reduction" metric: Helm made this a single command.

**Q: This was for DoD / TRMC — was this production?**
Yes. These nine services (Jira, Bitbucket, Jenkins, etc.) were the development infrastructure for the entire TENA program — six hundred engineers used them daily to write, build, and test code. It wasn't a customer-facing app, but it was production in the sense that if Jira went down, six hundred people couldn't file issues. If Jenkins went down, builds stopped. If Bitbucket went down, nobody could push code. Mission-critical internal tooling for the DoD Test Resource Management Center.

### The Build Layer — How Does It Actually Work?

**Q: What is a Makefile? What are .mk files?**
A Makefile defines "targets" — named commands you can run with `make <target>`. Example: `make deploy-jira` might call a shell script that runs docker-compose for Jira. The main `Makefile` at the repo root is the entry point. `.mk files` are include files — separate Makefiles per service or per concern that get included into the main one. So `jira.mk` has all Jira build targets, `bitbucket.mk` has Bitbucket targets, etc. `make` reads the main Makefile which includes all the .mk files.

**Q: What's a "build target"?**
A named command in a Makefile. Like `deploy-all`, `deploy-jira`, `build-images`, `clean`. You type `make deploy-jira` and it executes the commands defined for that target. The .mk files define per-service targets.

**Q: Why is `make` the central node?**
Because that's how it was designed — `make` was the single entry point for EVERYTHING. Want to deploy? `make deploy`. Want to build images? `make build`. Want to clean up? `make clean`. All roads went through make, which then called Makefiles, which called scripts, which called docker commands. It centralized control but also centralized fragility — if the Makefile broke, nothing worked.

**Q: What did the Python scripts do? Shell scripts?**
- **Python scripts:** config generation (reading values.yaml, producing env files), validation (checking configs before deploy), some data migration scripts
- **Shell scripts (Bash):** deployment glue — `docker-compose up`, `docker stack deploy`, health checks (`curl` the service, check status), log tailing, cleanup. Also rsync for moving files between environments.
- Both were called BY the Makefiles, not directly by developers. The chain: `make deploy-jira` → calls `scripts/deploy-jira.sh` → runs `docker-compose -f jira/docker-compose.yml up -d`

**Q: Was the build triggered by CI/CD or manual?**
**Manual for the Swarm deployment.** A developer or ops person would SSH to the build server, pull the latest code, and run `make deploy`. There was no CI/CD pipeline for the Compose/Swarm setup — that was one of the major problems. After the Helm migration, I set up a CI/CD pipeline that automated everything on git push.

### The Container Runtime — Docker Swarm

**Q: How did docker-compose / docker stack deploy actually work?**
The build chain produced the final config files and then called:
- `docker-compose up -d` for local dev (brings up all services on the developer's laptop)
- `docker stack deploy -c docker-compose.yml <stack-name>` for the shared environment (deploys to Docker Swarm)

The docker-compose.yml files defined: which image to use, which ports to expose, which volumes to mount, environment variables, restart policies. Swarm added basic orchestration: if a container died, Swarm restarted it. But no rolling updates, no health checks, no resource limits.

**Q: Did the build layer CREATE the Compose files, or were they static?**
The Compose files were mostly static — they lived in the Git repo. But Gomplate would substitute variables into them (like the database host, image tag, port numbers). So the TEMPLATE of the Compose file was in Git, Gomplate filled in the values, and then `docker-compose up` ran the result.

**Q: Would Nix have been better than Makefiles?**
Interesting question — if Andy asks this: "Nix solves a different problem. Makefiles orchestrate build steps. Nix provides reproducible builds — guaranteeing the SAME environment everywhere. For IBM's problem, the issue wasn't reproducibility — it was the lack of orchestration, rollback, and drift detection. Nix wouldn't have solved those. What solved them was moving from imperative scripting (Makefiles → scripts → docker) to declarative state management (Helm charts on Kubernetes). That said, if you combine Nix for reproducible image builds WITH Helm for deployment, you get the best of both worlds — which is actually what Anduril does with their Nix-based build system."

### Production and CI/CD — The Gaps

**Q: Where is CI/CD in the before state?**
**It didn't exist for platform deployment.** There was a Jenkins instance (one of the 9 services), but it was used by the engineering teams for THEIR application builds, not for deploying the dev tool platform itself. We maintained and managed Jenkins for the users, but the platform's own deployment was manual: SSH to the server, git pull, run `make deploy-test` or `make deploy-prod`. No pipeline for our own infrastructure, no gates, no automated testing of the platform itself. The 2-week release cycle was entirely human-driven.

After the Helm migration, I set up a CI/CD pipeline that automated: build images → lint charts → package → deploy to dev cluster → test → promote to test cluster. The promotion from test to production became a single `helm upgrade` command with the production values file — not a multi-hour manual process.

**Q: If Andy asks "what CI tool did you use?"**
"We used the CI tooling available on the platform — the migration focused on building the pipeline automation itself: build, lint, package, deploy, test, promote. The tool was less important than establishing the automated promotion path — before, deployment was entirely manual."

**Q: How would you summarize the before vs after release process?**
"Before: two-week sprints, end of sprint someone SSH'd to the test server, pulled code, ran make deploy, manually validated all nine services, then repeated the same process on production. Release prep took hours, rollback was a gamble. After: developer pushes code, pipeline automatically builds images, lints charts, packages, deploys to dev cluster, runs tests. Promotion to test is one command. Promotion to production is one command. Rollback is `helm rollback` to any previous revision. The same release that used to take hours now takes minutes."

---

## Answer Keys

- **Real architecture diagrams:** `ibm-migration-answers.md`
- **How to present this system:** this file's coaching section above
- **Related Anduril scenario:** `anduril-scenarios.md` Scenario 4 (Introduce K8s to Podman team)
