# Anduril Onsite — Final 7-Day Prep Plan

## What They Actually Asked (from all transcripts)

### Andy Carroll (Hiring Manager — YOUR Round 1)
From the HM call, Andy specifically asked about:
- **Ansible** — "are you writing your own roles or integrating?" He probed: custom vs community
- **RKE2** — "have you stood up clusters from scratch? deployed RKE2 clusters?" He wants to put RKE2 on aircraft networks
- **Air-gap** — "have you populated registries? owned the whole chain?" They just got a diode live
- **Software dev support** — containerization, pipelines, build tools for engineering teams
- **ArgoCD** — he specifically asked about it
- **Culture/pace** — context switching, day-to-day firefighting vs roadmap
- **Your background walkthrough** — career progression, what excites you

**Pattern:** Andy asks conversationally, lets you talk, then probes deeper on what interests him. He doesn't rapid-fire concepts — he digs into YOUR experience. The whiteboard will be him asking you to draw something YOU built, not a hypothetical.

### Andrew Lunceford (Infrastructure — similar to what Taylor might ask)
Andrew asked:
- **Linux troubleshooting** — "web app down on single bare-metal host, what do you check?"
- **Networking basics** — IP address, subnet mask, gateway purpose, how does the interface know its subnet, when does it use the gateway
- **DNS** — what is it, record types, dig output analysis, troubleshooting "name resolves but IP doesn't"
- **Motivation** — what excites you about the work

**Pattern:** Fundamental concept checks + troubleshooting scenarios. Short answers expected. Then one passion question at the end.

### Okta Interviews (shows what SENIOR interviewers look for)
Dinesh and Sean asked:
- **STAR behavioral** — "security outcome with engineering-first mindset"
- **Greenfield architecture** — "walk me through what you built, how you broke it down, team size"
- **Hands-on vs design split** — "60-40 or 70-30?"
- **Scripting examples** — "what did you actually script?"
- **Air-gap pipeline architecture** — "how would you architect CI/CD in disconnected environment?"
- **Security best practices** — not tools, but WHAT you're trying to achieve and risks
- **Compliance gaps** — "what's the remaining 10%? how do you control it?"
- **Pushback on leadership** — "time you pushed back on VP/CTO"
- **Balancing roadmap vs execution** — how do you split your time

**Pattern:** Senior interviewers want DEPTH — not just "I used Terraform" but "here's the specific module I wrote, why I chose this approach, what the tradeoff was, what I'd change."

---

## What This Means for the Onsite

### Round 1: Andy Carroll (Technical Deep Dive / Whiteboard) — 45 min

**He will almost certainly ask:**
1. "Walk me through your current platform" or "most complex thing you've built" → VivSoft JCRS-E
2. Something about RKE2 — he asked in the HM call, it's their goal → Nightwatch story
3. Something about Ansible — "how did you bootstrap nodes?" → Ansible RKE2 roles
4. Air-gap delivery — "how do you get software to disconnected networks?" → Zarf/bundling
5. "What would you do for us?" → The Anduril K8s pitch

**He might ask (based on patterns):**
- "Draw your architecture on the whiteboard" → be ready to draw VivSoft layers OR Nightwatch RKE2
- "How would you approach K8s rollout here?" → the phased pitch
- "Tell me about a time something broke" → Kapitan failure story (Story 14)

**He probably won't ask:**
- Rapid-fire concept questions (that was Andrew's style, not Andy's)
- LeetCode or algorithm questions
- Deep Helm template syntax or K8s YAML (that might be Taylor)

### Round 2: Taylor Hine (Technical Hands-On) — 45 min

