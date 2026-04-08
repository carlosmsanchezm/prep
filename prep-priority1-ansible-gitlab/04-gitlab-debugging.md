# GitLab CI/CD Debugging — Common Problems & How to Fix Them

> Taylor's scenario involves a buggy GitLab CI/CD setup deploying via Ansible. These are the problems you'll encounter.

---

## 1. Runner Not Picking Up Jobs

**Symptoms:** Pipeline stuck in "pending" forever. No runner starts the job.

**Check these in order:**

```bash
# Is the runner registered?
gitlab-runner list
# Should show: runner name, URL, token, executor

# Is the runner running?
systemctl status gitlab-runner
# or if it's a pod:
kubectl get pods -l app=gitlab-runner

# Does the runner's tags match the job's tags?
# In .gitlab-ci.yml:
deploy:
  tags:
    - ansible          # job requires "ansible" tag
# Runner must be registered WITH this tag — or remove tags from the job

# Is the runner in the right project/group?
# Check GitLab UI → Settings → CI/CD → Runners → is the runner visible?
```

**Most common cause:** Tag mismatch. Job requires a tag the runner doesn't have. Fix: either add the tag to the runner registration or remove `tags:` from the job.

**Second most common:** Runner is registered but the service isn't running. `systemctl start gitlab-runner`.

---

## 2. .gitlab-ci.yml Syntax Errors

**Symptoms:** Pipeline won't create at all. GitLab shows "yaml invalid" or "config error."

**Common mistakes:**

```yaml
# BAD — stage name mismatch
stages:
  - build
  - deploy

deploy_job:
  stage: deployment    # "deployment" doesn't match "deploy"

# BAD — missing script key
deploy:
  stage: deploy
  # no script: key — every job MUST have script

# BAD — wrong indentation
deploy:
stage: deploy         # should be indented under deploy:
  script:
    - echo "deploying"

# BAD — using 'only' with 'rules' (can't mix)
deploy:
  stage: deploy
  only:
    - main
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# BAD — variable not quoted in comparison
rules:
  - if: $CI_COMMIT_BRANCH == main    # "main" needs quotes
# GOOD:
  - if: $CI_COMMIT_BRANCH == "main"
```

**How to validate:** GitLab has a built-in linter: project → CI/CD → Editor → "Validate" button. Or locally: `gitlab-ci-lint` tool.

---

## 3. Podman Executor Issues

**Symptoms:** Runner picks up job but container fails to start. Errors about socket, permissions, or image pull.

```bash
# "Cannot connect to the Docker daemon" with Podman
# The runner is configured for Docker executor but Podman socket isn't running

# Fix: enable Podman socket
systemctl --user enable --now podman.socket
# Verify:
ls /run/user/$(id -u)/podman/podman.sock

# Runner config.toml needs DOCKER_HOST pointing to Podman:
# [runners.docker]
#   host = "unix:///run/user/1000/podman/podman.sock"

# "permission denied" on volume mount (SELinux)
# Podman on RHEL with SELinux enforcing blocks volume mounts
# Fix: add :Z to volume mounts in config.toml
# [runners.docker]
#   volumes = ["/cache:/cache:Z", "/builds:/builds:Z"]

# "image not found" in air-gap
# Runner tries to pull from docker.io but there's no internet
# Fix: configure /etc/containers/registries.conf
# [registries.search]
# registries = ['nexus.local:5000']
# [registries.block]
# registries = ['docker.io']    # block public registry
```

---

## 4. Pipeline Variable Problems

**Symptoms:** Job runs but fails because a variable is empty or wrong.

```yaml
# BAD — variable used but never defined
deploy:
  script:
    - ansible-playbook -i $INVENTORY playbook.yml
# $INVENTORY is empty → ansible fails with "no inventory"

# FIX — define variables at the top
variables:
  INVENTORY: "inventory/production.yml"

# BAD — variable expansion in single quotes (won't expand)
  script:
    - echo '$MY_VAR'     # prints literal $MY_VAR
# GOOD:
    - echo "$MY_VAR"     # expands the variable

# BAD — protected variable not available in non-protected branch
# If DEPLOY_KEY is marked "Protected" in GitLab settings,
# it's ONLY available on protected branches (main, production)
# Feature branches can't access it → empty → SSH fails
```

---

## 5. SSH Key Issues (Runner → EC2)

**Symptoms:** Ansible can't reach the target host. "Permission denied (publickey)" or "Host key verification failed."

