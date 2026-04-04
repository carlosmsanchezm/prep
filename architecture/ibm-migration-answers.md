# IBM Helm Migration — Answer Keys (Mermaid Charts)

## 1. BEFORE State: Legacy Deployment System

> **This is the ACTUAL before state.** No Kubernetes, no kubectl. Docker Compose for local dev, Docker Swarm for deployment, Makefiles and scripts for orchestration. The diagram shows the relationships between components — this is what tells the story on a whiteboard.

```mermaid
---
config:
  layout: elk
---
flowchart TD
    subgraph Dev_Config_Layer["Development & Configuration Layer"]
        GIT["Git Repo<br/>tws-stack-deployment"]:::git
        VALUES["config/local/values.yaml<br/>per-service config values"]:::values
        CONFIGS["Individual config files<br/>per service"]:::configFiles
        TEMPLATES["Template config files<br/>.tmpl files"]:::templates
        GOMPLATE["Gomplate Translation<br/>custom templating engine"]:::gomplate
        MAKEFILE["Makefile<br/>main build control"]:::makefile
        MK_FILES[".mk files<br/>build logic per service"]:::makefile
        SCRIPTS_DIR["Scripts directory<br/>helper scripts"]:::scripts
    end

    subgraph Build_Deploy_Layer["Build & Deployment Layer"]
        MAKE_CMD["make command<br/>entry point for everything"]:::make
        SUB_MAKES["Subdirectory Makefiles<br/>per-service build targets"]:::makefile
        SHELL["Custom shell scripts<br/>deployment glue"]:::scripts
        PYTHON["Python scripts<br/>config generation, validation"]:::scripts
        DOCKER_CMD["docker-compose / docker stack<br/>manual execution"]:::docker
    end

    subgraph Container_Runtime["Container Runtime (Docker Swarm)"]
        COMPOSE["Docker Compose files<br/>service definitions"]:::docker
        SWARM["Docker Swarm<br/>orchestration (basic)"]:::docker
        VOLUMES["Docker Volumes<br/>persistent data"]:::docker
    end

    subgraph Services["Dev Tool Suite (9 Services · 600+ Users)"]
        JIRA["Jira"]:::service
        BB["Bitbucket"]:::service
        CONF["Confluence"]:::service
        JENK["Jenkins"]:::service
        ART["Artifactory"]:::service
        CROWD["Crowd (SSO)"]:::service
        ACCT["Accounts-API"]:::service
        MAIL["Mailman"]:::service
        HTTPD["HTTPD-UI"]:::service
    end

    %% Config layer relationships
    GIT -- "centralized repo" --> TEMPLATES
    VALUES -- "config values" --> GOMPLATE
    CONFIGS -- "individual configs" --> GOMPLATE
    TEMPLATES -- "template processing" --> GOMPLATE
    GOMPLATE -- "substituted files" --> MAKE_CMD

    %% Build control relationships
    MAKEFILE -- "main build control" --> MAKE_CMD
    MK_FILES -- "build logic" --> MAKE_CMD
    SCRIPTS_DIR -- "helper scripts" --> MAKE_CMD

    %% Build layer relationships
    MAKE_CMD -- "trigger builds" --> SUB_MAKES
    MAKE_CMD -- "trigger scripts" --> SHELL
    MAKE_CMD -- "trigger scripts" --> PYTHON
    SUB_MAKES -- "invoke shell" --> SHELL
    SUB_MAKES -- "invoke python" --> PYTHON
    SHELL -- "docker commands" --> DOCKER_CMD
    PYTHON -- "docker commands" --> DOCKER_CMD

    %% Deployment
    DOCKER_CMD -- "compose up / stack deploy" --> COMPOSE
    COMPOSE -- "orchestrated by" --> SWARM
    SWARM -- "runs" --> Services
    VOLUMES -- "mounted by" --> Services

    %% Monitoring feedback (the painful loop)
    Services -. "docker logs / docker ps<br/>manual monitoring" .-> MAKE_CMD

    classDef git fill:#ffcc00,stroke:#333,stroke-width:2px
    classDef values fill:#ffccff,stroke:#333,stroke-width:2px
    classDef configFiles fill:#ccffff,stroke:#333,stroke-width:2px
    classDef makefile fill:#ffcccc,stroke:#333,stroke-width:2px
    classDef scripts fill:#ccffcc,stroke:#333,stroke-width:2px
    classDef make fill:#ffcc99,stroke:#333,stroke-width:2px
    classDef docker fill:#ccccff,stroke:#333,stroke-width:2px
    classDef service fill:#ccff99,stroke:#333,stroke-width:2px
    classDef templates fill:#ccffcc,stroke:#333,stroke-width:2px
    classDef gomplate fill:#ffcccc,stroke:#333,stroke-width:2px
```

