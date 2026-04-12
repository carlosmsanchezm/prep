# Drill 05: GitLab Runner + Pipeline Debug — Find ALL the Bugs

> **Scenario:** You're given a GitLab CI/CD project that uses Ansible to deploy Prometheus node_exporter (monitoring agent) to target hosts. The GitLab runner uses Podman executor. The environment is AIR-GAPPED — no internet. Everything is broken — pipeline bugs, runner config bugs, registry bugs, AND Ansible bugs. Find and fix every bug.
>
> **Rules:** No AI. No Google. Talk through your process aloud. Time yourself — 30 minutes.
> **This drill is GitLab/runner-heavy.** The recruiter said Andy will test: "GitLab runner having issues using ansible based deployment — how would you go about fixing it by looking at ansible configs, GitLab configs?"

---

## File 1: .gitlab-ci.yml

```yaml
stages:
  - validate
  - build
  - deploy
  - smoke_test

variables:
  ANSIBLE_HOST_KEY_CHECKING: "False"
  INVENTORY: inventory/monitoring.yml
  DEPLOY_KEY: $CI_DEPLOY_KEY                  # ← think about variable types

# YAML anchor — reusable template
.ansible_defaults: &ansible_base
  image: registry.local/ansible-runner:2.15
  tags:
    - devops
  before_script:
    - eval $(ssh-agent -s)
    - chmod 400 "$DEPLOY_KEY"
    - ssh-add "$DEPLOY_KEY"

validate:
  stage: lint                                  # ← look at stage name
  <<: *ansible_base
  script:
    - ansible-lint playbooks/deploy-monitoring.yml
    - yamllint .gitlab-ci.yml

build_image:
  stage: build
  image: quay.io/buildah/stable               # ← think about air-gap
  script:
    - buildah bud -t registry.local/node-exporter:$CI_COMMIT_SHORT_SHA .
    - buildah push registry.local/node-exporter:$CI_COMMIT_SHORT_SHA
  cache:
    paths:
      - build/output/                          # ← think about cache vs artifact

deploy:
  <<: *ansible_defaults                        # ← look at anchor name
  stage: deploy
  script:
    - ansible-playbook -i $INVENTORY playbooks/deploy-monitoring.yml
  needs: [build]                               # ← look at job name
  artifacts:
    paths:
      - ~/.pip/cache                           # ← think about cache vs artifact

smoke_test:
  stage: smoke_test
  image: registry.local/rhel9:latest
  script:
    - curl -f http://${TARGET_HOST}:9100/metrics
  needs: [deploy_monitoring]                   # ← look at job name
  when: manual                                 # ← think about automated pipeline
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

---

## File 2: /etc/gitlab-runner/config.toml (Runner Configuration)

```toml
concurrent = 0
check_interval = 3

[[runners]]
  name = "devops-runner"
  url = "https://gitlab.dev.internal"
  token = "xYz_runner_token_123"
  executor = "docker"

  [runners.docker]
    image = "registry.local/rhel9:latest"
    host = "unix:///var/run/docker.sock"
    privileged = false
    disable_entrypoint_overwrite = false
    volumes = ["/cache:/cache", "/builds:/builds"]
    shm_size = 0
    pull_policy = "always"

    [[runners.docker.services]]
      name = "docker:dind"
```

---

## File 3: /etc/containers/registries.conf (Podman Registry Config)

```toml
[registries.search]
registries = ['docker.io', 'registry.local']

[registries.insecure]
registries = []

[registries.block]
registries = ['registry.local']
```

---

## File 4: ansible.cfg

```ini
[defaults]
inventory = inventory/production.yml
remote_user = ec2-user
host_key_checking = False
roles_path = ./roles/galaxy
retry_files_enabled = True
timeout = 30

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False
```

---

## File 5: inventory/monitoring.yml

```yaml
monitoring_servers:
  hosts:
    monitor-01:
      ansible_host: 10.0.2.10
      ansible_user: ec2-user
      ansible_port: 2222
    monitor-02:
      ansible_host: 10.0.2.11
      ansible_user: ec2-user
      ansible_port: 2222
  vars:
    ansible_python_interpreter: /usr/bin/python3
    node_exporter_version: "1.7.0"
```

---

## File 6: playbooks/deploy-monitoring.yml

```yaml
---
- name: Deploy Prometheus node_exporter
  hosts: monitoring
  become: false

  tasks:
    - name: Create node_exporter user
      user:
        name: node_exporter
        shell: /sbin/nologin
        system: yes
        create_home: no

    - name: Copy node_exporter binary
      copy:
        src: files/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz
        dest: /tmp/node_exporter.tar.gz
        mode: 644

    - name: Extract node_exporter
      unarchive:
        src: /tmp/node_exporter.tar.gz
        dest: /usr/local/bin/
        remote_src: yes
        extra_opts: [--strip-components=1]

    - name: Deploy systemd unit file
      template:
        src: templates/node_exporter.service.j2
        dest: /etc/systemd/system/node_exporter.service
        mode: '0644'
      notify: Restart node-exporter

    - name: Reload systemd and enable service
      systemd:
        name: node_exporter
        daemon-reload: yes
        enabled: yes
        state: started

    - name: Open metrics port
      firewalld:
        port: 9100/tcp
        permanent: yes
        state: enabled
        immediate: yes

    - name: Verify node_exporter is responding
      uri:
        url: http://localhost:9100/metrics
        return_content: yes
      register: metrics_check
      with_items:
        - check1
        - check2
      retries: 3
      delay: 5
      until: metrics_check.status == 200

  handlers:
    - name: restart_node_exporter
      systemd:
        name: node_exporter
        state: restarted
        daemon_reload: yes
```

---

## Your Task

Find EVERY bug across all 6 files. Write:
1. Which file
2. Which line/section
3. What's wrong
4. What the fix is
5. WHY it's wrong (what would happen if you ran it as-is)

**Bugs found:**

```
File:
Line:
Bug:
Fix:
Why:

(repeat for each bug)
```

**How many bugs total?** (check against answers — there are 23)

**Debugging order:**
1. CHECK AIR-GAP FIRST — scan for internet assumptions
2. Runner config — is it even able to run jobs?
3. Registry config — can it pull images?
4. Pipeline — is .gitlab-ci.yml valid?
5. Ansible — are configs and playbook correct?
