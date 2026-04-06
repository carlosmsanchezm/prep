# Anduril K8s Migration Pitch — Combining IBM + Nightwatch

> **Purpose:** A prepared pitch that connects your IBM migration experience and Nightwatch RKE2 experience into a concrete proposal for Anduril's K8s rollout. Practice delivering this as a cohesive narrative.

---

## The Pitch (practice this aloud — 3-5 minutes)

### Part 1: "Here's where you are today" (30 seconds)

"From what I've learned talking with Felipe and Andrew, you're running Podman Compose on RHEL, Ansible playbooks for config, GitLab for CI/CD, Nexus for your registry, and everything's air-gapped with a diode for transfers. No Kubernetes yet — you want it but haven't had the bandwidth."

### Part 2: "I've been in this exact situation before" (90 seconds)

"At IBM Federal, I walked into a nearly identical setup — Docker Compose, Swarm, Makefiles, Python scripts, Gomplate templating. Nine services serving six hundred users: Jira, Bitbucket, Confluence, Jenkins, Artifactory, and four others. No orchestration, no rollback, every release was a manual checklist.

I led the migration to Kubernetes with Helm. Four phases: first, two weeks defining standards and the shared library chart template. Then eighteen weeks migrating one service every two weeks — first week writing the chart and converting configs, second week testing at every layer. Testing ran in parallel the whole time. Final two weeks were documentation and training — brown-bag sessions, runbooks, self-healing guides so ops could handle eighty percent of incidents without me.

Result: cut release prep forty percent, hardened the platform to STIG/FIPS baselines, reliability hit ninety-nine point nine percent for eight mission apps. Then I designed and started implementing the next step — migrating from vanilla K8s to OpenShift for better multi-tenancy and build integration."

### Part 3: "And I've run K8s air-gapped" (60 seconds)

"Separately at NTConcepts, I built an RKE2 cluster inside a controlled-egress environment — our Bird-Dog hub-and-spoke network with deny-by-default egress through Network Firewall. Terraform provisioned the AWS infrastructure — VPC, ASGs, RDS, EFS, IAM roles with IRSA for pod-level access. Ansible bootstrapped the nodes — I wrote custom roles that installed the RKE2 binary, wrote the config and registries.yaml to redirect image pulls to our ECR mirror, opened firewall ports, and started the rke2-server and agent services. Three control plane nodes for HA with embedded etcd, CPU and GPU worker pools managed by Cluster Autoscaler. ArgoCD deployed everything inside the cluster from a local Git repo — infrastructure services like Istio, Keycloak, and monitoring, plus the application workloads. External Secrets Operator synced credentials from AWS Secrets Manager into the cluster via IRSA. The whole thing ran with zero internet access — only allowlisted AWS endpoints through the firewall. Tripled throughput for twelve data scientists."

### Part 4: "Here's how I'd do it for you" (90 seconds)

"For Anduril, I'd combine both playbooks.

Phase zero — two weeks — I'd spin up a single-node RKE2 cluster on a spare machine. No production impact. Run one thing on it — maybe a GitLab runner — to prove it works and measure if it saves time versus Podman. If it doesn't? Kill it, no wasted effort.

Phase one — if it proves value — move GitLab runners to K8s. Runners are stateless and ephemeral — lowest risk migration, highest scaling benefit. K8s autoscaling handles the 'pipeline jobs doubled in a month' problem natively. Keep everything else on Podman.

Phase two — migrate stateless internal tools. Use Podman's 'generate kube' to create initial K8s manifests from existing Compose setups, then templatize into Helm charts. Set up ArgoCD to manage deployments — push manifests to a Git repo, ArgoCD syncs them to the cluster automatically. No more manual deploys. If someone changes something in the cluster manually, ArgoCD detects the drift and reverts it. That's the GitOps layer you don't have today.

Phase three — if phases zero through two worked, tackle stateful services with StatefulSets and persistent volumes. Design the storage layer — StorageClass for dynamic provisioning, Retain reclaim policy for production data."

The key: each phase is independently valuable and independently reversible. If phase one saves time, great — phase two is optional. No big-bang, no half-assing it, and I've done every step of this before."

---

## Coaching: How to Deliver This

### When to Use This Pitch
- When Andy asks: "What would you do about Kubernetes?" or "How would you approach K8s here?"
- When there's a natural pause and you say: "Based on my conversations with Felipe and Andrew..."
- When asked about your biggest value-add or what you'd tackle first

