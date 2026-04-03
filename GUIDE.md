# Anduril Prep Boot Camp — How to Use This

## The Two Rounds

| Round | Interviewer | Format | Weight |
|-------|-------------|--------|--------|
| **1. Technical Deep Dive** | **Andy Carroll** (hiring manager) | Whiteboard. Walk through your systems, design discussions, tradeoffs, architecture. He'll probe deep. | **THIS IS THE ROUND THAT MATTERS MOST.** Andy is the hiring manager. Impress him. |
| **2. Technical Hands-On** | **Taylor Hine** | In-person. Live debugging, Ansible, Podman, Linux, networking. Practical problem-solving. | Important but secondary. Taylor validates you can do the work. |

---

## The Actual Stack (from 3 interview transcripts)

**What they use TODAY:** RHEL bare-metal, Podman (rootless), GitLab runners + pipelines, Ansible playbooks, Nexus registry, Rundeck, Compose files, air-gapped classified networks with data diodes, Packer (exploring).

**What they WANT but don't have yet:** Kubernetes. Felipe said it's a long-term goal. Andy asked you about RKE2 for aircraft networks. This is where YOUR value proposition lives.

**Your differentiator:** You've migrated a team from manual containers to K8s (IBM), AND you've run K8s air-gapped on RKE2 (NTConcepts). No other candidate brings both.

---

## Daily Structure (5-6 hours)

Architecture gets the majority of time because Andy's whiteboard is the priority.

| Block | Time | Focus | For Which Round |
|-------|------|-------|-----------------|
| **Morning: Architecture** | **3 hours** | Draw systems, narrate aloud, study components, practice tradeoffs, rehearse bridges to Anduril | **Andy (Round 1)** |
| **Afternoon: Hands-On** | **2 hours** | Ansible drills, Bash, Linux troubleshooting, networking, Podman, GitLab CI | **Taylor (Round 2)** |

---

## Morning Block: Architecture (3 hours)

This is the prep for Andy's whiteboard round. Every morning, you do 3 things:

### Hour 1: Draw + Narrate (the day's system)

1. Open that day's **exercise file** — read the coaching section
2. Close everything. Get paper or whiteboard.
3. **Draw the system from memory.** Boxes, arrows, labels.
4. **Narrate out loud as you draw** — as if Andy is sitting across from you.
5. Time yourself: 8-10 minutes.
6. Open the **answer key** — compare. What did you miss?
7. Redo the parts you missed.

### Hour 2: Component Deep-Dive Study

Each exercise file has a "Component Deep-Dive Prep" section listing specific things to study so you can go 3-4 levels deep when Andy probes. This hour is for studying those components.

Example for Nightwatch RKE2 day:
- Read about RKE2 air-gap install method
- Memorize registries.yaml structure
- Know Canal CNI (Calico + Flannel)
- Understand Cluster Autoscaler → GPU scheduling flow
- Know ArgoCD in air-gap (local Git, local registry, no webhooks)
- Know the auth chain: NLB → Istio → oauth2-proxy → Keycloak → RDS

Don't just read — **explain each component aloud in 2-3 sentences** as if Andy asked "tell me more about that."

### Hour 3: Tradeoffs + Anduril Bridges

Each exercise file has "Tradeoffs to Know" and "Bridging to Anduril" sections. This hour is for rehearsing those.

1. Read each tradeoff question. Answer aloud without looking.
2. Practice the Anduril bridge: "Your setup is like X, here's how I'd solve it based on Y."
3. Practice the **3 narrative strategies** for bringing up K8s naturally (documented in the plan and in `anduril-k8s-migration-pitch.md`):
   - Strategy 1: Use the question period to steer ("Based on my conversations with Felipe...")
   - Strategy 2: Bridge from any technical question (each has a hook + follow-up)
   - Strategy 3: Weave into "tell me about yourself"

---

## Architecture Daily Rotation

