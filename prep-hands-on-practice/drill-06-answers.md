# Drill 06 Answers — Read the Logs, Diagnose the Failure

---

## Failure 1: x509 certificate signed by unknown authority

**Diagnosis:** The runner is trying to pull an image from `registry.local` over HTTPS, but the registry's TLS certificate is signed by an internal CA that the runner host doesn't trust. This is classic air-gap — you're running your own CA (step-ca) but the runner's container runtime doesn't have the CA cert in its trust store.

**Fix (two options):**
```bash
# Option A: Add internal CA cert to system trust store
cp internal-ca.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust

# Option B: Configure registry as insecure in registries.conf
# /etc/containers/registries.conf
[[registry]]
location = "registry.local"
insecure = true
```

Also check `pull_policy` in runner config.toml — `always` forces a fresh pull every time. Change to `if-not-present` to use cached images when available.

**Why:** Air-gapped environments use self-signed or internal CA certs. The container runtime (Podman) doesn't trust them by default. You either add the CA cert to the system trust store (preferred — real TLS verification) or mark the registry as insecure (quick fix — skips TLS verification).

---

## Failure 2: chmod: cannot access '': No such file or directory

**Diagnosis:** `$SSH_PRIVATE_KEY` is empty. The `chmod 400 ""` command fails because there's no file path. The CI variable `SSH_PRIVATE_KEY` is either:
- Not defined in GitLab CI/CD settings
- Defined as a **Protected** variable and this is running on a non-protected branch
- Defined as type **Variable** (string) instead of type **File**

**Fix:**
1. In GitLab → Settings → CI/CD → Variables, check that `SSH_PRIVATE_KEY` exists
2. Make sure it's type **File** (not Variable) — `ssh-add` needs a file path, not a string
3. If it's protected, either unprotect it or ensure the job only runs on protected branches
4. Add error handling in the pipeline:
```yaml
before_script:
  - eval $(ssh-agent -s)
  - |
    if [ -z "$SSH_PRIVATE_KEY" ]; then
      echo "ERROR: SSH_PRIVATE_KEY is not set"
      exit 1
    fi
  - chmod 400 "$SSH_PRIVATE_KEY"
  - ssh-add "$SSH_PRIVATE_KEY"
```

**Why:** GitLab CI variables of type "File" create a temporary file and set the variable to the file PATH. Type "Variable" sets it to the string VALUE. `ssh-add` needs a file path. If the variable is empty (not set or protected), `chmod` gets an empty string and fails.

---

## Failure 3: ssh: connect to host 10.0.2.10 port 22: Connection timed out

**Diagnosis:** The runner container can't reach the target hosts on port 22. "Connection timed out" (not "Connection refused") means packets aren't arriving at all. Multiple possible causes:

1. **Wrong SSH port** — inventory says default port 22, but hosts might use a non-standard port (like 2222 from drill-05)
2. **Firewall blocking** — the target host's firewall doesn't allow inbound SSH from the runner's network
3. **Network routing** — the runner container (inside K8s) can't route to the target VM's network (10.0.2.x)
4. **Wrong IP** — the IP addresses in inventory are wrong

**Fix (check in this order):**
```bash
# 1. Verify the correct SSH port
ssh -p 22 ec2-user@10.0.2.10      # try default
ssh -p 2222 ec2-user@10.0.2.10    # try non-standard

# 2. Check firewall on target host
sudo firewall-cmd --list-all       # is port 22 (or 2222) open?
sudo firewall-cmd --add-port=22/tcp --permanent && sudo firewall-cmd --reload

# 3. Check network route from runner
# From inside the runner container:
ping 10.0.2.10                     # can we reach the network at all?
traceroute 10.0.2.10               # where does the route die?

# 4. Verify inventory IPs
cat inventory/monitoring.yml       # do IPs match actual hosts?
```

If the inventory has `ansible_port: 2222`, make sure the target hosts actually listen on 2222. If they listen on 22, remove the `ansible_port` line.

**Why:** "Connection timed out" means no response at all — the packets either can't reach the host (routing/firewall) or are hitting the wrong port. "Connection refused" would mean the host IS reachable but nothing is listening. The difference tells you where to look.

---

## Failure 4: useradd: Permission denied. Cannot lock /etc/passwd

**Diagnosis:** Ansible is trying to create a system user (`node_exporter`) but doesn't have root privileges. The playbook has `become: false` (or no `become` at all), so tasks run as the SSH user (ec2-user) which can't modify `/etc/passwd`.

**Fix:**
```yaml
# Option A: Set become at the play level
- name: Deploy Prometheus node_exporter
  hosts: monitoring_servers
  become: true          # ← was false or missing

# Option B: Set become on the specific task
- name: Create node_exporter user
  user:
    name: node_exporter
    shell: /sbin/nologin
    system: yes
  become: true          # ← add this
```

