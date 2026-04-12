# Drill 06: Read the Logs — Diagnose the Failure

> **Scenario:** You're troubleshooting a GitLab CI/CD pipeline that uses Ansible to deploy to target hosts in an air-gapped environment. Andy shows you log output from various failures. For each one: what's wrong, why, and how do you fix it?
>
> **Rules:** No AI. No Google. Talk through your reasoning aloud. Time yourself — 25 minutes.
> **Think like you're SSHed into the machine or reading the GitLab job log in the UI.**

---

## Failure 1: Pipeline Job Log — "deploy" stage

The developer pushed to main. The lint job passed. The deploy job shows this:

```
Running with gitlab-runner 16.8.0 (c72a09b6)
  on devops-runner xYz_token_123
Preparing the "docker" executor
Using Docker executor with image registry.local/ansible-runner:2.15 ...
Pulling docker image registry.local/ansible-runner:2.15 ...
WARNING: Failed to pull image with policy "always": Error response from daemon:
  Get "https://registry.local/v2/": x509: certificate signed by unknown authority
ERROR: Job failed: failed to pull image "registry.local/ansible-runner:2.15"
  with specified policies [always]: Error response from daemon:
  Get "https://registry.local/v2/": x509: certificate signed by unknown authority (exec.go:78:0s)
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 2: Pipeline Job Log — "deploy" stage (different error)

After fixing Failure 1, the deploy job now shows this:

```
Running with gitlab-runner 16.8.0 (c72a09b6)
  on devops-runner xYz_token_123
Preparing the "docker" executor
Using Docker executor with image registry.local/ansible-runner:2.15 ...
Pulling docker image registry.local/ansible-runner:2.15 ...
Using docker image sha256:a3b8f...2d1e for registry.local/ansible-runner:2.15 ...
Preparing environment
Running on runner-xyz-project-1-concurrent-0 via devops-runner...
Getting source from Git repository
Fetching changes with git depth set to 20...
Initialized empty Git repository in /builds/devops/monitoring-deploy/.git/
Created fresh repository.
Checking out abc12345 as detached HEAD (ref is main)...
Skipping Git submodules setup
Executing "step_script" stage of the job script
$ eval $(ssh-agent -s)
Agent pid 34
$ chmod 400 "$SSH_PRIVATE_KEY"
chmod: cannot access '': No such file or directory
ERROR: Job failed: exit code 1
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 3: Pipeline Job Log — "deploy" stage (Ansible output)

SSH is now working. The Ansible playbook starts but fails:

```
$ ansible-playbook -i inventory/monitoring.yml playbooks/deploy-monitoring.yml

PLAY [Deploy Prometheus node_exporter] *****************************************

TASK [Gathering Facts] *********************************************************
fatal: [monitor-01]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect
to the host via ssh: ssh: connect to host 10.0.2.10 port 22: Connection timed out",
"unreachable": true}
fatal: [monitor-02]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect
to the host via ssh: ssh: connect to host 10.0.2.11 port 22: Connection timed out",
"unreachable": true}

PLAY RECAP *********************************************************************
monitor-01                 : ok=0    changed=0    unreachable=1    failed=0    skipped=0
monitor-02                 : ok=0    changed=0    unreachable=1    failed=0    skipped=0
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 4: Pipeline Job Log — "deploy" stage (Ansible task failure)

After fixing the connection issue, the playbook runs but fails mid-way:

```
$ ansible-playbook -i inventory/monitoring.yml playbooks/deploy-monitoring.yml

PLAY [Deploy Prometheus node_exporter] *****************************************

TASK [Gathering Facts] *********************************************************
ok: [monitor-01]
ok: [monitor-02]

TASK [Create node_exporter user] ***********************************************
fatal: [monitor-01]: FAILED! => {"changed": false, "msg": "useradd: Permission denied.\n
useradd: cannot lock /etc/passwd; try again later.\n", "name": "node_exporter",
"rc": 1}
fatal: [monitor-02]: FAILED! => {"changed": false, "msg": "useradd: Permission denied.\n
useradd: cannot lock /etc/passwd; try again later.\n", "name": "node_exporter",
"rc": 1}

PLAY RECAP *********************************************************************
monitor-01                 : ok=1    changed=0    unreachable=0    failed=1    skipped=0
monitor-02                 : ok=1    changed=0    unreachable=0    failed=1    skipped=0
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 5: GitLab Runner Registration Log

You SSH into the runner host. The runner isn't picking up jobs. You check the logs:

```
$ sudo journalctl -u gitlab-runner -n 30

Apr 12 09:15:01 runner01 gitlab-runner[1234]: WARNING: Failed to process runner
  builds=0 error="connecting to Docker: Cannot connect to the Docker daemon at
  unix:///var/run/docker.sock. Is the docker daemon running?" runner=xYz_token
Apr 12 09:15:04 runner01 gitlab-runner[1234]: WARNING: Failed to process runner
  builds=0 error="connecting to Docker: Cannot connect to the Docker daemon at
  unix:///var/run/docker.sock. Is the docker daemon running?" runner=xYz_token
Apr 12 09:15:07 runner01 gitlab-runner[1234]: WARNING: Failed to process runner
  builds=0 error="connecting to Docker: Cannot connect to the Docker daemon at
  unix:///var/run/docker.sock. Is the docker daemon running?" runner=xYz_token
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 6: Podman Image Pull Error

You're on the runner host trying to pull an image manually to debug:

```
$ podman pull registry.local/ansible-runner:2.15
Trying to pull registry.local/ansible-runner:2.15...
Error: initializing source docker://registry.local/ansible-runner:2.15:
  pinging container registry registry.local: Get "https://registry.local/v2/":
  dial tcp: lookup registry.local on 10.0.0.2:53: no such host
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 7: Ansible Playbook — Module Error