| Day | System | Exercise File | Why It Matters for Anduril |
|-----|--------|--------------|---------------------------|
| **1** | **IBM Helm Migration** (before → plan → after) | `ibm-helm-migration.md` | Shows you've migrated from manual containers to K8s — EXACTLY what they need |
| **2** | **Nightwatch RKE2** (cluster + GPU + auth + GitOps) | `nightwatch-rke2.md` | Shows you've built and run K8s air-gapped — their long-term goal |
| **3** | **Anduril K8s Migration Pitch** (IBM + Nightwatch → proposal) | `anduril-k8s-migration-pitch.md` | The combined pitch — practice delivering the whole thing as one coherent story |
| **4** | VivSoft JCRS-E (6 layers) | `vivsoft-platform.md` | Shows depth and principal-level ownership |
| **5** | Air-gap delivery + Bird-Dog network | `vivsoft-airgap-delivery.md` + `ntconcepts-bird-dog.md` | Air-gap expertise + networking depth |
| **6** | **MOCK: Full whiteboard simulation** | `drills/day6-mock/deep-dive-prompts.md` | Record yourself answering 10 questions aloud. Grade it. |
| **7** | Review weakest systems + tradeoff questions | `tradeoff-questions.md` | Light review, rest |

**Days 1-3 are the most critical.** The IBM migration, Nightwatch RKE2, and the combined Anduril pitch are your value differentiators. By Day 3, you should be able to deliver the full pitch cold.

### Answer Keys
- `vivsoft-answers.md` — 13-section VivSoft reference with mermaid diagrams
- `ntconcepts-answers.md` — Bird-Dog network + Kubeflow + Nightwatch RKE2 with real details
- `ibm-migration-answers.md` — Before/after mermaid charts for IBM migration

### Coaching Files
- `deep-dive-coaching-guide.md` — General presentation techniques (zoom-out, 5-3-1 rule)
- `ibm-helm-migration.md` — Coaching for IBM story (opening line, drawing order, component prep, tradeoffs)
- `nightwatch-rke2.md` — Coaching for Nightwatch story (same structure)
- `anduril-k8s-migration-pitch.md` — The combined pitch + pushback responses + component study list

### Scenario Practice
- `anduril-scenarios.md` — 5 real Anduril problems to design solutions for

---

## Afternoon Block: Hands-On Drills (2 hours)

This is prep for Taylor's round. Rotate through these every day:

| Area | Time | What to Do |
|------|------|------------|
| **Ansible** | 30 min | Do that day's Ansible exercise from `drills/dayN/`. Write from memory, check answers. |
| **Bash + Podman** | 30 min | Do that day's Bash exercise. Also review `cheatsheets/podman.md` — know rootless, compose, registry, SELinux `:Z`. |
| **Linux + Networking** | 30 min | Do that day's networking exercise. Also review `cheatsheets/linux-troubleshooting.md` — know the exact troubleshooting flow Andrew tested (systemctl → journalctl → top → ss → firewall). |
| **GitLab CI** | 30 min | Do that day's pipeline exercise. Know stages, runners, tags, Podman executor. Review `cheatsheets/packer.md` for golden image builds. |

### Drill Files by Day
| Day | Ansible | Bash | K8s/Network | Pipeline/Other |
|-----|---------|------|-------------|----------------|
| 1 | `day1/ansible-read-and-fix.yml` | `day1/bash-fill-in-blanks.sh` | `day1/k8s-debug-manifests.yml` + `day1/kubectl-commands.md` | `day1/networking-diagnosis.md` |
| 2 | `day2/ansible-write-tasks.yml` | `day2/bash-read-and-explain.sh` | `day2/k8s-write-snippets.yml` | `day2/pipeline-read-and-fix.yml` + `day2/networking-trace.md` |
| 3 | `day3/ansible-role-structure.md` | `day3/bash-debug-scripts.sh` | `day3/k8s-networkpolicy.yml` + `day3/kubectl-troubleshoot.md` | `day3/networking-firewall.md` |
| 4 | `day4/ansible-rke2-bootstrap.yml` | `day4/bash-bundle-validator.sh` | `day4/k8s-rbac.yml` | `day4/pipeline-design.md` + `day4/networking-dns-tls.md` |
| 5 | `day5/ansible-registry-populate.yml` | `day5/bash-mixed-review.sh` | `day5/k8s-mixed-review.yml` + `day5/kubectl-speed-round.md` | `day5/networking-full-trace.md` |
| 6 | Mock hands-on challenge | | | `day6-mock/hands-on-challenge.md` |
| 7 | Review weak spots | | | `day7-review/final-review.md` |

