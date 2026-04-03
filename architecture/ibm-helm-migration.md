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

**Step 2 — Draw the AFTER (bottom half — show the contrast):**

Draw a clean, simple flow:

```
[Git Repo] → [Helm Charts] → [Jenkins CI Pipeline] → [Registry] → [Dev Cluster] → [Test Cluster]
              values.yaml      build → lint → test      versioned     auto-deploy     promote
              per environment  → package → deploy       images
```

Say: "Here's where I took them. Helm charts for all nine services — declarative, versioned, rollbackable. Jenkins pipeline handles build, lint, package, deploy, test — all automated. Each environment gets its own values.yaml — no more Gomplate. One command deploys, one command rolls back. Cut release prep forty percent. The platform went from five layers of manual scripting to a single Helm upgrade command."

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

## Answer Keys

- **Real architecture diagrams:** `ibm-migration-answers.md`
- **How to present this system:** this file's coaching section above
- **Related Anduril scenario:** `anduril-scenarios.md` Scenario 4 (Introduce K8s to Podman team)