### What This Diagram Shows (the story it tells)

**Layer 1 — Development & Configuration:** Everything starts in one Git repo. Config values and templates feed into Gomplate — a custom templating engine that nobody outside this team uses. Gomplate generates substituted config files that feed into the make command. Makefiles and .mk files define build logic per service. Helper scripts are scattered in a scripts directory.

**Layer 2 — Build & Deployment:** The `make` command is the single entry point for everything. It triggers subdirectory Makefiles (one per service), which invoke custom shell scripts and Python scripts. These scripts eventually call `docker-compose up` or `docker stack deploy` to push containers to Swarm. Every step is imperative — "do this, then this, then this."

**Layer 3 — Container Runtime:** Docker Compose defines the services. Docker Swarm provides basic orchestration (restart on failure, but no rolling updates, no health checks, no resource limits). Volumes are Docker volumes — not managed, not backed up automatically.

**Layer 4 — The 9 Services:** Jira, Bitbucket, Confluence, Jenkins, Artifactory, Crowd, Accounts-API, Mailman, HTTPD-UI. Six hundred engineers depend on these daily.

**The feedback loop (dotted line):** When something breaks, you `docker logs` and `docker ps` manually, trace back through the scripts, fix, re-run make. No alerting, no drift detection.

### Pain Points to Call Out on the Whiteboard

Write these next to or below the diagram:

1. **No rollback** — Compose/Swarm has no revision history. If a deploy breaks, you manually revert files and re-run.
2. **No drift detection** — what's running might not match what's in Git. Someone could `docker exec` in and change a config.
3. **Gomplate is custom** — custom templating syntax, no community support, hard to hire for, hard to debug.
4. **Five layers of indirection** — Git → Gomplate → Make → Scripts → Docker. A config change touches every layer.
5. **Manual release checklist** — each release requires running make targets in order, checking docker ps, verifying each service. Takes hours.
6. **600+ users at risk** — one bad deploy takes down the entire dev tool suite.

### How to Draw This on a Whiteboard

**Step 1:** Draw two big boxes side by side at the top — "Config Layer" (left) and "Build Layer" (right).

**Step 2:** Inside Config Layer, write: Git Repo, values.yaml, config files, templates, Gomplate. Draw arrows showing how values and templates both feed into Gomplate, and Gomplate feeds into the make command.

**Step 3:** Inside Build Layer, write: make command (big, central), then Makefiles, Shell scripts, Python scripts branching off it. Show make triggers all of them.

**Step 4:** Draw a box below labeled "Docker Compose / Swarm" with arrows from the scripts down to it.

**Step 5:** Draw a box at the bottom labeled "9 Services (600+ users)" and list them.

**Step 6:** Draw a dotted line from the services back up to the make command labeled "manual monitoring (docker logs)" — this shows the painful feedback loop.

**Step 7:** Write pain points in red on the side.

### Narration Script
"This is what I inherited at IBM Federal. A single Git repo with per-service config files and templates. Everything feeds through Gomplate — a custom templating engine — which generates config files that feed into make. The make command is the single entry point: it triggers per-service Makefiles, which invoke Python and shell scripts, which eventually run docker-compose up or docker stack deploy. Five layers of indirection before a container starts. Nine services — Jira, Bitbucket, Confluence, Jenkins, Artifactory, and four others — serving six hundred engineers. No rollback capability. No drift detection. If a deploy failed, you'd SSH in, check docker logs, trace through the scripts, and fix by hand. Every release was a multi-hour manual checklist."

---

## 2. The Bridge: How Docker Compose/Swarm Services Moved to Kubernetes

