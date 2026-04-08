# How Ansible Connects to Remote Hosts (EC2 / VMs)

> Taylor's scenario: GitLab runner runs Ansible to deploy to an EC2 instance. This covers the connection mechanics.

---

## The Connection Chain

```
GitLab Runner → SSH → Target EC2 Instance
    (runs ansible-playbook)     (receives + executes tasks)

What Ansible needs:
1. Target host IP or hostname (from inventory)
2. SSH private key (to authenticate)
3. Username (ec2-user, ubuntu, root)
4. Become/sudo config (to run as root)
```

---

## Inventory File — Telling Ansible WHERE to Connect

```yaml
# inventory/hosts.yml

all:
  hosts:
    web-server:
      ansible_host: 10.0.1.50              # IP address of the EC2 instance
      ansible_user: ec2-user                # SSH username (RHEL = ec2-user, Ubuntu = ubuntu)
      ansible_ssh_private_key_file: ~/.ssh/deploy-key.pem   # SSH private key path
      ansible_python_interpreter: /usr/bin/python3           # Python path on remote host

  vars:
    ansible_connection: ssh                 # default — SSH to remote hosts
    ansible_become: true                    # run tasks as root via sudo
    ansible_become_method: sudo
```

**Common bugs in inventory:**
- Wrong `ansible_host` IP — copied from another environment, doesn't match the actual EC2 IP
- Wrong `ansible_user` — RHEL uses `ec2-user`, Ubuntu uses `ubuntu`, Amazon Linux uses `ec2-user`
- Missing or wrong `ansible_ssh_private_key_file` — key doesn't exist, wrong permissions, or wrong path
- Missing `ansible_python_interpreter` — some minimal AMIs don't have Python in the default path

---

## SSH Key Setup (in a CI/CD Pipeline)

In a GitLab CI pipeline, the runner doesn't have SSH keys by default. You must inject them:

```yaml
# .gitlab-ci.yml

variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"    # skip host key verification in CI

deploy:
  stage: deploy
  before_script:
    # Start SSH agent
    - eval $(ssh-agent -s)
    
    # Add the private key (stored as a GitLab CI/CD File variable)
    - chmod 400 "$SSH_PRIVATE_KEY"       # restrict permissions — SSH requires this
    - ssh-add "$SSH_PRIVATE_KEY"          # load key into agent
    
    # Verify the key loaded
    - ssh-add -l
  script:
    - ansible-playbook -i inventory/hosts.yml playbook.yml
```

**Where `$SSH_PRIVATE_KEY` comes from:**
GitLab → Settings → CI/CD → Variables → Add Variable:
- Key: `SSH_PRIVATE_KEY`
- Type: **File** (not Variable — File writes the content to a temp file, Variable injects as env var)
- Value: paste the private key content
- Protected: Yes (only available on protected branches)

**Common bugs:**
- Variable type is "Variable" instead of "File" — SSH gets the key content as a string, not a file path → `ssh-add: not a private key`
- Missing `chmod 400` — SSH refuses keys with open permissions: `Permissions 0644 for 'key.pem' are too open`
- `eval $(ssh-agent -s)` missing — `ssh-add: Could not open a connection to your authentication agent`

---

## ansible.cfg — Global Ansible Configuration

```ini
# ansible.cfg (in the project root — Ansible reads this automatically)

[defaults]
inventory = inventory/hosts.yml       # default inventory file
remote_user = ec2-user                # default SSH user
host_key_checking = False             # don't verify host keys in CI
timeout = 30                          # SSH connection timeout (seconds)
stdout_callback = yaml                # readable output format
retry_files_enabled = False           # don't create .retry files

[privilege_escalation]
become = True                         # run tasks as root
become_method = sudo
become_user = root
become_ask_pass = False               # CRITICAL: no password prompt in CI
```

**Common bugs:**
- `become_ask_pass = True` → pipeline hangs forever waiting for password input
- `inventory` path wrong → Ansible uses default `/etc/ansible/hosts` (empty) → `No hosts matched`
- `remote_user` wrong → SSH connects as wrong user → permission denied or wrong home directory
- Missing `host_key_checking = False` → first connection fails with `Host key verification failed`
- `timeout` too low for slow networks → connection timeout before SSH handshake completes

---

## Become/Sudo — How Ansible Gets Root Access

Most tasks need root: installing packages, editing system files, managing services. The target host needs sudo configured for the SSH user:

```bash
# On the EC2 instance, the ec2-user should have NOPASSWD sudo:
# /etc/sudoers.d/ec2-user
ec2-user ALL=(ALL) NOPASSWD: ALL
```

**If sudo requires a password:**
- Ansible will fail with `Missing sudo password` in CI
- Fix on the host: add NOPASSWD to sudoers
- Or set `become_ask_pass = True` + `ansible_become_pass` variable (but this puts passwords in CI variables — not ideal)

**If become is missing entirely:**
- Tasks that need root (install packages, systemctl, edit /etc/ files) will fail with `Permission denied`
- Fix: add `become: true` at the play level or per-task

---

## Common Connection Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Permission denied (publickey)` | SSH key wrong, missing, or wrong permissions | Check key path, `chmod 400`, `ssh-add` in before_script |
| `Host key verification failed` | First connection, host not in known_hosts | Set `host_key_checking = False` in ansible.cfg |
| `Connection timed out` | Can't reach host — wrong IP, firewall, security group | Verify IP, check SG allows TCP 22 from runner |
| `No hosts matched` | Inventory file wrong or missing | Check `inventory` path in ansible.cfg, verify file exists |
| `Missing sudo password` | become_ask_pass is True or NOPASSWD not configured | Set `become_ask_pass = False`, add NOPASSWD to sudoers |
| `SSH connect to host port 22: Connection refused` | SSH not running on target, or wrong port | Check `systemctl status sshd` on target, verify port |
| `/usr/bin/python: not found` | Python missing on target host | Set `ansible_python_interpreter: /usr/bin/python3` in inventory |
| `unreachable` | DNS can't resolve hostname, or host is down | Use IP instead of hostname, verify host is running |
