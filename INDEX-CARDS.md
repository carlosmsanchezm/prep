# Index Cards for Monday Hands-On

Print or copy these onto index cards. One topic per card.

---

## CARD 1 — Linux Troubleshooting Flow

```
1. Service running?    → systemctl status <svc>
2. Logs?               → journalctl -u <svc> -n 50
3. Host healthy?       → top / free -h / df -h
4. Network reachable?  → ping / curl -v / ss -tlnp
5. Firewall blocking?  → firewall-cmd --list-all
6. Recent changes?     → rpm -qa --last / last -10
```

Key commands:
```
du -sh /path            directory size
ss -tlnp                listening ports + process
systemctl daemon-reload after editing .service file
journalctl -u svc -f    follow logs real-time
getenforce              SELinux status
restorecon -Rv /path    fix SELinux contexts
```

---

## CARD 2 — GitLab CI/CD Debugging Flow

```
1. AIR-GAP FIRST — scan every line for internet assumptions
   → public images (docker.io, quay.io, ghcr.io)
   → pip install / ansible-galaxy (reaches public repos)
   → get_url with external URLs
   → DNF/YUM without local repo config

2. PIPELINE SYNTAX
   → stages defined? job stage names match?
   → each job has script: key?
   → variables quoted? ("False" not False)
   → tags: not tag: (plural)
   → only + rules = conflict (pick one)
   → needs: references JOB names not stage names

3. RUNNER CONFIG
   → concurrent > 0?
   → Podman socket: /run/user/1000/podman/podman.sock
   → volumes with :Z for SELinux
   → pull_policy: if-not-present (not always)
   → no docker:dind with Podman

4. CONNECTIVITY
   → SSH key as File type CI variable
   → chmod 400 + ssh-add
   → host_key_checking = False for CI
   → correct port (22 vs custom)
```

---

## CARD 3 — Ansible Quick Reference

```
COMMON BUGS:
  state: present       (not installed)
  mode: '0644'         (quoted string, leading 0)
  daemon_reload        (underscore, not hyphen)
  handler names        case-sensitive, exact match
  become: true         needed for root tasks
  become_ask_pass: False   CI has no terminal
  hosts: must match inventory group name

ANSIBLE.CFG CHECKS:
  inventory path matches actual file?
  remote_user matches inventory ansible_user?
  roles_path correct?
  host_key_checking = False for CI

INVENTORY CHECKS:
  group name matches playbook hosts:?
  ansible_host IP correct?
  ansible_port correct (22 default)?
  ansible_python_interpreter: /usr/bin/python3
  vars: indented under group, not under hosts
```

---

## CARD 4 — Error Messages → Root Cause

```
x509: certificate signed by unknown authority
  → internal CA not trusted. Add CA cert or insecure registry

chmod: cannot access ''
  → CI variable empty. Check: protected? type=File?

Connection timed out
  → wrong port, firewall, wrong IP, network route

Permission denied (publickey)
  → SSH key missing, wrong perms, not ssh-added

Cannot connect to Docker daemon
  → Podman socket path wrong in config.toml

no such host
  → DNS record missing. Check /etc/resolv.conf

Unsupported parameters: daemon-reload
  → underscore not hyphen. daemon_reload

status=203/EXEC
  → binary not executable. chmod +x

Cannot lock /etc/passwd
  → missing become:true (not running as root)

mkdir: permission denied (volumes)
  → SELinux. Add :Z to volume mounts

role was not found
  → wrong roles_path or role not in repo

No hosts matched
  → playbook hosts: doesn't match inventory group
```

---

## CARD 5 — Podman / Registry / Air-Gap

```
REGISTRIES.CONF (/etc/containers/registries.conf):
  search:  registry.local ONLY (remove docker.io)
  block:   docker.io, quay.io, gcr.io
  insecure: registry.local (if self-signed certs)

PODMAN SOCKET:
  rootless: /run/user/1000/podman/podman.sock
  root:     /run/podman/podman.sock
  enable:   systemctl --user enable --now podman.socket

SELINUX:
  :z = shared (multiple containers)
  :Z = private (one container, more secure)
  getenforce → Enforcing = active
  ausearch -m avc → check denials

RUNNER CONFIG.TOML:
  executor = "docker"  (even for Podman — API compatible)
  host = Podman socket path
  volumes with :Z
  pull_policy = "if-not-present"
  concurrent >= 1
  NO docker:dind service
```

---

## CARD 6 — K8s Control Plane + Worker Components

```
CONTROL PLANE (master nodes):
  kube-apiserver     → front door. ALL communication goes through it.
                       kubectl, kubelet, ArgoCD — all talk to API server.
  etcd               → key-value store. cluster state, configs, secrets.
                       RKE2 embeds this (no external etcd needed).
  kube-scheduler     → decides WHICH node runs a new pod.
                       checks resources, affinity, taints/tolerations.
  kube-controller-manager → runs control loops:
                       - deployment controller (desired vs actual replicas)
                       - node controller (marks nodes NotReady)
                       - job controller (runs Jobs to completion)
  cloud-controller   → talks to cloud API (EBS, ELB, etc.)
                       NOT used on bare-metal / RKE2.

WORKER NODES:
  kubelet            → agent on every node. receives pod specs from
                       API server, tells container runtime to run them.
                       reports node status back.
  kube-proxy         → manages network rules (iptables/IPVS).
                       routes Service ClusterIP traffic to the right pod.
  container runtime  → actually runs containers.
                       containerd (standard), CRI-O (OpenShift).
                       RKE2 uses containerd.

HOW A POD GETS SCHEDULED:
  kubectl apply → API server → stores in etcd
  → scheduler picks a node → writes assignment to etcd
  → kubelet on that node sees it → tells containerd
  → containerd → runc → creates namespaces + cgroups
  → pod is running

RKE2 SPECIFICS:
  - bundled binary (no internet install)
  - embedded etcd (no external DB)
  - Canal CNI (Calico policies + Flannel overlay)
  - CIS hardened by default
  - registries.yaml → redirects containerd to local registry
  - server node = control plane + worker
  - agent node = worker only
  - join: agent connects to server on port 9345
```

---

## CARD 7 — YAML Anchors + Cache vs Artifacts

```
YAML ANCHORS:
  &name     → defines the anchor
  *name     → references it
  <<:       → merge key (inserts all keys)
  .hidden   → prefix with . = GitLab won't run it as a job

  .template: &defaults        # define
    image: registry.local/rhel9
    tags: [devops]

  deploy:
    <<: *defaults             # use — merges image + tags
    script: [ansible-playbook ...]

  BUG: &name and *name MUST match exactly

CACHE vs ARTIFACTS:
  CACHE = speeds up repeated pipeline RUNS
    → node_modules, pip cache, Go modules
    → best-effort, may not exist
    → persists BETWEEN pipelines
    → key: ${CI_COMMIT_REF_SLUG}

  ARTIFACTS = passes files between STAGES
    → build output, compiled binary, test report
    → guaranteed available to next stage
    → persists WITHIN one pipeline
    → expire_in: 1 hour

  COMMON BUG: using cache for build output
              (next stage might not get it)
```
