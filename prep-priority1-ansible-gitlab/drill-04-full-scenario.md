# Drill 04: Andy's Hands-On Scenario — Find ALL the Bugs

> **Scenario:** You're given a GitLab CI/CD project that uses Ansible to deploy a web server to a target host. The runner uses Podman executor. The environment is AIR-GAPPED — no internet access. Local GitLab, local Nexus registry, local DNS. Everything is broken — syntax bugs, config bugs, AND air-gap bugs. Find and fix every bug.
> 
> **Rules:** No AI. No Google. Talk through your process aloud. Time yourself — 30 minutes.
> **Think air-gap:** Every time you see something that assumes internet access, flag it.

---

## File 1: .gitlab-ci.yml

```yaml
stages:
  - lint
  - deploy
  - verify

variables:
  ANSIBLE_HOST_KEY_CHECKING: True
  INVENTORY: inventory/hosts.yml

lint:
  stage: lint
  image: python:3.11                    # ← look at this image source
  script:
    - pip install ansible-lint          # ← think about air-gap
    - ansible-lint playbooks/deploy-webserver.yml
  tag:
    - ansible

deploy:
  stage: deploy
  image: registry.local/rhel9:latest
  before_script:
    - eval $(ssh-agent -s)
    - ssh-add $SSH_PRIVATE_KEY
  script:
    - ansible-galaxy install -r requirements.yml    # ← think about air-gap
    - ansible-playbook -i $INVENTORY playbooks/deploy-webserver.yml
  only:
    - main
  rules:
    - if: $CI_COMMIT_BRANCH == main

verify:
  stage: verify
  script:
    - curl -f http://$TARGET_HOST
  needs: [deploy]
```

---

## File 2: ansible.cfg

```ini
[defaults]
inventory = inventory/production.yml
remote_user = ubuntu
host_key_checking = True
timeout = 10

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = True
```

---

## File 3: inventory/hosts.yml

```yaml
all:
  hosts:
    web-server:
      ansible_host: 10.0.1.50
      ansible_user: ec2-user
      ansible_ssh_private_key_file: /home/gitlab-runner/.ssh/deploy-key.pem
  vars:
    ansible_python_interpreter: /usr/bin/python
```

---

## File 4: playbooks/deploy-webserver.yml

```yaml
---
- name: Deploy web server
  hosts: web-servers
  roles:
    - role: geerlingguy.nginx          # ← think about air-gap
  tasks:
    - name: Install nginx
      yum:
        name: nginx
        state: installed

    - name: Download custom module
      get_url:
        url: https://example.com/modules/custom-module.tar.gz    # ← think about air-gap
        dest: /tmp/custom-module.tar.gz

    - name: Copy nginx config
      template:
        src: nginx.conf
        dest: /etc/nginx/nginx.conf
        mode: 644
      notify: Restart Nginx

    - name: Ensure nginx is running
      service:
        name: nginx
        state: running
        enabled: yes

    - name: Open HTTP port
      firewalld:
        port: 80
        permanent: yes
        state: enabled

    - name: Create web directory
      file:
        path: /var/www/html
        state: dir
        owner: nginx

    - name: Deploy index page
      copy:
        src: index.html
        dest: /var/www/html/index.html
        mode: 0644

  handlers:
    - name: restart nginx
      service:
        name: nginx
        state: restarted
```

---

## Your Task

Find EVERY bug across all 4 files. Write:
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

**How many bugs total?** (check against answers — there are 19: 15 config/syntax bugs + 4 air-gap bugs)