> **Andy WILL ask this:** "Before you used Helm, how did you actually get the services running on Kubernetes?" This section explains the bridge — the containers already existed, you just changed the orchestration layer.

### The Key Insight to Communicate

"The services were already containerized — Docker images existed for all nine services. The migration wasn't about building containers from scratch. It was about replacing the orchestration layer: going from Docker Compose files and Swarm to Kubernetes manifests managed by Helm."

### What I Actually Did (step by step)

1. **Analyzed the existing Compose files** — each service had a docker-compose.yml defining: image, ports, volumes, environment variables, dependencies, restart policies
2. **Translated Compose definitions to K8s manifests** — for each service:
   - `image:` in Compose → same image reference in K8s Deployment
   - `ports:` → K8s Service (ClusterIP or NodePort)
   - `volumes:` → PersistentVolumeClaim + PersistentVolume
   - `environment:` → ConfigMap or Secret
   - `depends_on:` → not needed in K8s (services discover via DNS)
   - `restart: always` → K8s handles this natively (restartPolicy: Always is default)
3. **Templatized the manifests into Helm charts** — turned hardcoded values into `{{ .Values.x }}` references, created values.yaml per environment
4. **Tested with `helm template`** (dry-run render) → verified output YAML matched what the Compose files produced
5. **Deployed to dev cluster with `helm install`** → validated services came up, connected to each other, and served traffic
6. **Built a CI/CD pipeline** around it — build image → lint chart → package → deploy → test → promote

### How to Explain It to Andy

"The containers already existed — Docker images for Jira, Bitbucket, Jenkins, all of them. The Compose files defined how they ran: ports, volumes, env vars, dependencies. What I did was translate each Compose definition into Kubernetes manifests — a Deployment for the workload, a Service for networking, PersistentVolumeClaims for storage, ConfigMaps for config. Then I templatized those into Helm charts so every environment uses the same template with different values. The hardest part wasn't Kubernetes itself — it was getting the persistent volumes right for stateful services like Jira's database, and making sure the service discovery worked without Compose's depends_on."

### If Andy Probes: "What was hardest about the migration?"

"Stateful services. Jira and Bitbucket have databases that need persistent storage. In Compose, that's just a named volume. In K8s, that's a PersistentVolumeClaim bound to a PersistentVolume, with the right storage class and reclaim policy so data isn't deleted on pod restart. I had to design the storage layer carefully — wrong reclaim policy and you lose the database on upgrade. The other challenge was config management: Compose uses .env files, K8s uses ConfigMaps and Secrets. I built a migration script that converted each service's .env into a ConfigMap YAML, then moved sensitive values to Secrets."

---

## 3. AFTER State: Helm-Based Deployment

> This diagram shows the relationships — how developers interact with Helm charts, how CI/CD flows through the pipeline, how environments connect. This is what the AFTER state looks like and what you draw on the whiteboard as the contrast to the BEFORE.