The playbook continues but hits a different error:

```
TASK [Deploy systemd unit file] ************************************************
ok: [monitor-01]
ok: [monitor-02]

TASK [Reload systemd and enable service] ***************************************
fatal: [monitor-01]: FAILED! => {"changed": false, "msg": "Unsupported parameters for
(systemd) module: daemon-reload. Supported parameters include: daemon_reexec,
daemon_reload, enabled, force, masked, name, no_block, scope, state"}
fatal: [monitor-02]: FAILED! => {"changed": false, "msg": "Unsupported parameters for
(systemd) module: daemon-reload. Supported parameters include: daemon_reexec,
daemon_reload, enabled, force, masked, name, no_block, scope, state"}
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 8: systemd Service Log on Target Host

You SSH into monitor-01 to check why node_exporter isn't starting:

```
$ systemctl status node_exporter
● node_exporter.service - Prometheus Node Exporter
     Loaded: loaded (/etc/systemd/system/node_exporter.service; enabled; vendor preset: disabled)
     Active: failed (Result: exit-code) since Sat 2026-04-12 09:30:15 UTC; 2min ago
    Process: 5678 ExecStart=/usr/local/bin/node_exporter (code=exited, status=203/EXEC)
   Main PID: 5678 (code=exited, status=203/EXEC)

Apr 12 09:30:15 monitor-01 systemd[1]: Started Prometheus Node Exporter.
Apr 12 09:30:15 monitor-01 systemd[1]: node_exporter.service: Main process exited, code=exited, status=203/EXEC
Apr 12 09:30:15 monitor-01 systemd[1]: node_exporter.service: Failed with result 'exit-code'.

$ ls -la /usr/local/bin/node_exporter
-rw-r--r--. 1 root root 19853432 Apr 12 09:25 /usr/local/bin/node_exporter
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Failure 9: Pipeline Job Log — Cache/Artifact Issue

The lint job passes. The deploy job fails because it can't find files:

```
Running with gitlab-runner 16.8.0 (c72a09b6)
  on devops-runner xYz_token_123
Preparing the "docker" executor
Using Docker executor with image registry.local/ansible-runner:2.15 ...
Preparing environment
Running on runner-xyz-project-1-concurrent-0 via devops-runner...
Getting source from Git repository
Fetching changes with git depth set to 20...
Reinitialized existing Git repository in /builds/devops/monitoring-deploy/.git/
Checking out abc12345 as detached HEAD (ref is main)...
Skipping Git submodules setup
Restoring cache
Checking cache for pip-deps-main...
No URL provided, cache is not downloaded from shared cache server.
WARNING: Cache file does not exist.
Failed to extract cache
Executing "step_script" stage of the job script
$ ansible-playbook -i inventory/monitoring.yml playbooks/deploy-monitoring.yml
ERROR! the role 'monitoring_common' was not found in
/builds/devops/monitoring-deploy/roles/galaxy:
/builds/devops/monitoring-deploy/roles

If you are using a role file, ensure that the role name is exact.
The error appears to be in '/builds/devops/monitoring-deploy/playbooks/deploy-monitoring.yml'

ERROR: Job failed: exit code 1
```

**What's wrong? What's the fix? Why?** (There are TWO issues in this log.)

```
Diagnosis:
Fix:
Why:
```

---

## Failure 10: Pipeline Job Log — SELinux Volume Mount

The runner picks up the job but immediately fails with a permission error:

```
Running with gitlab-runner 16.8.0 (c72a09b6)
  on devops-runner xYz_token_123
Preparing the "docker" executor
Using Docker executor with image registry.local/ansible-runner:2.15 ...
Pulling docker image registry.local/ansible-runner:2.15 ...
Using docker image sha256:a3b8f...2d1e for registry.local/ansible-runner:2.15 ...
Preparing environment
ERROR: Failed to create container volume for
  /builds:/builds: error while creating mount source path '/builds':
  mkdir /builds: permission denied
ERROR: Job failed: prepare environment: Error response from daemon (exec.go:78:0s)
```

**What's wrong? What's the fix? Why?**

```
Diagnosis:
Fix:
Why:
```

---

## Your Task

For each failure:
1. **Read the log carefully** — what is the actual error message?
2. **Diagnose** — what component is failing and why?
3. **Fix** — what specific change fixes it?
4. **Explain** — why does this fix work? What was the root cause?

**Total: 10 failures to diagnose (11 issues — Failure 9 has two)**

**Debugging order hint:**
- Failures 1, 6, 10 = infrastructure/registry/runner issues (check FIRST)
- Failures 2, 5 = pipeline/runner config issues
- Failures 3, 4, 7 = Ansible connection and code issues
- Failure 8 = target host issue (systemd)
- Failure 9 = cache/artifact + Ansible config issue
