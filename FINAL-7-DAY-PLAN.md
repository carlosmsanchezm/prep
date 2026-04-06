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

## Key Reminders

1. **Andy is the priority.** He's the hiring manager. Impress him with architecture depth, tradeoff reasoning, and the K8s migration value proposition.
2. **Your differentiator: migration + air-gap K8s.** No other candidate has both IBM (Compose→Helm) AND Nightwatch (RKE2 air-gapped). Find ways to bring it up.
3. **Draw while you talk.** Whiteboard is not optional. Practice drawing every day this week.
4. **Know components 3-4 levels deep.** Andy will probe. Surface answers won't cut it.
5. **Bridge everything to Anduril.** Every story ends with "...and that's exactly what you need here."
6. **Taylor validates hands-on.** Process > perfection. Talk through your thinking.
7. **You already passed the HM screen and two other rounds.** They want you to succeed. Show up prepared, not panicked.
