# Linux Troubleshooting Cheatsheet — Memorize This

> **Anduril runs RHEL bare-metal.** Andrew's interview was literally: "web app is down on a single host, troubleshoot it." Know these commands cold.

## The Troubleshooting Flow (memorize this order)

```
1. Is the service running?      → systemctl status / ps aux
2. What do the logs say?        → journalctl / tail logs
3. Is the host healthy?         → top / free / df
4. Is the network reachable?    → ping / curl / ss
5. Is the firewall blocking?    → firewall-cmd / iptables
6. Any recent changes?          → last / rpm -qa --last / git log
```

## Service Management (systemd)

```bash
# Check if service is running
systemctl status nginx
systemctl is-active nginx          # just "active" or "inactive"
systemctl is-enabled nginx         # starts on boot?

# Start / Stop / Restart
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx             # graceful reload (no downtime)

# Enable on boot
systemctl enable nginx
systemctl enable --now nginx       # enable AND start

# List all services
systemctl list-units --type=service
systemctl list-units --type=service --state=failed    # just failed ones

# Daemon reload (after editing unit files)
systemctl daemon-reload
```

## Logs (journalctl)

```bash
# Service logs
journalctl -u nginx                        # all nginx logs
journalctl -u nginx -n 50                  # last 50 lines
journalctl -u nginx -f                     # follow (like tail -f)
journalctl -u nginx --since "1 hour ago"   # time filter
journalctl -u nginx --since today          # today only
journalctl -u nginx -p err                 # only errors

# System-wide
journalctl -b                              # current boot
journalctl -b -1                           # previous boot
journalctl --disk-usage                    # how much space logs take

# Kernel messages
dmesg                                      # kernel ring buffer
dmesg -T                                   # with human-readable timestamps
dmesg | tail -20                           # recent kernel messages

# Traditional log files
tail -f /var/log/messages                  # RHEL system log
tail -f /var/log/secure                    # auth/SSH logs
tail -f /var/log/nginx/error.log           # app-specific
```

## Resource Monitoring

```bash
# CPU and memory — live view
top                                        # interactive (q to quit)
htop                                       # better UI (if installed)

# Memory
free -h                                    # human-readable
# Look for: available (not just free — available includes cache)

# Disk
df -h                                      # filesystem usage
df -h /                                    # just root
du -sh /var/log/*                          # what's eating disk
lsblk                                      # block devices

# CPU info
nproc                                      # number of CPUs
uptime                                     # load averages
# Load > nproc = overloaded

# Processes
ps aux                                     # all processes
ps aux | grep nginx                        # find specific
ps aux --sort=-%mem | head -10             # top memory consumers
ps aux --sort=-%cpu | head -10             # top CPU consumers

# IO
iostat -x 1                                # disk IO per second
iotop                                      # like top but for disk IO

# Open files
lsof -i :80                                # what's using port 80
lsof -p $(pgrep nginx)                     # files opened by nginx
```

## Network Troubleshooting

```bash
# Is the host reachable?
ping -c 3 10.0.1.50                        # 3 pings
ping -c 3 hostname.local                   # test DNS too

# Is the port open?
ss -tlnp                                   # TCP listening ports + process
ss -tlnp | grep 80                         # is port 80 listening?
# -t = TCP, -l = listening, -n = numeric, -p = process

# Test remote port
nc -zv 10.0.1.50 80                        # is port 80 open on remote?
curl -v http://10.0.1.50                   # HTTP test
curl -vk https://10.0.1.50                 # HTTPS (skip cert verify)

# What's my IP?
ip addr                                    # all interfaces
ip addr show eth0                          # specific interface
hostname -I                                # just IPs

# Routing
ip route                                   # routing table
ip route get 10.0.1.50                     # which route for this IP?
traceroute 10.0.1.50                       # trace path

# DNS
dig hostname.local                         # full DNS query
nslookup hostname.local                    # simple lookup
cat /etc/resolv.conf                       # DNS config

# ARP (local network)
ip neigh                                   # ARP table
arping -I eth0 10.0.1.50                   # ARP ping
```

## Firewall (RHEL uses firewalld)

```bash
# Status
firewall-cmd --state                       # running?
firewall-cmd --list-all                    # all rules

# Open ports
firewall-cmd --add-port=80/tcp --permanent
firewall-cmd --add-port=443/tcp --permanent
firewall-cmd --reload

# Open service
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=https --permanent
firewall-cmd --reload

# Rich rules (specific source)
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" port protocol="tcp" port="8080" accept'

# Remove rules
firewall-cmd --remove-port=80/tcp --permanent
firewall-cmd --reload

# Zones
firewall-cmd --get-active-zones
firewall-cmd --zone=public --list-all
```

