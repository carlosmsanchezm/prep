# Priority 1: Ansible + GitLab Debugging — Study Guide

> **For:** Andy's Monday hands-on (12:45-1:30 — SECOND round, after Taylor's system design)
> **Scenario:** Given a buggy Ansible-based GitLab CI/CD project that deploys to a target host. **AIR-GAPPED environment** — no internet. Local GitLab, local Nexus, local DNS. Find and fix: GitLab config issues, Ansible config/code issues, pipeline problems, AND air-gap specific failures.
> 
> **The #1 bug category in air-gap: things that assume internet access.** Every public registry pull, every pip install, every Galaxy download, every external URL — all broken. Train your eyes to spot these FIRST.

## Everything you need is in THIS directory. Read in order.

### Day 1 — Ansible Foundations + Bug Spotting

| Time | File | What to do |
|------|------|-----------|
| 1.5 hrs | `01-ansible-fundamentals.md` | Read. Focus on: playbook structure, 15 core modules, handlers, role directory, vault. This is the baseline. |
| 1 hr | `02-ansible-common-bugs.md` | Read every bug pattern. These are what Taylor will plant in the exercise. |
| 30 min | `drill-01-fix-ansible-playbook.yml` | Do it. Find all 8 bugs. Check `drill-01-answers.yml`. |

### Day 2 — GitLab CI/CD + Debugging

| Time | File | What to do |
|------|------|-----------|
| 1 hr | `03-gitlab-ci-fundamentals.md` | Read. Focus on: .gitlab-ci.yml structure, stages, variables, runners, artifacts. |
| 1.5 hrs | `04-gitlab-debugging.md` | **START with Section 0: Air-Gap Specific Failures.** Then: runner problems, pipeline failures, config errors, Podman executor issues. |
| 30 min | `drill-02-fix-gitlab-pipeline.yml` | Do it. Find all 6 bugs. Check `drill-02-answers.yml`. |

### Day 3 — Runner + Remote Hosts

| Time | File | What to do |
|------|------|-----------|
| 45 min | `05-podman-for-runners.md` | Read. How Podman executor works, DOCKER_HOST, rootless, SELinux. |
| 45 min | `06-ansible-to-ec2.md` | Read. SSH, inventory, become, key auth, common connection errors. |
| 30 min | `drill-03-ansible-role-structure.md` | Do it. Design a full role. Check `drill-03-answers.md`. |

### Day 4 — Full Scenario (Taylor's Exercise)

| Time | File | What to do |
|------|------|-----------|
| 1.5 hrs | `drill-04-full-scenario.md` | **This simulates Taylor's exact scenario.** Buggy Ansible + GitLab deploying to a target host IN AN AIR-GAPPED ENVIRONMENT. 19 bugs: 15 config/syntax + 4 air-gap. Find ALL. No AI, no Google. Talk through your process aloud. |
| 30 min | `drill-04-answers.md` | Check your work. Note what you missed. |
| 30 min | Review | Re-read `02-ansible-common-bugs.md` + `04-gitlab-debugging.md` for anything you missed. |

### Day 5 (Sunday) — Light Review

| Time | File | What to do |
|------|------|-----------|
| 30 min | Redo weakest drill | Whichever drill you missed the most bugs on. |
| 30 min | Skim `02` + `04` | Bug patterns + debugging patterns — quick scan. |
| | **REST** | Trust the prep. |

## What Andy Will Test

Based on the recruiter's description:
1. **Read broken configs** — .gitlab-ci.yml, ansible.cfg, playbook.yml, inventory
2. **Identify what's wrong** — syntax errors, logical errors, config mismatches
3. **Explain your debugging process** — "I'd check X first because..."
4. **Suggest fixes** — not just "it's broken" but "here's the fix and why"

## How to Approach the Exercise

1. **Read everything first** — don't start fixing immediately. Scan all files.
2. **CHECK AIR-GAP FIRST** — scan every line for internet assumptions: public images, pip install, galaxy downloads, external URLs, public DNS. These are the bugs that show you understand the environment.
3. **Then check the pipeline** — is .gitlab-ci.yml syntactically valid? Are stages ordered correctly? Is the runner configured right? Tags match?
4. **Then check Ansible** — is the playbook syntactically valid? Are module params correct? Is become set? Do handlers match notify? Mode quoted?
5. **Then check connectivity** — can the runner reach the target host? SSH keys? Inventory correct? Port open?
6. **Talk through your thinking** — Taylor evaluates your PROCESS, not just the answer. Say: "First thing I notice is this image pulls from Docker Hub — that won't work air-gapped. Fix: point to the local registry."