```mermaid
---
config:
  layout: elk
---
flowchart TB
    subgraph Developer_Local_Environment["Developer Local Environment"]
        A1["Local Git repository"]:::git
        A2["Docker Desktop / Minikube"]:::k8s
        A3["Helm"]:::helm
        A4["kubectl"]:::k8s
    end

    subgraph Version_Control["Version Control"]
        B1["Remote Git repository"]:::git
    end

    subgraph CI_CD_Pipeline["CI/CD Pipeline"]
        C1["Build Docker images"]:::docker
        C2["Push to container registry"]:::docker
        C3["Helm lint"]:::helm
        C4["Helm package"]:::helm
    end

    subgraph Dev_Test_Environments["Dev/Test Environments"]
        D1["Dev Kubernetes Cluster"]:::k8s
        D2["Test Kubernetes Cluster"]:::k8s
    end

    subgraph Helm_Charts["Helm Charts"]
        E1["Application charts<br/>(one per service)"]:::helm
        E2["Shared library charts<br/>(common patterns)"]:::helm
        E3["values.yaml files<br/>(per environment)"]:::values
    end

    %% Developer workflow (numbered steps)
    A1 -- "1 Clone/Pull" --> B1
    A1 -- "2 Modify code/charts" --> Helm_Charts
    A3 -- "3 helm lint" --> Helm_Charts
    A3 -- "4 helm template" --> Helm_Charts
    A3 -- "5 helm install/upgrade" --> A2
    A4 -- "6 kubectl for debugging" --> A2
    A1 -- "7 Commit changes" --> A1
    A1 -- "8 Push changes" --> B1

    %% CI/CD workflow (numbered steps)
    B1 -- "1 Trigger CI" --> C1
    C1 -- "2 Build images" --> C2
    C2 -- "3 Push images" --> C2
    C3 -- "4 Lint charts" --> Helm_Charts
    C4 -- "5 Package charts" --> Helm_Charts
    C4 -- "6 Deploy to Dev" --> D1
    D1 -- "7 Run tests" --> D1
    D1 -- "8 Promote to Test" --> D2

    %% High-level relationships
    Developer_Local_Environment -- "Develop and test" --> Helm_Charts
    Helm_Charts -- "Used by" --> CI_CD_Pipeline
    Helm_Charts -- "Deploy to" --> Dev_Test_Environments
    B1 -- "Triggers" --> CI_CD_Pipeline
    CI_CD_Pipeline -- "Deploys to" --> Dev_Test_Environments

    classDef git fill:#f96,stroke:#333,stroke-width:2px
    classDef k8s fill:#9cf,stroke:#333,stroke-width:2px
    classDef helm fill:#fcf,stroke:#333,stroke-width:2px
    classDef docker fill:#cfc,stroke:#333,stroke-width:2px
    classDef values fill:#ff9,stroke:#333,stroke-width:2px
```

### What This Diagram Shows (the story)

**Developer Local Environment:** Developer clones the repo, modifies Helm charts locally, runs `helm lint` and `helm template` to validate, then `helm install` to test on Minikube/Docker Desktop. Uses kubectl for debugging. Commits and pushes.

**Version Control → CI/CD:** Push triggers the pipeline. Pipeline builds Docker images, pushes to registry, lints Helm charts, packages them, deploys to Dev cluster, runs tests, promotes to Test.

**Helm Charts (center):** The key differentiator. Application charts (one per service), shared library charts (common patterns like health checks, resource limits), and values.yaml per environment. Everything is templated, versioned, rollbackable.

**Dev/Test Environments:** Separate K8s clusters. Dev gets auto-deployed on every push. Test gets promoted after dev tests pass.

### Key Improvements vs. BEFORE State

| Before (Compose/Swarm) | After (Helm/K8s) |
|------------------------|-------------------|
| Docker Compose + Swarm | Kubernetes + Helm |
| Gomplate (custom templating) | Helm templates (industry standard) |
| Makefiles + Python + Shell scripts | CI/CD pipeline |
| Manual release checklist | Automated: build → lint → test → deploy |
| No rollback | `helm rollback` to any previous revision |
| No drift detection | Helm tracks release state |
| 5 layers of indirection | Push → CI → deploy (3 steps) |
| Hours per release | Minutes per release (40% reduction) |

### How to Draw the AFTER on a Whiteboard

**Step 1 (top left):** Box: "Developer" with Git, Helm, kubectl inside. Arrows to "Helm Charts" and "Git Repo."

**Step 2 (center):** Box: "Helm Charts" — application charts, shared library charts, values.yaml. This is the heart. Draw it prominent.

**Step 3 (top right):** Box: "Git Repo (Remote)." Arrow from developer to Git, arrow from Git triggering CI.

**Step 4 (right):** Box: "CI/CD Pipeline" — build images, push to registry, lint, package, deploy. Show the numbered flow.

**Step 5 (bottom):** Two boxes: "Dev Cluster" → "Test Cluster." CI deploys to Dev, test passes, promote to Test.

**Step 6:** Draw arrows showing how Helm Charts connect to EVERYTHING — developers use them, CI packages them, clusters run them.

Say: "Helm Charts are the center of everything now. One chart per service, shared library for common patterns, values.yaml per environment. Developer pushes, pipeline builds and deploys automatically. Rollback is one command. Release prep went from hours to minutes — forty percent reduction."

---

## 4. OpenShift Migration (Designed + Implemented)

> This was the NEXT evolution — from vanilla K8s/Helm to OpenShift. Shows architectural progression.