Also verify `ansible.cfg` has:
```ini
[privilege_escalation]
become_method = sudo
become_ask_pass = False    # must be False in CI — no terminal for password
```

And the target host must have NOPASSWD sudo for ec2-user:
```
# /etc/sudoers.d/ec2-user
ec2-user ALL=(ALL) NOPASSWD: ALL
```

**Why:** Creating system users, writing to `/etc`, installing packages — all need root. `become: true` tells Ansible to `sudo` before running the command. Without it, everything runs as the SSH user who can't modify system files.

---

## Failure 5: Cannot connect to the Docker daemon at unix:///var/run/docker.sock

**Diagnosis:** The runner is configured to use the Docker executor but is looking for the Docker socket at `/var/run/docker.sock`. This environment uses **Podman**, not Docker — Docker isn't installed, so the socket doesn't exist.

**Fix:** Update `/etc/gitlab-runner/config.toml`:
```toml
[runners.docker]
  # Change Docker socket to Podman socket
  # For rootless Podman:
  host = "unix:///run/user/1000/podman/podman.sock"
  # For root Podman:
  # host = "unix:///run/podman/podman.sock"
```

Also ensure the Podman socket is running:
```bash
# For rootless:
systemctl --user enable --now podman.socket
ls /run/user/$(id -u)/podman/podman.sock    # verify it exists

# For root:
systemctl enable --now podman.socket
ls /run/podman/podman.sock
```

**Why:** GitLab runner's "docker" executor uses the Docker API — Podman is API-compatible but its socket is at a different path. The runner keeps trying Docker's socket, which doesn't exist. Point it to Podman's socket and ensure the socket service is running.

---

## Failure 6: dial tcp: lookup registry.local on 10.0.0.2:53: no such host

**Diagnosis:** DNS resolution failed. The host can't resolve `registry.local` — the DNS server at 10.0.0.2 doesn't have a record for it. This is an air-gap DNS issue: the internal DNS server needs records for every internal service.

**Fix:**
```bash
# 1. Check what DNS server is configured
cat /etc/resolv.conf
# nameserver 10.0.0.2    ← is this the correct internal DNS?

# 2. Test DNS resolution
dig registry.local @10.0.0.2
# Should return an A record → the IP of Nexus

# 3. If DNS record is missing, add it on the DNS server (bind):
# /etc/named/zones/db.dev.internal
# Add:
# registry.local.    IN    A    10.0.1.100

# 4. Or as a quick workaround, add to /etc/hosts:
echo "10.0.1.100 registry.local" >> /etc/hosts
```

**Why:** Air-gapped environments use internal DNS. If the DNS server doesn't have a record for `registry.local`, nothing can find it. The error "no such host" is DNS failure, not network failure. The fix is adding the DNS record or using /etc/hosts as a workaround.

---

## Failure 7: Unsupported parameters for (systemd) module: daemon-reload

**Diagnosis:** The Ansible `systemd` module uses **underscores** in parameter names, not **hyphens**. `daemon-reload` (with hyphen) is not a valid parameter. The correct parameter is `daemon_reload` (with underscore).

**Fix:**
```yaml
# BAD — hyphen
- name: Reload systemd and enable service
  systemd:
    name: node_exporter
    daemon-reload: yes       # ← WRONG: hyphen
    enabled: yes
    state: started

# GOOD — underscore
- name: Reload systemd and enable service
  systemd:
    name: node_exporter
    daemon_reload: yes       # ← CORRECT: underscore
    enabled: yes
    state: started
```

**Why:** Ansible module parameters always use underscores. This is a common mistake because the CLI command is `systemctl daemon-reload` (with hyphen), but the Ansible module parameter is `daemon_reload` (underscore). Ansible's error message is actually helpful here — it lists all supported parameters.

---

## Failure 8: status=203/EXEC — node_exporter won't start

**Diagnosis:** Exit code 203/EXEC means systemd **couldn't execute the binary**. The `ls -la` output reveals why: the file permissions are `-rw-r--r--` (644) — **no execute permission**. The binary can't run because it's not marked as executable.

**Fix:**
```bash
chmod +x /usr/local/bin/node_exporter
# OR more specific:
chmod 755 /usr/local/bin/node_exporter
```

In the Ansible playbook, fix the `unarchive` task or add a task to set permissions:
```yaml
- name: Set execute permission
  file:
    path: /usr/local/bin/node_exporter
    mode: '0755'
    owner: root
    group: root

# Or fix the copy task if using copy instead of unarchive:
- name: Copy node_exporter binary
  copy:
    src: files/node_exporter
    dest: /usr/local/bin/node_exporter
    mode: '0755'          # ← must be executable
```

