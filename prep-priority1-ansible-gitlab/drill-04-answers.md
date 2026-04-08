# Drill 04 Answers — 19 Bugs (15 config/syntax + 4 air-gap)

---

## AIR-GAP BUGS (the ones that show you understand the environment)

**Air-Gap Bug 1:** `image: python:3.11` — pulls from Docker Hub
- No internet in air-gap → image pull fails → job never starts
- Fix: `image: registry.local/python:3.11` (pull from local Nexus registry)
- Why: Every image must come from the local registry. Nothing from docker.io, ghcr.io, or any public source.

**Air-Gap Bug 2:** `pip install ansible-lint` — tries to reach PyPI
- No internet → pip can't resolve pypi.org → install fails
- Fix: Either pre-install ansible-lint in the runner image, OR configure pip to use local Nexus PyPI mirror: `pip install --index-url https://nexus.local/repository/pypi/simple ansible-lint`
- Why: Package managers default to public repositories. In air-gap, every package manager must point to local mirrors.

**Air-Gap Bug 3:** `ansible-galaxy install -r requirements.yml` — tries to reach Galaxy
- No internet → can't download roles from galaxy.ansible.com
- Fix: Pre-download roles on the connected side, include them in the project repo under `roles/`, or use a local Galaxy proxy in Nexus. Remove the galaxy install line and reference local roles.
- Why: ansible-galaxy is like pip — defaults to public servers. Air-gap means pre-bundle everything.

**Air-Gap Bug 4:** `role: geerlingguy.nginx` + `get_url: https://example.com/...` in the playbook
- Both try to reach the internet. The role download fails (Galaxy), the get_url times out.
- Fix for role: Include the role source code directly in your project's `roles/` directory instead of referencing a Galaxy role. Fix for get_url: Host the file on Nexus or a local HTTP server: `url: https://nexus.local/repository/raw/modules/custom-module.tar.gz`
- Why: In air-gap, NOTHING downloads from external URLs. Every dependency must be pre-staged locally.

**How to spot air-gap bugs:** Read every line and ask: "Does this assume internet access?" Any URL, any public registry, any package manager command without a `--index-url` or local source is a bug in an air-gapped environment.

---

## .gitlab-ci.yml (6 config/syntax bugs)

**Bug 1:** `ANSIBLE_HOST_KEY_CHECKING: True` should be `"False"`
- True means SSH will fail on first connection (no known_hosts in CI)
- Fix: `ANSIBLE_HOST_KEY_CHECKING: "False"`
- Why: CI runners are ephemeral — no persistent known_hosts file

**Bug 2:** `tag:` should be `tags:` (plural)
- `tag:` is not a valid key — GitLab ignores it silently
- Fix: `tags:` with an `s`
- Why: Without correct tags, the job might run on any runner or none

**Bug 3:** `ssh-add $SSH_PRIVATE_KEY` — missing `chmod 400` and the variable is likely a File type
- SSH refuses keys with open permissions
- Fix: `chmod 400 "$SSH_PRIVATE_KEY"` then `ssh-add "$SSH_PRIVATE_KEY"` (with quotes)
- Why: Without chmod, SSH says "Permissions too open, key ignored"

**Bug 4:** Using BOTH `only:` and `rules:` — can't mix them
- GitLab will error or behave unpredictably
- Fix: Remove `only: - main` and keep only the `rules:` block
- Why: `only/except` is legacy, `rules` is modern — they conflict

**Bug 5:** `$CI_COMMIT_BRANCH == main` — `main` needs quotes
- Without quotes, `main` might be interpreted as a variable
- Fix: `if: $CI_COMMIT_BRANCH == "main"`
- Why: YAML parsing issue — unquoted strings in conditionals are unreliable

**Bug 6:** `verify` job uses `$TARGET_HOST` but it's never defined
- Variable is empty → curl fails
- Fix: Define `TARGET_HOST: "10.0.1.50"` in the variables section, or extract from inventory
- Why: Undefined variable = empty string = curl tries to reach nothing

---

## ansible.cfg (3 bugs)

**Bug 7:** `inventory = inventory/production.yml` but the actual file is `inventory/hosts.yml`
- Ansible won't find the inventory → "No hosts matched"
- Fix: `inventory = inventory/hosts.yml`
- Why: Path mismatch between ansible.cfg and the actual file

**Bug 8:** `host_key_checking = True` should be `False` for CI
- Same as Bug 1 — SSH fails on first connection
- Fix: `host_key_checking = False`
- Why: Duplicated from .gitlab-ci.yml, but ansible.cfg also needs it (belt and suspenders)

**Bug 9:** `become_ask_pass = True` → pipeline hangs forever
- CI has no terminal — can't type a password
- Fix: `become_ask_pass = False`
- Why: Pipeline will hang waiting for password input that never comes. Target host needs NOPASSWD sudo.

---

## inventory/hosts.yml (2 bugs)

**Bug 10:** `ansible_user: ec2-user` but ansible.cfg says `remote_user = ubuntu`
- Conflicting — which user is used? Inventory overrides ansible.cfg, so ec2-user wins
- But if the instance is Ubuntu, ec2-user doesn't exist → "Permission denied"
- Fix: Make them consistent. If RHEL: both should be `ec2-user`. If Ubuntu: both `ubuntu`.
- Why: User mismatch = SSH connects as wrong user

**Bug 11:** `ansible_python_interpreter: /usr/bin/python` — Python 2 path
- Modern RHEL/Ubuntu have Python 3 only — `/usr/bin/python` might not exist
- Fix: `ansible_python_interpreter: /usr/bin/python3`
- Why: Ansible needs Python on the target host. Wrong path = "Python not found" error

---

## playbooks/deploy-webserver.yml (4 bugs)

**Bug 12:** `hosts: web-servers` but inventory defines host group as `all` with host `web-server`
- No group called `web-servers` exists → "No hosts matched"
- Fix: `hosts: all` or `hosts: web-server` (the host name, not a group)
- Why: Ansible tries to match the host pattern to inventory — no match = nothing happens

**Bug 13:** `state: installed` should be `state: present`
- yum module doesn't accept "installed"
- Fix: `state: present`
- Why: Valid states are present, absent, latest

**Bug 14:** `mode: 644` should be `mode: '0644'`
- Integer 644 = octal 644 = wrong permissions
- Fix: `mode: '0644'` (quoted string)
- Why: YAML treats unquoted numbers as integers, not octal

**Bug 15:** `notify: Restart Nginx` but handler is `name: restart nginx` — case mismatch
- Handler never triggers → nginx doesn't restart after config change
- Fix: `notify: restart nginx` (match the handler name exactly)
- Why: Handler names are case-sensitive

### Additional issues (not counted in the 15 but worth noting):

- `service` module `state: running` should be `state: started`
- `firewalld` port `80` should be `80/tcp`
- `file` state `dir` should be `directory`
- Template src `nginx.conf` should probably be `nginx.conf.j2`
- Missing `immediate: yes` on firewalld (won't apply until reload)
- No `become: true` at play or task level — will fail on privileged operations

(If you found these extra ones — even better. Shows depth.)