**Based on Felipe's description of Taylor + Andrew's interview style:**
1. Linux troubleshooting scenarios — "this service is down, walk me through debugging"
2. Ansible — might ask you to write or debug a playbook
3. Podman — rootless troubleshooting, compose issues, registry config
4. GitLab CI — pipeline debugging, runner configuration
5. Networking — DNS, firewall, connectivity debugging (Andrew's style questions)
6. Possibly: "here's a broken config, find the bugs" (read-and-fix style)

**Important: No AI agent backup for this round.** You need to know the commands from memory or be able to work through problems out loud. Talk through your thinking — they evaluate process, not perfection.

---

## The 3 Systems to Know Cold

| System | For which question | What to draw | Time to narrate |
|--------|-------------------|-------------|-----------------|
| **VivSoft JCRS-E** | "Walk me through your platform" | 6 layers, multi-repo, toggle pipeline | 5-8 min |
| **IBM Helm Migration** | "Have you migrated to K8s?" (YOU steer to this) | Before (Compose/Swarm mess) → After (Helm/K8s clean) | 5-8 min |
| **Nightwatch RKE2** | "RKE2 experience?" / "Air-gap K8s?" | AWS foundation, RKE2 cluster, Ansible bootstrap, Bird-Dog network | 5-8 min |

**You don't need to memorize all three diagrams perfectly.** You need to be able to:
1. Draw the KEY boxes and arrows from memory
2. Narrate WHY each component exists (not just WHAT)
3. Answer follow-up probes 2-3 levels deep
4. Bridge to Anduril's problems

---

## 7-Day Schedule

### Days 1-2: Architecture (Andy's round)

**Morning (3 hours each day):**
- Day 1: Draw VivSoft JCRS-E from memory → check against `vivsoft-answers.md` → note gaps → redraw
- Day 2: Draw Nightwatch RKE2 from memory (DevOps-focused, Chart 3b) → check → note gaps → redraw

**Afternoon (2 hours each day):**
- Day 1: Read `ibm-helm-migration.md` Deep Understanding section. Draw the before/after from memory. Practice narrating the migration story aloud.
- Day 2: Read `nightwatch-rke2.md` Ansible walkthrough. Practice explaining the RKE2 bootstrap flow aloud — "I run ansible-playbook, it SSHs to every node..."

**Evening (1 hour each day):**
- Read `k8s-refresher.md` — 2-3 sections per night. Understand the mechanics: HA/etcd, IRSA, ArgoCD flow, Cluster Autoscaler.

### Day 3: The Pitch + Tradeoffs

**Morning (3 hours):**
- Practice the Anduril K8s migration pitch from `anduril-k8s-migration-pitch.md` — deliver it aloud, cold, no notes
- Practice the 3 narrative strategies for bringing it up
- Practice the bridge hooks: "Speaking of containers, at IBM I migrated..."

**Afternoon (2 hours):**
- Read `tradeoff-questions.md` — ALL motivations sections (IBM, Nightwatch, VivSoft, Governance)
- Practice answering "why did you choose X over Y?" aloud for 5 random tradeoffs

**Evening (1 hour):**
- Read `anduril-scenarios.md` — the 5 real Anduril problems. These are what you'd propose to Andy.

### Days 4-5: Hands-On (Taylor's round)

**Morning (2 hours each day):**
- Architecture review: redraw ONE system from memory (VivSoft on Day 4, Nightwatch on Day 5). Check gaps. Quick — 30 min max, then move on.

**Afternoon (3 hours each day):**
- Day 4: Hands-on drills
  - `cheatsheets/ansible.md` — read, then write an RKE2 bootstrap role from memory (check against `drills/day4/ansible-rke2-bootstrap.yml`)
  - `cheatsheets/linux-troubleshooting.md` — practice the "web app down" troubleshooting flow aloud
  - `cheatsheets/networking.md` — practice DNS/firewall commands from memory

- Day 5: Hands-on drills
  - `cheatsheets/podman.md` — know rootless, compose, registries.yaml, SELinux :Z
  - `cheatsheets/bash.md` — practice writing a short script (checksum validator)
  - `drills/day5/kubectl-speed-round.md` — type 20 kubectl commands as fast as you can

**Evening (1 hour each day):**
- Review any GAPS from architecture practice
- Re-read the K8s refresher sections you're weakest on

### Day 6: Mock Interview

**Morning (3 hours):**
- Full Andy mock: Open `drills/day6-mock/deep-dive-prompts.md`
  - Answer 10 questions ALOUD, timed (3-5 min each)
  - For 3 of them, draw on paper while narrating
  - Record yourself if possible — listen back
  - Deliver the Anduril K8s pitch cold — no notes

**Afternoon (2 hours):**
- Full Taylor mock: Open `drills/day6-mock/hands-on-challenge.md`
  - 45-minute timer
  - Ansible role + debug broken YAML + network diagnosis
  - NO AI — Google/docs okay
  - Talk aloud as you work

**Evening (1 hour):**
- Review `drills/day6-mock/questions-for-interviewers.md` — pick 3-4 for Andy, 2-3 for Taylor
- Review your "tell me about yourself" answer
- Review the narrative strategies for steering

### Day 7: Light Review + Rest

- Re-draw your WEAKEST system one more time (whichever had the most gaps)
- Deliver the K8s pitch one final time — cold
- Review 3 tradeoff questions from `tradeoff-questions.md`
- Review your questions for Andy and Taylor
- Review `GUIDE.md` Key Reminders section
- **REST.** Don't cram. Trust the week.

---

## What to Bring / Prepare Day-Of

- **Phone with Grok loaded** — paste `INTERVIEW_INFRASTRUCTURE_PROMPT.md` + `CARLOS_INTERVIEW_KNOWLEDGE_BASE.md` before leaving. If connectivity works in the building, you have backup. If not, you've prepped all week without it.
- **Whiteboard marker preference** — ask if they have markers. If you bring your own, black + blue + red covers everything.
- **Questions written down** — 3-4 for Andy, 2-3 for Taylor, on a notecard in your pocket.
- **Water** — dry mouth kills delivery. Ask for water before you start.

---

## If You Can't Use the AI Agent During the Interview

The prep this week is designed so you DON'T need it. Here's what to rely on:

**For Andy's round (architecture/whiteboard):**
- You've drawn each system multiple times — muscle memory kicks in
- You've narrated the stories aloud — the words flow naturally
- You have the tradeoffs memorized — "why X over Y?" has a prepared answer
- You have the pitch rehearsed — it's 3-5 minutes, practiced cold

**For Taylor's round (hands-on):**
- You know the troubleshooting flow: service → logs → resources → network → firewall
- You've written Ansible tasks from memory
- You know kubectl commands
- You can talk through problems even if you can't type every command perfectly — process matters more than syntax

**The honest play if you're stuck:**
"I know the approach — here's how I'd think through this. In practice, I'd reference the docs for exact syntax, but the logic is: check if the service is running, then check logs, then check network..."

That's not weakness — that's how senior engineers actually work. Andy and Taylor both know this.

---

## Depth Levels — What "3-4 Levels Deep" Means for Each System

Andy starts broad and drills until you hit your limit. Here's what each level looks like and what to study.

### System 1: Nightwatch RKE2 (HIGHEST PRIORITY)

| Level | Andy asks | You answer | Study in |
|-------|-----------|-----------|----------|
| 1 | "Tell me about your RKE2 experience" | "Built an RKE2 cluster air-gapped — 3 control plane for HA, CPU and GPU workers, ArgoCD for GitOps, Ansible for bootstrap. Inside our Bird-Dog hub-and-spoke network with deny-by-default egress." | `nightwatch-rke2.md` opening line |
| 2 | "How did you bootstrap the nodes?" | "Ansible roles — common role disables swap, loads kernel modules, opens firewall ports on ALL nodes. rke2-server role for control plane runs serial:1 so etcd quorum forms correctly — first node bootstraps, others join. rke2-agent role for workers runs parallel. One ansible-playbook command runs everything." | `nightwatch-rke2.md` Ansible walkthrough |
| 3 | "What's in the server config?" | "config.yaml: token for auth, server URL for joining, CIS profile for hardening, TLS SANs for the NLB IP. First node gets cluster-init:true, others point to its URL on port 9345. registries.yaml redirects docker.io and ghcr.io to our ECR — containerd never hits public internet." | `nightwatch-rke2.md` RKE2 Bootstrap table + registries.yaml |
| 4 | "Why embedded etcd? What if a node dies?" | "Raft consensus — 3 nodes need 2 to agree on every write. Lose 1, the other 2 still have quorum. No external etcd to manage — RKE2 handles lifecycle. Dead node comes back, auto-rejoins and catches up. Chose embedded over external because simpler ops for our scale." | `k8s-refresher.md` Section 1 |

**Study list to reach Level 4:**
- `nightwatch-rke2.md` — full Ansible walkthrough (roles, inventory, site.yml, templates)
- `nightwatch-rke2.md` — RKE2 Bootstrap 8-step table
- `nightwatch-rke2.md` — registries.yaml file with explanation
- `nightwatch-rke2.md` — RKE2 ports table (memorize: 6443, 9345, 10250, 2379-2380, 8472/UDP)
- `k8s-refresher.md` Section 1 — HA/etcd quorum
- `k8s-refresher.md` Section 3 — Cluster Autoscaler flow
- `k8s-refresher.md` Section 5 — ArgoCD/GitOps flow
- `k8s-refresher.md` Section 7 — IRSA/OIDC (how pods get AWS access)
- `ntconcepts-answers.md` Chart 3b — the DevOps-focused mermaid diagram

### System 2: IBM Helm Migration (VALUE PROPOSITION)

| Level | Andy asks | You answer | Study in |
|-------|-----------|-----------|----------|
| 1 | "Have you migrated to K8s?" | "Yes — at IBM, migrated 9 services from Docker Compose/Swarm to K8s with Helm. Cut release prep 40%. Six hundred users, zero downtime during migration." | `ibm-helm-migration.md` opening line |
| 2 | "What was the before state?" | "One Git repo, per-service configs fed through Gomplate — a custom templating engine — into Makefiles that called Python and shell scripts that ran docker-compose or docker stack deploy. Five layers of indirection, no rollback, no drift detection. Every release was a multi-hour manual checklist." | `ibm-helm-migration.md` Step 1 narration |
| 3 | "How did you get services into K8s?" | "Containers already existed — Docker images for all 9. I translated each Compose definition: image → Deployment, ports → Service, volumes → PVC with StorageClass, environment → ConfigMap for non-sensitive and Secret for sensitive. depends_on → not needed, K8s services use DNS. Hardest part was persistent storage — PVCs need reclaim policies. Retain for production databases, Delete for test." | `ibm-helm-migration.md` Compose-to-K8s table + Deep Understanding |
| 4 | "How did you migrate Jira's database without downtime?" | "Rsync'd Docker volume data into K8s PV via a temporary migration pod. Ran during maintenance window for Bitbucket's 100Gi repos — took hours. Checksummed everything. Kept old Docker volumes as backup for one release cycle. Wrong reclaim policy would lose the database — I used Retain and tested rollback before the real migration." | `ibm-helm-migration.md` Deep Understanding Q&A |

**Study list to reach Level 4:**
- `ibm-helm-migration.md` — GAPS section (what you missed drawing)
- `ibm-helm-migration.md` — Deep Understanding Q&A (config flow, Gomplate, make chain, deployment glue)
- `ibm-helm-migration.md` — K8s Fundamentals section (Deployments, Services, PVCs, probes, ConfigMaps vs values.yaml)
- `ibm-helm-migration.md` — Compose-to-K8s translation table
- `ibm-helm-migration.md` — StatefulSet vs Deployment (apps = Deployments, databases = StatefulSets)
- `ibm-helm-migration.md` — Helm rollback mechanics
- `ibm-helm-migration.md` — CI/CD pipeline stages table (with SonarQube)
- `ibm-migration-answers.md` — Before state mermaid (Docker/Swarm chain)
- `ibm-migration-answers.md` — After state mermaid (Helm/K8s, same 4 layers)
- `tradeoff-questions.md` — IBM Motivations section (5 pains, decision table)

### System 3: VivSoft JCRS-E (CURRENT ROLE)

| Level | Andy asks | You answer | Study in |
|-------|-----------|-----------|----------|
| 1 | "What are you working on now?" | "Multi-tenant K8s platform for USCYBERCOM on GovCloud — air-gapped, 20+ services across 8 environments at 2 classification levels. I lead a squad of 6, own the roadmap end-to-end." | `vivsoft-platform.md` opening line |
| 2 | "How does air-gap work?" | "Zarf bundles everything — images, Helm charts, configs — into self-contained archives. The GitLab CI pipeline on the connected side builds the bundles and pushes them to S3. From S3 they transfer to the air-gapped side. UDS deploys in dependency order — core services before enterprise services. registries.yaml redirects all image pulls to the in-cluster registry. Build and deploy are completely decoupled." | `vivsoft-airgap-delivery.md` + `vivsoft-answers.md` Section 8 |
| 3 | "Why separate repos?" | "Classification boundary protection. If IaC and CaC share a repo and that repo touches SIPRNET, the whole repo becomes classified under DoD rules. Now a developer on the unclassified side who just wants to change a Terraform module needs a classification review to even access the code — because the repo is marked classified. I split them: kraken repo for Terraform stays unclassified. jcrs-cac repo for Kapitan configs gets classified when needed but only configs are affected. Developers can work on infrastructure freely without clearance reviews." | `vivsoft-platform.md` + `vivsoft-answers.md` Sections 2-3 |
| 4 | "What's Kapitan? How does class inheritance work?" | "Kapitan compiles one set of templates into different outputs per environment. A target file is 5 lines: name the environment, reference shared classes (like bb-vault.yml for Vault defaults), pin a release version. Classes define defaults — Vault port 8200, TLS enabled, Raft HA. Templates are Jinja2 — {{ vault_port }} gets filled in. Run kapitan compile, it outputs finished scripts and configs for that specific environment. Change a class default once, every target that inherits it updates. Versus Kustomize which patches a base — at 8+ environments across classification levels, inheritance is cleaner than stacking patches." | `vivsoft-answers.md` Section 6 |

**Study list to reach Level 4:**
- `vivsoft-platform.md` — coaching section (opening line, drawing order, emphasis points)
- `vivsoft-answers.md` — Section 2 (architecture approach, why decisions were made)
- `vivsoft-answers.md` — Section 3 (repository ecosystem — what each repo does)
- `vivsoft-answers.md` — Section 5 (6 cluster stack layers with details)
- `vivsoft-answers.md` — Section 6 (Kapitan: inventory structure, compile flow, class inheritance)
- `vivsoft-answers.md` — Section 7 (CI/CD pipeline: 7 stages, toggles, verification)
- `vivsoft-answers.md` — Section 8 (Zarf/UDS packaging: build vs deploy decoupling)
- `vivsoft-answers.md` — Section 11 (Crossplane: XRDs, Compositions, self-service claims)
- `tradeoff-questions.md` — VivSoft Motivations section (4 pains, 6 decisions with tradeoffs)
- `deep-dive-coaching-guide.md` — System 1 (VivSoft presentation guide)

---

## Helm Chart Structure Deep Dive

> Andy may ask "what does a Helm chart actually look like?" — know this structure.

A Helm chart is a directory with a specific layout:

```
my-service-chart/
├── Chart.yaml              # Metadata: chart name, version, description, dependencies
├── values.yaml             # Default configuration values (the knobs you turn)
├── templates/              # K8s manifest templates with {{ .Values.x }} placeholders
│   ├── deployment.yaml     # Deployment template
│   ├── service.yaml        # Service template
│   ├── configmap.yaml      # ConfigMap template
│   ├── secret.yaml         # Secret template (references, not actual secrets)
│   ├── pvc.yaml            # PersistentVolumeClaim template
│   ├── _helpers.tpl        # Reusable template snippets (labels, names, selectors)
│   └── NOTES.txt           # Post-install message shown to user
└── charts/                 # Sub-charts (dependencies — like a shared library chart)
```

**Chart.yaml — what it contains:**
```yaml
apiVersion: v2
name: jira
version: 1.2.0                    # chart version (what you package/release)
appVersion: "8.20.1"              # the app version inside (Jira 8.20.1)
description: "Jira deployment for TENA platform"
dependencies:
  - name: common-lib               # shared library chart
    version: "1.0.0"
    repository: "file://../common-lib"   # local path, not internet
```

**values.yaml — the configuration surface:**
```yaml
# These are the DEFAULTS — overridden per environment
replicaCount: 1
image:
  repository: registry.local/jira
  tag: "8.20.1"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80
  targetPort: 8080

resources:
  requests:
    cpu: 500m
    memory: 2Gi
  limits:
    cpu: 2
    memory: 4Gi

persistence:
  enabled: true
  size: 50Gi
  storageClass: gp3-encrypted

config:
  DB_HOST: postgres-jira
  JIRA_PORT: "8080"
  MEMORY_OPTS: "-Xmx4g"
```

**templates/deployment.yaml — how values become K8s resources:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}-jira          # release name from helm install
  labels:
    {{- include "common-lib.labels" . }}   # pulls labels from shared library
