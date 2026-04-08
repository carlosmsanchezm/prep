# Day 3: Ansible Role Structure
# Given this task, lay out the full role directory and write the key files.

---

## Task: Create an Ansible role called "node-hardening"

This role should:
1. Disable swap (swapoff + remove from fstab)
2. Set kernel parameters: net.bridge.bridge-nf-call-iptables=1, net.ipv4.ip_forward=1
3. Configure sshd: disable root login, disable password auth
4. Enable and configure auditd
5. Set a login banner (/etc/issue)

**Step 1: Write the directory tree for this role**
```
YOUR ANSWER:
roles/node-hardening/
├──
├──
├──
├──
└──
```

**Step 2: Write tasks/main.yml (all 5 tasks)**
```yaml
YOUR ANSWER:

```

**Step 3: Write handlers/main.yml**
```yaml
YOUR ANSWER:

```

**Step 4: Write defaults/main.yml (default variables)**
```yaml
YOUR ANSWER:

```

**Step 5: What would you put in templates/sshd_config.j2?**
```
YOUR ANSWER:

```
