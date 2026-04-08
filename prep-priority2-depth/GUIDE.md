# Priority 2: Linux / Networking / Podman / Containers Depth — Study Guide

> **For:** Andy's Monday deep-dive (12:45-1:30 — SECOND round, after Taylor)
> **Format:** Conversational probing — Linux, networking, Podman, containers, GitLab, builds. "Go deeper" on each topic. 3-4 levels.

## Everything you need is in THIS directory. Read in order.

### Day 1 — Linux Troubleshooting

| Time | File | What to do |
|------|------|-----------|
| 1.5 hrs | `01-linux-troubleshooting.md` | Read the full troubleshooting flow: service → logs → resources → network → firewall. Know systemctl, journalctl, top, df, free, ss, SELinux. |
| 30 min | `drill-01-troubleshoot-scenarios.md` | Do it — 3 scenarios, write your diagnostic steps. Check `drill-01-answers.md`. |

### Day 2 — Networking

| Time | File | What to do |
|------|------|-----------|
| 1.5 hrs | `02-networking-depth.md` | DNS (dig, nslookup), HTTP (curl -v), connections (ss -tlnp), routes (ip route), firewall (iptables, firewalld), TLS (openssl), K8s networking. |
| 30 min | `drill-02-firewall-exercises.md` | Write iptables + firewalld rules, diagnose RKE2 join failure. Check `drill-02-answers.md`. |

### Day 3 — Podman + Containers vs VMs

| Time | File | What to do |
|------|------|-----------|
| 1 hr | `03-podman-depth.md` | Full Podman: rootless, compose, build, push, registry config, SELinux :Z, systemd integration, GitLab runner. |
| 1 hr | `04-containers-vs-vms.md` | Hypervisors, VMs, containers, when to use each. VMware honesty. Container runtimes. Namespaces/cgroups. |
| 30 min | `drill-03-bash-debug.sh` | Find bugs in 2 bash scripts. Check `drill-03-answers.sh`. |

### Day 4 — Tradeoffs + Packet Tracing

| Time | File | What to do |
|------|------|-----------|
| 1 hr | `06-tradeoffs-and-motivations.md` | All motivation sections: IBM (5 pains), Nightwatch (3 pains), VivSoft (4 pains), Governance (3 pains). Andy will probe "why did you choose X." |
| 1 hr | `drill-04-packet-trace.md` | Trace packets: pod-to-pod, pod-to-external, plus "what breaks if" scenarios. |

### Day 5 (Sunday) — Light Review

| Time | File | What to do |
|------|------|-----------|
| 30 min | Redo weakest drill | Whichever you missed the most on. |
| 30 min | Skim `01` + `02` | Troubleshooting flow + networking commands. |
| | **REST** | Trust the prep. |

## What Andy Will Probe

Based on the recruiter + Andrew's interview:
- **Linux:** "Service is down — walk me through debugging." systemctl → journalctl → resources → network → firewall
- **Networking:** IP, subnet, gateway, DNS, firewall rules. "How does the interface know which subnet?" "When does it use the gateway?" Potentially deeper: packet tracing, TLS, mTLS
- **Podman/Containers:** Rootless, how it differs from Docker, registry config, SELinux, systemd. "Why Podman over Docker?"
- **VMware:** Be honest. "I haven't worked with VMware directly. I know hypervisors at the concept level — Type 1 runs on bare metal, Type 2 runs on an OS. My focus has been containers and K8s, which replaced the VM layer for most workloads."
- **GitLab/Builds:** Pipeline structure, runner config, how builds work, artifact flow
- **Your experience depth:** "You said you did X — go deeper. What specifically? What trade-offs? What would you change?"

## How to Answer Depth Probes

1. **Level 1:** State the concept. "Podman is a rootless container runtime."
2. **Level 2:** Explain the mechanics. "Rootless means no daemon running as root. Each podman command is a fork/exec — one process per container."
3. **Level 3:** Give specifics. "Rootless uses user namespaces — /etc/subuid maps your user to a range of UIDs inside the container. SELinux requires :Z on volume mounts for relabeling."
4. **Level 4:** Trade-offs and edge cases. "Rootless can't bind to ports below 1024 without CAP_NET_BIND_SERVICE. Networking uses slirp4netns which adds latency vs root mode. For GitLab runners, you set DOCKER_HOST to the Podman socket — same API, different backend."

If Andy goes deeper than you know: "That's the edge of my hands-on experience with that specific detail. In practice, I'd reference the docs and test it. But the concept is..."