## Package Management (RHEL)

```bash
# Install
dnf install nginx                          # RHEL 8+
yum install nginx                          # RHEL 7

# Search
dnf search podman
dnf info podman                            # details

# Update
dnf update                                 # all packages
dnf update nginx                           # specific

# List installed
rpm -qa                                    # all packages
rpm -qa --last | head -20                  # recently installed (good for "what changed?")
rpm -qi nginx                              # package info

# Check what package owns a file
rpm -qf /usr/bin/podman
```

## User & Permission Management

```bash
# Who am I?
whoami
id                                         # UID, GID, groups

# Switch user
su - username
sudo -i                                    # root shell

# Check sudo access
sudo -l                                    # what can I sudo?

# File permissions
ls -la /etc/nginx/
chmod 644 file                             # rw-r--r--
chmod 755 dir                              # rwxr-xr-x
chown nginx:nginx /var/www/html

# SELinux (RHEL enforces this!)
getenforce                                 # Enforcing, Permissive, Disabled
sestatus                                   # detailed status
ls -Z /var/www/html                        # SELinux context on files
# If "Permission denied" but file perms look fine → probably SELinux
# Quick test: setenforce 0 (temporarily disable) — if it works, SELinux was blocking
# Fix: restorecon -Rv /path/to/files (restore correct context)
```

## SELinux Troubleshooting (CRITICAL for RHEL)

```bash
# Check if SELinux is blocking something
ausearch -m AVC -ts recent                 # recent denials
sealert -a /var/log/audit/audit.log        # human-readable analysis

# Common fix: restore file context
restorecon -Rv /var/www/html

# Allow a service to do something (boolean)
getsebool -a | grep httpd                  # list httpd booleans
setsebool -P httpd_can_network_connect on  # allow Nginx to make outbound connections

# If container volume mount fails (Podman + SELinux):
# Add :Z to the volume mount in podman run or compose
```

## STIG Hardening — Common Mistakes and Blast Radius

> Taylor asked: "What are common mistakes from STIG hardening that could break applications or have a blast radius?"

**What STIGs are:** Security Technical Implementation Guides — DoD-mandated configuration standards. They lock down systems but can break things if applied blindly.

### Common Mistakes That Break Applications

```bash
# 1. SSH lockout — tighten SSH config too much
# STIG requires: PermitRootLogin no, AllowGroups sshusers, MaxAuthTries 3
# BREAKS: if the app user isn't in sshusers group, Ansible can't connect
# FIX: verify the deploy user is in the allowed group BEFORE applying

# 2. Firewall too restrictive — close ports the app needs
# STIG requires: deny all inbound by default
# BREAKS: app listens on 8080 but only 22/443 are open → connection refused
# FIX: audit all ports the app uses (ss -tlnp) BEFORE applying firewall rules

# 3. SELinux set to enforcing — blocks app file access
# STIG requires: SELinux enforcing
# BREAKS: app writes to /opt/myapp/data but SELinux context is wrong → permission denied
# FIX: set correct file contexts (semanage fcontext + restorecon) or add booleans

# 4. Crypto/TLS policy too strict — ciphers incompatible
# STIG requires: FIPS mode, TLS 1.2+ only, specific cipher suites
# BREAKS: older apps or clients can't negotiate TLS → handshake failure
# FIX: test all app connections after tightening. Check: openssl s_client -connect host:port

# 5. File permissions locked down — app can't read its own config
# STIG requires: restrict permissions on /etc, /var, /tmp
# BREAKS: app needs to read /etc/myapp/config.yml but permissions are 600 root:root
# FIX: set correct ownership/group for app files

# 6. Disabled services the app depends on
# STIG requires: disable unnecessary services (cups, avahi, rpcbind, etc.)
# BREAKS: if you disable a service the app actually uses (e.g., rpcbind for NFS)
# FIX: inventory app dependencies BEFORE applying STIG
```

### Kubernetes-Specific STIG Issues

