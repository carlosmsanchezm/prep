# Day 7: Final Review Checklist

## Morning: Review Cheatsheets (1 hour)

Read through each cheatsheet one more time. For each one, cover the screen and try to recall:

### Ansible
- [ ] Can I write a basic playbook structure from memory? (hosts, become, tasks, handlers)
- [ ] Do I know the 10 most common modules? (apt/yum, copy, template, file, service, systemd, firewalld, user, lineinfile, command)
- [ ] Can I write a handler + notify pattern?
- [ ] Do I know the role directory structure? (tasks/, handlers/, defaults/, templates/, files/)
- [ ] Can I use ansible-vault for secrets?

### Bash
- [ ] Do I know `set -euo pipefail` and why?
- [ ] Can I write an if/elif/else with file tests (-f, -d, -e, -z)?
- [ ] Can I write a while read loop to process a file line by line?
- [ ] Can I write a function with local variables and return codes?
- [ ] Do I know trap for cleanup?

### kubectl
- [ ] Can I write these 10 from memory: get, describe, logs, exec, apply, delete, rollout undo, top, get events, port-forward?
- [ ] Do I know the debugging flow: get pods → describe → logs → events?
- [ ] Can I use -o yaml, -o jsonpath, -l for label selectors?

### Kubernetes YAML
- [ ] Can I write a Deployment from memory? (apiVersion, selector, template, containers, resources, probes)
- [ ] Can I write a Service? (selector must match pod labels, port vs targetPort)
- [ ] Can I write a NetworkPolicy? (podSelector, ingress, egress, don't forget DNS port 53)
- [ ] Can I write RBAC? (ServiceAccount + Role + RoleBinding, apiGroups for core vs apps)

### Networking
- [ ] Can I trace a packet from pod to external service through every hop?
- [ ] Do I know: dig, curl -v, ss -tlnp, iptables -L -n -v, openssl s_client?
- [ ] Can I diagnose: DNS failure, TLS failure, service not reachable, pod network isolated?

### CI/CD
- [ ] Can I describe a GitLab CI pipeline structure? (stages, jobs, script, artifacts, rules)
- [ ] Do I know the standard pipeline pattern? (lint → build → scan → test → push → deploy → verify)
- [ ] Can I explain ArgoCD GitOps in 3 sentences?

---

## Afternoon: Re-Do Weak Spots (1 hour)

Go back to the exercises you struggled with most. Redo them without looking at answers.

My weakest areas this week were:
1. ________________
2. ________________
3. ________________

---

## Architecture Quick Check

Without looking at notes, draw these on paper (5 min each):
- [ ] VivSoft 6-layer platform (just the layer names and key components)
- [ ] Air-gap delivery flow (connected → bundle → transfer → deploy)
- [ ] RKE2 ports to open (6443, 9345, 10250, 2379-2380, 8472/UDP)

---

## Interview Logistics

- [ ] Know how to get to Anduril Reston office
- [ ] Bring: government-issued ID, phone (for recording practice notes)
- [ ] Wear: smart casual (Anduril is tech startup — not suit-and-tie)
- [ ] Arrive 15 minutes early
- [ ] Have 3-4 questions ready for each interviewer
- [ ] Have your "why defense tech" answer ready
- [ ] Have your "tell me about yourself" answer ready (2 minutes max)

---

## Mindset for Interview Day

- They already like you — you passed the hiring manager screen
- This is a CONVERSATION, not an exam
- When you don't know something: say "I haven't done that specifically, but here's how I'd approach it..."
- When using the whiteboard: draw big, label everything, narrate as you go
- For the hands-on: talk through your thinking out loud. They care about your process.
- It's okay to use Google/docs in the hands-on. They want to see HOW you work, not IF you memorized syntax.
- If you get stuck: say "Let me think about this for a second" — silence is better than rambling.
- Be yourself. You have real experience. Trust it.