**Why:** systemd 203/EXEC means "I tried to run the command in ExecStart but couldn't execute it." Common causes: wrong path, missing binary, or (like here) no execute permission. The `ls -la` shows `-rw-r--r--` — readable but not executable. The `unarchive` module or `copy` module didn't preserve or set the execute bit.

**Key insight:** When you see 203/EXEC, always check: (1) does the file exist at the ExecStart path? (2) does it have execute permissions? (3) is the file actually a binary (not a corrupted download)?

---

## Failure 9: Two Issues — Cache Failure + Role Not Found

**Issue 1: Cache failure**
```
Restoring cache
Checking cache for pip-deps-main...
No URL provided, cache is not downloaded from shared cache server.
WARNING: Cache file does not exist.
Failed to extract cache
```

**Diagnosis:** The cache is configured but the runner has no shared cache storage configured. In GitLab, cache can be stored locally (per-runner) or on a shared server (S3, GCS). This runner has no cache URL configured — so the cache from a previous pipeline run on a different runner is lost.

**Fix:** Either configure a shared cache location in `config.toml`:
```toml
[runners.cache]
  Type = "s3"   # or local path
  Path = "cache"
  [runners.cache.s3]
    ServerAddress = "nexus.local:9000"    # MinIO/Nexus as cache storage
    BucketName = "runner-cache"
    Insecure = true
```

Or, if dependencies should always be available (air-gap), don't rely on cache — pre-install them in the runner image.

**Issue 2: Role not found**
```
ERROR! the role 'monitoring_common' was not found in
/builds/devops/monitoring-deploy/roles/galaxy:
/builds/devops/monitoring-deploy/roles
```

**Diagnosis:** Ansible is looking for the role `monitoring_common` in `roles/galaxy` (from `roles_path` in ansible.cfg) and `roles/` but it doesn't exist in either location. In air-gap, you can't `ansible-galaxy install` — roles must be bundled in the project.

**Fix:**
1. Make sure the role directory exists: `roles/monitoring_common/tasks/main.yml`
2. Fix `roles_path` in ansible.cfg: `roles_path = ./roles` (remove `/galaxy`)
3. Verify the role is committed to Git (not in .gitignore)

**Why:** Two compounding issues: the cache miss means any cached dependencies are gone, and the role path is wrong in ansible.cfg. In air-gap, every dependency must be in the repo or in the runner image — you can't download anything at runtime.

---

## Failure 10: mkdir /builds: permission denied — SELinux volume mount

**Diagnosis:** The runner container can't create the `/builds` directory on the host volume mount. On RHEL with SELinux enforcing, containers are blocked from writing to host directories unless the SELinux context is correct.

**Fix:** Add `:Z` to volume mounts in `/etc/gitlab-runner/config.toml`:
```toml
[runners.docker]
  volumes = ["/cache:/cache:Z", "/builds:/builds:Z"]
  #                        ^^^                  ^^^  add :Z
```

The `:Z` flag tells Podman to relabel the mount with the correct SELinux context for the container.

```bash
# Verify SELinux is the issue:
getenforce                    # "Enforcing" confirms SELinux is active
ausearch -m avc --ts recent   # check for SELinux denials

# After fixing config.toml, restart the runner:
systemctl restart gitlab-runner
```

**Why:** SELinux on RHEL prevents containers from accessing host filesystem paths unless they have the correct security label. The `:Z` flag on the volume mount tells the container runtime to automatically relabel the directory with the container's SELinux context. Without it, SELinux blocks the write and you get "permission denied."

---

## Summary — Error Pattern Quick Reference

| Error message | Root cause | Category |
|--------------|-----------|----------|
| `x509: certificate signed by unknown authority` | Internal CA cert not trusted | Registry/TLS |
| `chmod: cannot access ''` | CI variable empty (not set, protected, or wrong type) | Pipeline config |
| `Connection timed out` | Network/firewall/wrong port — packets not arriving | Connectivity |
| `Permission denied. Cannot lock /etc/passwd` | Missing `become: true` — not running as root | Ansible privilege |
| `Cannot connect to Docker daemon` | Podman socket not configured, Docker socket doesn't exist | Runner config |
| `no such host` | DNS can't resolve hostname — record missing | DNS/air-gap |
| `Unsupported parameters: daemon-reload` | Hyphen vs underscore in Ansible module param | Ansible syntax |
| `status=203/EXEC` | Binary not executable (chmod), wrong path, or corrupted | systemd/target host |
| `Cache file does not exist` | No shared cache configured, cache is per-runner | Pipeline config |
| `role was not found` | Role not in repo, wrong roles_path in ansible.cfg | Ansible config |
| `mkdir: permission denied` on volume | SELinux blocking — missing `:Z` on volume mount | SELinux/Podman |

**The pattern:** Read the EXACT error message. It almost always tells you what's wrong. The skill is mapping the error to the right component and knowing the fix.