```bash
# 1. RBAC too restrictive — pods can't access API server
# STIG: minimize ClusterRoleBindings
# BREAKS: app needs to list pods or read configmaps → 403 Forbidden
# FIX: use least-privilege Role (not ClusterRole), namespace-scoped

# 2. Security contexts break containers
# STIG: drop all capabilities, run as non-root, read-only rootfs
# BREAKS: container needs NET_BIND_SERVICE (port 80), or writes to /tmp
# FIX: add ONLY the capabilities needed, mount tmpfs for /tmp

# 3. Network policies isolate pods that need to talk
# STIG: deny all ingress/egress by default
# BREAKS: pod A can't reach pod B even though they're in the same namespace
# FIX: add explicit allow rules for required pod-to-pod traffic

# 4. Pod Security Standards (Restricted) too strict
# STIG: enforce restricted profile
# BREAKS: app needs hostNetwork, privileged, or hostPath
# FIX: evaluate if the app can be refactored, or use exceptions sparingly
```

### The Right Approach to STIG Hardening
```
1. Inventory — know what the app uses (ports, files, services, users)
2. Apply in dev/test FIRST — never go straight to production
3. Test after EVERY change — don't batch 50 STIGs and test once
4. Have a rollback plan — snapshot/backup before applying
5. Document exceptions — some STIGs need waivers for specific apps
```

**How to explain to Andy:** "The biggest STIG mistakes I've seen are SSH lockouts where the deploy user isn't in the allowed group, firewall rules that close ports the app needs, and SELinux blocking file access. The fix is always: audit what the app needs BEFORE applying hardening. Apply in test first, test after every change, and have a rollback plan."

---

## Git — Squash Commits and Git LFS

> Taylor asked about squash commits and Git LFS for large files.

### Squash Commits

**What it is:** Combining multiple commits into a single one before merging. Keeps the main branch history clean.

```bash
# Scenario: you made 5 small commits on a feature branch
# git log --oneline:
# abc1234 fix typo
# def5678 add error handling
# ghi9012 wip
# jkl3456 more wip
# mno7890 start feature X

# Option 1: Squash during merge (most common in GitLab)
# In GitLab MR settings → "Squash commits when merging"
# Result: one clean commit on main instead of 5 messy ones

# Option 2: Interactive rebase (manual squash)
git rebase -i HEAD~5
# Editor opens — change "pick" to "squash" (or "s") for commits to combine:
# pick mno7890 start feature X
# squash jkl3456 more wip
# squash ghi9012 wip
# squash def5678 add error handling
# squash abc1234 fix typo
# Save → edit the combined commit message → done

# Option 3: Soft reset (quick squash)
git reset --soft HEAD~5
git commit -m "Add feature X with error handling"
```

**When to use squash:**
- Feature branches with lots of WIP commits → squash into one meaningful commit
- Merge requests in GitLab → enable "Squash commits" in MR settings
- Keeping main branch history readable — one commit per feature/fix

**When NOT to squash:**
- When individual commits matter (e.g., a series of deliberate refactoring steps)
- When multiple authors contributed and you want to preserve attribution

### Git LFS (Large File Storage)

**What it is:** Git extension that stores large files (PDFs, images, binaries, datasets) outside the main repo. Git tracks a pointer file; the actual content lives on a separate LFS server.

```bash
# Install
git lfs install

# Track large file types
git lfs track "*.pdf"
git lfs track "*.tar.gz"
git lfs track "*.iso"
# This creates/updates .gitattributes:
# *.pdf filter=lfs diff=lfs merge=lfs -text

# Commit .gitattributes FIRST
git add .gitattributes
git commit -m "Track PDFs with Git LFS"

# Then add and commit large files normally
git add docs/manual.pdf
git commit -m "Add user manual"
git push    # large file goes to LFS server, pointer goes to Git

# Check what's tracked by LFS
git lfs ls-files

# Check LFS status
git lfs status
```

**Why it matters:**
- Git repos get slow with large binary files — every clone downloads the full history
- LFS stores the content on a separate server, Git only stores a small pointer (~130 bytes)
- Clone stays fast, large files downloaded on demand

**In air-gap context:** LFS server must be local (GitLab has built-in LFS support). Large files transferred in via the same diode/bundle process as everything else.

---

## The "Web App Down" Troubleshooting Script (Andrew's exact scenario)

```bash
# 1. Is the service running?
systemctl status nginx

# 2. If dead, check logs
journalctl -u nginx -n 50

# 3. If running but not responding, check port
ss -tlnp | grep 80

# 4. Check resources
free -h                    # memory
df -h /                    # disk
top -bn1 | head -15        # CPU snapshot

# 5. Check firewall
firewall-cmd --list-all | grep 80

# 6. Check from outside
curl -v http://server-ip

# 7. Check DNS (if by hostname)
dig server-hostname

# 8. Recent changes?
rpm -qa --last | head -10
last -10                   # recent logins
```