```mermaid
---
config:
  layout: elk
---
flowchart TB
    subgraph Developer_Local_Environment["Developer Local Environment"]
        A1["Local Git repository"]:::git
        A2["CodeReady Containers<br/>(local OpenShift)"]:::openshift
        A3["Helm"]:::helm
        A4["oc CLI"]:::openshift
    end

    subgraph Version_Control["Version Control"]
        B1["Remote Git repository"]:::git
    end

    subgraph OpenShift_CI_CD["OpenShift CI/CD"]
        C1["BuildConfig<br/>(native image builds)"]:::openshift
        C2["ImageStream<br/>(built-in image management)"]:::openshift
        C3["Helm lint"]:::helm
        C4["Helm package"]:::helm
    end

    subgraph OpenShift_Cluster["OpenShift Cluster"]
        D1["Dev Project<br/>(namespace + RBAC)"]:::openshift
        D2["Test Project<br/>(namespace + RBAC)"]:::openshift
    end

    subgraph Helm_Charts["Helm Charts"]
        E1["Application charts"]:::helm
        E2["Shared library charts"]:::helm
        E3["values.yaml files"]:::values
    end

    %% Developer workflow
    A1 -- "1 Clone/Pull" --> B1
    A1 -- "2 Modify code/charts" --> Helm_Charts
    A3 -- "3 helm lint" --> Helm_Charts
    A3 -- "4 helm template" --> Helm_Charts
    A3 -- "5 helm install/upgrade" --> A2
    A4 -- "6 oc for debugging" --> A2
    A1 -- "7 Commit" --> A1
    A1 -- "8 Push" --> B1

    %% CI/CD workflow
    B1 -- "1 Trigger CI" --> C1
    C1 -- "2 Build images" --> C2
    C2 -- "3 Push to ImageStream" --> C2
    C3 -- "4 Lint charts" --> Helm_Charts
    C4 -- "5 Package charts" --> Helm_Charts
    C4 -- "6 Deploy to Dev" --> D1
    D1 -- "7 Run tests" --> D1
    D1 -- "8 Promote to Test" --> D2

    %% Relationships
    Developer_Local_Environment -- "Develop and test" --> Helm_Charts
    Helm_Charts -- "Used by" --> OpenShift_CI_CD
    B1 -- "Triggers" --> OpenShift_CI_CD
    OpenShift_CI_CD -- "Deploys to" --> OpenShift_Cluster

    classDef git fill:#f96,stroke:#333,stroke-width:2px
    classDef openshift fill:#3d85c6,stroke:#333,stroke-width:2px,color:#fff
    classDef helm fill:#fcf,stroke:#333,stroke-width:2px
    classDef values fill:#ff9,stroke:#333,stroke-width:2px
```

### What Changed from K8s/Helm to OpenShift

| K8s + Helm | OpenShift |
|------------|-----------|
| Separate CI for image builds | OpenShift BuildConfig builds natively |
| Manual image registry | ImageStream manages images + promotion |
| Namespaces + manual RBAC | Projects (namespace + RBAC built-in) |
| kubectl | oc CLI (wraps kubectl + OpenShift features) |
| Ingress for routing | Routes (simpler, built-in TLS) |
| Docker Desktop for local | CodeReady Containers (local OpenShift) |

### How to Explain to Andy

"After the Helm migration was stable, I designed and started implementing the next step — moving from vanilla Kubernetes to OpenShift. The Helm charts carried over — same charts, just deployed to OpenShift instead of vanilla K8s. The big wins were: BuildConfig gave us native image builds inside the platform — no separate CI needed for image creation. ImageStreams gave us built-in image promotion — no more manually pushing tags between registries. And Projects gave us namespace-level RBAC out of the box, which mattered for our multi-team setup with six hundred users."

### If Andy Asks: "Did you finish the OpenShift migration?"

"I designed the architecture, built the initial infrastructure — CodeReady Containers for local dev, the first two services migrated as proof of concept — and created the full roadmap for the remaining services. I left before completing the full migration but handed off the plan and the working prototype to the team. The Helm charts didn't change — that was the whole point of using Helm. The charts are platform-agnostic. What changed was the CI/CD layer and how images were managed."