```bash
# "Permission denied (publickey)"
# The runner doesn't have the SSH private key to connect
# Fix: add the key as a GitLab CI/CD variable (type: File)
# Then in .gitlab-ci.yml:
before_script:
  - eval $(ssh-agent -s)
  - chmod 400 "$SSH_PRIVATE_KEY"      # CI variable (file type)
  - ssh-add "$SSH_PRIVATE_KEY"

# "Host key verification failed"
# First time connecting — host not in known_hosts
# Fix in ansible.cfg:
[defaults]
host_key_checking = False
# Or in .gitlab-ci.yml:
variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"

# "Connection timed out"
# Can't reach the host at all — network issue
# Check: is the security group open? Is the IP correct? Is SSH port 22 open?
# Fix: verify inventory has correct ansible_host IP
# Fix: verify security group allows inbound TCP 22 from runner's IP
```

---

## 6. Ansible Configuration Issues

**Symptoms:** Ansible runs but does unexpected things — wrong host, wrong user, no sudo.

```ini
# ansible.cfg — check these settings:

[defaults]
inventory = inventory/hosts.yml    # wrong path? Ansible uses default /etc/ansible/hosts
remote_user = ec2-user             # wrong user? Ubuntu uses "ubuntu", RHEL uses "ec2-user"
host_key_checking = False          # set to False for CI environments
timeout = 30                       # connection timeout — increase if network is slow

[privilege_escalation]
become = True                      # if missing, tasks that need root will fail
become_method = sudo               # default, but some systems use "su"
become_user = root
become_ask_pass = False            # MUST be False in CI — no one to type password
```

**Common gotcha:** `become_ask_pass = True` in CI → pipeline hangs waiting for password input that never comes. Always `False` in automated environments.

---

## 7. Artifact and Cache Problems

**Symptoms:** Files from one stage aren't available in the next stage.

```yaml
# BAD — artifacts defined but wrong path
build:
  script:
    - ansible-galaxy collection install -r requirements.yml -p ./collections
  artifacts:
    paths:
      - collections/        # trailing slash might cause issues on some versions

# BAD — no artifacts defined → next stage can't see files
lint:
  script:
    - ansible-lint playbook.yml
deploy:
  script:
    - ansible-playbook playbook.yml    # where's the playbook? Not passed from lint stage

# GOOD — pass artifacts between stages
lint:
  artifacts:
    paths:
      - "*.yml"
    expire_in: 1 hour
```

---

## 8. Common Error Messages and What They Mean

| Error message | Cause | Fix |
|--------------|-------|-----|
| `yaml invalid` | .gitlab-ci.yml syntax error | Check indentation, missing colons, stage name mismatch |
| `stuck in pending` | No matching runner | Check tags, runner registration, runner service status |
| `Permission denied (publickey)` | SSH key missing or wrong | Add key as CI variable, ssh-add in before_script |
| `Host key verification failed` | First SSH connection, no known_hosts | Set host_key_checking=False in ansible.cfg |
| `Connection timed out` | Can't reach host | Check IP in inventory, security group, network route |
| `become_ask_pass not set` | Ansible needs sudo password | Set become_ask_pass=False, use NOPASSWD in sudoers |
| `No such file or directory` | Artifact not passed, wrong path | Check artifact paths, file exists in current stage |
| `ModuleNotFoundError` | Python module not in runner image | Install in before_script or use custom image |
| `ERROR! the role 'my_role' was not found` | Role path wrong or not installed | Check roles_path in ansible.cfg, galaxy install |
| `fatal: No inventory was parsed` | Inventory file path wrong | Check inventory path in ansible.cfg or -i flag |

---

## Debugging Flow for Taylor's Scenario

When Taylor shows you the buggy project, follow this order:

```
1. READ .gitlab-ci.yml FIRST
   → Are stages defined? Do job stage names match?
   → Does each job have a script: key?
   → Are variables defined? Are they quoted?
   → Are runner tags correct?
   → Are artifacts passed between stages?

2. CHECK runner configuration
   → Is the runner registered with correct tags?
   → Is the executor correct (docker/podman)?
   → Is DOCKER_HOST set for Podman?
   → Are volume mounts correct (:Z for SELinux)?

3. READ the Ansible files
   → Is ansible.cfg correct? (inventory path, remote_user, become)
   → Is inventory correct? (ansible_host IP, ansible_user, SSH key path)
   → Is the playbook valid? (state values, mode strings, handler names, become)

4. CHECK connectivity
   → Can the runner reach the target? (security group, port 22, IP)
   → Does the SSH key work? (key as CI variable, ssh-add in before_script)
   → Is host_key_checking disabled for CI?

5. EXPLAIN your findings
   → "The first issue I see is... because... the fix is..."
   → "The second issue is in the Ansible config..."
   → "For connectivity, I'd check..."
```