spec:
  replicas: {{ .Values.replicaCount }}     # from values.yaml: 1
  selector:
    matchLabels:
      app: {{ .Release.Name }}-jira
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}-jira
    spec:
      containers:
        - name: jira
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          env:
            - name: DB_HOST
              valueFrom:
                configMapKeyRef:
                  name: {{ .Release.Name }}-config
                  key: DB_HOST
```

**How the pieces connect:**
1. `values.yaml` defines the VARIABLES (replicas, image, ports, resources)
2. `templates/*.yaml` reference those variables with `{{ .Values.x }}`
3. `helm template` renders the templates → produces final K8s YAML
4. `helm install` applies that YAML to the cluster
5. `helm upgrade` applies changes, creates a new REVISION
6. `helm rollback` re-applies a previous revision's YAML

**The library chart (`common-lib`) — how it works:**
The library chart has ONLY templates (no deployable resources). Service charts declare it as a dependency in Chart.yaml. Inside their templates, they call `{{ include "common-lib.labels" . }}` to pull in the shared label template. Change the library once → every chart that depends on it gets the update on next deploy.

**Per-environment values files:**
```
helm upgrade jira ./jira-chart -f values-dev.yaml     # dev settings
helm upgrade jira ./jira-chart -f values-prod.yaml     # prod settings
```
Same chart, same templates, different values. values-prod.yaml might say `replicaCount: 2` and `resources.limits.memory: 8Gi` while dev says `replicaCount: 1` and `2Gi`.

---

## Key Reminders

1. **Andy is the priority.** He's the hiring manager. Impress him with architecture depth, tradeoff reasoning, and the K8s migration value proposition.
2. **Your differentiator: migration + air-gap K8s.** No other candidate has both IBM (Compose→Helm) AND Nightwatch (RKE2 air-gapped). Find ways to bring it up.
3. **Draw while you talk.** Whiteboard is not optional. Practice drawing every day this week.
4. **Know components 3-4 levels deep.** Andy will probe. Surface answers won't cut it.
5. **Bridge everything to Anduril.** Every story ends with "...and that's exactly what you need here."
6. **Taylor validates hands-on.** Process > perfection. Talk through your thinking.
7. **You already passed the HM screen and two other rounds.** They want you to succeed. Show up prepared, not panicked.