### Cheatsheets (read these on Day 1, reference throughout)
- `cheatsheets/ansible.md` — playbook structure, 15 core modules, role directory
- `cheatsheets/bash.md` — loops, conditionals, file ops, traps, functions
- `cheatsheets/kubectl.md` — 25 essential commands
- `cheatsheets/networking.md` — dig, curl, ss, iptables, tcpdump, packet trace
- `cheatsheets/k8s-resources.md` — Deployment, Service, NetworkPolicy, RBAC templates
- `cheatsheets/cicd.md` — GitLab CI stages, ArgoCD, pipeline patterns
- `cheatsheets/podman.md` — rootless, compose, registry, GitLab runner integration, SELinux
- `cheatsheets/linux-troubleshooting.md` — systemctl, journalctl, top, df, SELinux debugging
- `cheatsheets/packer.md` — RHEL builds with Ansible, Podman integration

---

## How to Bring Up K8s Naturally (3 Strategies)

Andy leads the interview — you can't predict his questions. But you CAN steer the conversation toward your strongest stories. Three strategies:

### Strategy 1: Use the question period
When Andy says "any questions?" or there's a pause:
> "Based on my conversations with Felipe and Andrew, Kubernetes is a long-term goal but hasn't happened due to bandwidth. I've actually done that migration before — at IBM, the dev suite was running on Docker Compose, Swarm, Makefiles, Python scripts. I containerized everything into Helm charts, nine services. And separately at NTConcepts I built an RKE2 cluster air-gapped for classified ML workloads. What's blocked you so far?"

### Strategy 2: Bridge from any question
Every technical question has a natural hook to the K8s story. See `anduril-k8s-migration-pitch.md` for the full list with prepared follow-up answers for when Andy digs deeper.

### Strategy 3: Weave into career walkthrough
When asked "tell me about yourself" or "walk me through your experience," hit the IBM migration and Nightwatch as highlights. See `anduril-k8s-migration-pitch.md` Strategy 3 for the exact script.

---

## Day 6: Full Mock

### Morning (2.5 hours): Whiteboard Mock
1. Open `drills/day6-mock/deep-dive-prompts.md` — 10 questions
2. Answer each ALOUD. Record yourself. Time to 3-5 minutes each.
3. For at least 2 answers, use the whiteboard — draw as you talk.
4. Listen back. Grade: Did I hit the opening line? Did I explain tradeoffs? Did I bridge to Anduril?
5. Deliver the full Anduril K8s pitch from `anduril-k8s-migration-pitch.md` — cold, no notes.

### Afternoon (1 hour): Hands-On Mock
1. Open `drills/day6-mock/hands-on-challenge.md`
2. 45-minute timer. Ansible + K8s debug + network diagnosis.
3. No AI. Google okay. Talk aloud.
4. Check against answers.

### Evening
- Read `drills/day6-mock/questions-for-interviewers.md`. Pick 3-4 for Andy, 2-3 for Taylor.

---

## Day 7: Light Review + Rest

- Open `drills/day7-review/final-review.md`
- Re-draw IBM migration and Nightwatch RKE2 one more time
- Practice the Anduril K8s pitch one more time — cold
- Review 3 tradeoff questions
- Review interviewer questions
- REST. Trust the week.

---

## Key Reminders

- **Andy is the priority.** The whiteboard deep dive is where you win or lose. Architecture prep gets 3 hours/day.
- **Your differentiator is the K8s migration story + air-gap RKE2.** No other candidate has both. Find ways to bring it up.
- **Draw while you talk.** Whiteboard is not optional — practice drawing every day.
- **Know components 3-4 levels deep.** Andy will probe. "I used RKE2" is level 1. "registries.yaml redirects containerd to local Nexus, Canal CNI uses Flannel VXLAN for overlay, agent joins on port 9345" is level 3.
- **Bridge everything to Anduril.** Every story should end with "...and that's exactly what you need here."
- **Taylor validates hands-on.** Ansible, Podman, Linux, networking. Study the cheatsheets, do the drills, but don't sacrifice architecture time for it.
- **You already passed the HM screen.** Andy liked you enough to bring you onsite. Now show him you can deliver.
