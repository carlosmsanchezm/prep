# Index Cards — Interview Reference

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

---

## CARD 8 — SRE Troubleshooting: Symptom → First Command

```
SYMPTOM                          FIRST COMMANDS
─────────────────────────────────────────────────────
High CPU                         top -o %CPU
                                 ps aux --sort=-%cpu | head

High memory / OOM killed         free -h
                                 dmesg | grep -i oom
                                 ps aux --sort=-%mem | head

Disk full                        df -h
                                 du -sh /var/log/*
                                 find / -type f -size +100M
                                 journalctl --disk-usage

Service won't start              systemctl status <svc>
                                 journalctl -u <svc> -n 50
                                 systemctl cat <svc>
                                 <svc> -t  or --check-config

Can't connect to service         curl -v http://host:port
                                 ss -tlnp (on target host)
                                 ping <host>

DNS not resolving                dig <hostname>
                                 cat /etc/resolv.conf
                                 nslookup <hostname>

Permission denied                ls -la /path/to/file
                                 getenforce
                                 ausearch -m avc --ts recent
                                 id <username>

TLS / certificate error          openssl s_client -connect host:443
                                 openssl x509 -in cert.pem -noout -dates
                                 curl -vk https://host

Container not running            podman ps -a
                                 podman logs <container>
                                 podman inspect <container>

Firewall blocking                firewall-cmd --list-all
                                 iptables -L -n
                                 ss -tlnp (is port listening?)

Slow network / routing           traceroute <host>
                                 ip route
                                 ip addr
                                 mtr <host>
```

---

## CARD 9 — SRE Troubleshooting: Full Investigation Flow

```
FOR ANY ISSUE:
1. OBSERVE     → what is the symptom?
               uptime (load), top (CPU/mem), df -h (disk)
               systemctl status <svc>, ss -tlnp (ports)

2. ISOLATE     → which process/service/component?
               ps aux --sort=-%cpu or -%mem
               journalctl -u <svc> -n 50
               docker/podman logs <container>

3. INSPECT     → what is causing it?
               cat the script, config, or unit file
               check cron (crontab -l, /etc/cron.d/*)
               check systemd timers (systemctl list-timers)
               grep -R <name> /etc (find all references)

4. ROOT CAUSE  → WHY is it happening?
               log file too large? (ls -lh /var/log/*)
               infinite loop in script?
               cron running too frequently?
               config pointing to wrong host/port?
               disk full causing writes to fail?
               DNS not resolving?
               cert expired?
               firewall blocking?

5. MITIGATE    → immediate fix
               truncate log, kill process, adjust cron
               restart service, open port, fix config
               rotate logs, clear disk, fix permissions

6. PREVENT     → long-term fix
               log rotation (logrotate)
               monitoring alerts (Prometheus)
               config management (Ansible)
               runbooks for operators
               design docs for architectural changes

7. DOCUMENT    → postmortem
               what happened, timeline, root cause
               what was done, what will prevent recurrence
```

---

## CARD 10 — Networking Troubleshooting Deep Dive

```
"CAN'T CONNECT" DEBUGGING ORDER:
1. Is DNS working?
   dig <hostname>
   → if NXDOMAIN: DNS record missing
   → if timeout: DNS server unreachable
   → check: cat /etc/resolv.conf

2. Can I reach the host?
   ping <ip-address>
   → if timeout: network/routing/firewall
   → if success: host is reachable

3. Is the port open?
   ss -tlnp | grep <port>  (run ON target host)
   → if nothing: service not listening
   → if listening: something else blocking

4. Is firewall blocking?
   firewall-cmd --list-all  (on target)
   iptables -L -n           (on target)
   → look for DROP/REJECT rules on the port

5. Is the service responding?
   curl -v http://host:port
   → connection refused = port not listening
   → timeout = firewall or routing
   → 5xx = service error (check service logs)
   → TLS error = cert problem

6. Where does the path break?
   traceroute <host>
   → see which hop stops responding

COMMON FIXES:
  firewall-cmd --add-port=80/tcp --permanent && firewall-cmd --reload
  systemctl restart <service>
  echo "nameserver 10.0.0.2" > /etc/resolv.conf
```

---

## CARD 11 — Ansible Playbook from Memory (Fleet Management)

```
BASIC ROLE STRUCTURE:
  roles/
    auditd/
      tasks/main.yml
      templates/audit.rules.j2
      handlers/main.yml
      defaults/main.yml

PLAYBOOK:
---
- name: Deploy auditd across fleet
  hosts: all
  become: true
  serial: "10%"              # phased rollout

  tasks:
    - name: Install auditd
      package:
        name: audit
        state: present

    - name: Deploy audit rules
      template:
        src: audit.rules.j2
        dest: /etc/audit/rules.d/custom.rules
        mode: '0640'
      notify: restart auditd

    - name: Ensure auditd running
      service:
        name: auditd
        state: started
        enabled: yes

  handlers:
    - name: restart auditd
      service:
        name: auditd
        state: restarted

ROLLOUT STRATEGY:
  serial: "10%"   → 10% of fleet at a time
  max_fail_percentage: 5   → stop if >5% fail
  any_errors_fatal: true   → stop on first error

ROLLBACK PATTERN:
  - use a variable: rollback_mode: false
  - when rollback_mode: stop service, remove config, uninstall
  - Ansible Tower/AWX: schedule runs for continuous compliance
```

---

## CARD 12 — Go Coding Patterns (Memorize These)

```
MULTIPLES OF 2:
func multiples(n int) []int {
    result := []int{}
    for i := 0; i < n; i++ {
        result = append(result, i*2)
    }
    return result
}

FIBONACCI:
func fib(n int) []int {
    if n <= 0 { return []int{} }
    if n == 1 { return []int{0} }
    result := []int{0, 1}
    for i := 2; i < n; i++ {
        next := result[i-1] + result[i-2]
        result = append(result, next)
    }
    return result
}

CACHING WITH MAP:
var cache = map[int][]int{}

func cachedFib(n int) []int {
    if val, ok := cache[n]; ok {
        return val
    }
    result := fib(n)
    cache[n] = result
    return result
}

GO BASICS TO REMEMBER:
  := short variable declaration
  []int{} empty int slice
  append(slice, value) add to slice
  map[KeyType]ValueType{} create map
  val, ok := map[key] check if key exists
  for i := 0; i < n; i++ {} standard loop
  fmt.Println() print output
  func name(param type) returnType {}
```