### Delivery Tips
- **Don't recite it** — this is a conversation, not a presentation. Hit the key beats naturally.
- **Draw while you talk** — Part 4 (the phased plan) is great for whiteboarding: draw 4 boxes (Phase 0-3), fill in as you narrate
- **Pause after Part 1** — let Andy react. He might say "yeah, that's exactly right" or redirect
- **Numbers matter** — nine services, forty percent, six hundred users, twelve data scientists, tripled throughput. These stick.
- **End on "I've done every step before"** — that's the closer. Not "I think I could do this" but "I have done this."

### If Andy Pushes Back

**"We don't have time for a K8s migration right now"**
→ "Totally fair — that's why Phase 0 is just a single-node test on a spare machine. Two weeks, no production impact. If it doesn't prove value, we kill it. But if it does, you've got a path forward for when bandwidth opens up."

**"Why not just scale Podman?"**
→ "Podman scales containers, but it doesn't orchestrate them — no auto-restart, no rolling updates, no resource scheduling across nodes. K8s with Cluster Autoscaler handles that automatically. For runners specifically, when jobs spike, K8s spins up pods on available nodes without anyone intervening."

**"RKE2 vs K3s vs vanilla K8s?"**
→ "RKE2 for your environment. It bundles everything — one binary, embedded etcd, runs air-gapped out of the box. CIS hardened and FIPS-ready, which matters for your classified networks. K3s is lighter but doesn't have FIPS. Vanilla K8s requires assembling components yourself. RKE2 is designed for exactly this use case."

**"How do you handle images in air-gap K8s?"**
→ "RKE2 has a registries.yaml that redirects all image pulls to your local registry — whether that's Nexus or Harbor. On the connected side, you pull images to Nexus, transfer via diode, and containerd on the nodes pulls from local Nexus. Same pattern I used at NTConcepts with ECR as the local mirror."

**"What about Ansible? We're all-Ansible right now."**
→ "Ansible stays. It's perfect for node bootstrapping — I'd write roles for RKE2 server install, agent join, firewall ports, kernel params. Ansible preps the nodes, RKE2 runs the cluster, ArgoCD handles app deployment. Ansible doesn't go away — it just gets a new target."

---

## Component Study List (go deep on these for Andy)

### RKE2 Air-Gap Install (all done by Ansible roles)

**Pre-transfer (connected side — manual or pipeline):**
1. Download RKE2 binary + images tarball on connected side
2. Transfer to air-gapped hosts (via diode, USB, or S3)

**Ansible `common` role (runs on ALL nodes):**
3. Disable swap, load kernel modules (br_netfilter, overlay)
4. Set sysctl params (ip_forward, bridge-nf-call-iptables)
5. Open firewall ports (6443, 9345, 10250, 2379-2380, 8472/UDP)

**Ansible `rke2-server` role (control plane — serial: 1 for etcd ordering):**
6. Copy binary to `/usr/local/bin/rke2`
7. Copy images tarball to `/var/lib/rancher/rke2/agent/images/`
8. Template `config.yaml` (server URL, token, CIS profile, TLS SANs)
9. Template `registries.yaml` (redirect image pulls to local Nexus/ECR)
10. `systemctl enable --now rke2-server`
11. Wait for API server to be ready (retry loop)

**Ansible `rke2-agent` role (workers — parallel):**
12. Same binary + images copy
13. Template `config.yaml` (just server URL + token + node labels)
14. Template `registries.yaml` (same as servers)
15. `systemctl enable --now rke2-agent`

**Verify:** `/var/lib/rancher/rke2/bin/kubectl get nodes` — all nodes Ready

**One command runs everything:** `ansible-playbook -i inventory/production.yml playbooks/site.yml`

### registries.yaml (know this file cold)
```yaml
mirrors:
  docker.io:
    endpoint:
      - "https://nexus.local:8443"
  "registry.local":
    endpoint:
      - "https://nexus.local:8443"
configs:
  "nexus.local:8443":
    tls:
      ca_file: /etc/rancher/rke2/nexus-ca.pem
    auth:
      username: admin
      password: changeme
```

### RKE2 Ports (memorize these)
| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 9345 | TCP | RKE2 supervisor (agent join) |
| 10250 | TCP | kubelet metrics |
| 2379-2380 | TCP | etcd client/peer (server nodes only) |
| 8472 | UDP | VXLAN (Canal CNI) |

---

## Answer Keys

- **IBM migration diagrams:** `ibm-migration-answers.md`
- **Nightwatch RKE2 diagram:** `ntconcepts-answers.md` (detailed RKE2 chart)
- **How to present IBM migration:** `ibm-helm-migration.md` coaching section
- **How to present Nightwatch:** `nightwatch-rke2.md` coaching section
- **Anduril K8s scenario (phased plan):** `anduril-scenarios.md` Scenario 4
