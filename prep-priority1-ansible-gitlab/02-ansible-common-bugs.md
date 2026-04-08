# 15 Most Common Ansible Bugs — How to Spot Them

> Taylor's exercise will have bugs like these. Know each pattern so you can spot them instantly.

---

## Bug 1: Wrong module state value

```yaml
# BAD — "installed" is not a valid state for apt/yum
- name: Install nginx
  apt:
    name: nginx
    state: installed

# GOOD — use "present", "absent", or "latest"
- name: Install nginx
  apt:
    name: nginx
    state: present
```

**How to spot:** Look at every `state:` value. Common wrong ones: `installed` (use `present`), `running` (use `started`), `dir` (use `directory`).

---

## Bug 2: File mode as integer instead of string

```yaml
# BAD — 644 is interpreted as OCTAL 644 (decimal 420) — wrong permissions
- name: Copy config
  copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
    mode: 644

# GOOD — quote it as a string
- name: Copy config
  copy:
    src: nginx.conf
    dest: /etc/nginx/nginx.conf
    mode: '0644'
```

**How to spot:** Every `mode:` value should be a quoted string starting with `0`.

---

## Bug 3: Handler name mismatch (case-sensitive)

```yaml
# BAD — notify says "Restart Nginx" but handler is "restart nginx" — CASE SENSITIVE
tasks:
  - name: Update config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: Restart Nginx

handlers:
  - name: restart nginx
    service:
      name: nginx
      state: restarted

# GOOD — names must match exactly
    notify: restart nginx
```

**How to spot:** Compare every `notify:` string to the handler `name:` — they must be IDENTICAL, including case.

---

## Bug 4: Missing `become: true` for root operations

```yaml
# BAD — installing packages requires root, but no become
- name: Install packages
  apt:
    name: nginx
    state: present

# GOOD — add become at play or task level
- name: Install packages
  apt:
    name: nginx
    state: present
  become: true
```

**How to spot:** Any task that modifies system files, installs packages, manages services, or changes ownership needs `become: true` (either on the task or at the play level).

---

## Bug 5: Using `=` instead of `==` in when conditional

```yaml
# BAD — single = is assignment, not comparison
- name: Install on RedHat
  yum:
    name: httpd
  when: ansible_os_family = "RedHat"

# GOOD — double == for comparison
  when: ansible_os_family == "RedHat"
```

**How to spot:** Every `when:` condition using `=` should be `==`.

---

## Bug 6: `with_items` instead of `loop` (deprecated)

```yaml
# BAD — with_items still works but is deprecated
- name: Create users
  user:
    name: "{{ item }}"
  with_items:
    - alice
    - bob

# GOOD — use loop
- name: Create users
  user:
    name: "{{ item }}"
  loop:
    - alice
    - bob
```

**How to spot:** Any `with_items:` should be `loop:`. Not a hard error but shows you know modern Ansible.

---

## Bug 7: YAML indentation error

```yaml
# BAD — tasks should be indented under the play, not at root level
- name: My playbook
  hosts: all
  tasks:
  - name: Install nginx
    apt:
      name: nginx

# GOOD — tasks list is indented properly
- name: My playbook
  hosts: all
  tasks:
    - name: Install nginx
      apt:
        name: nginx
```

**How to spot:** YAML is whitespace-sensitive. Inconsistent indentation breaks parsing. Use 2-space indent consistently.

---

## Bug 8: Using `command` when a module exists

```yaml
# BAD — using shell to install packages
- name: Install nginx
  command: apt-get install -y nginx

# GOOD — use the apt module (idempotent, handles errors)
- name: Install nginx
  apt:
    name: nginx
    state: present
```

**How to spot:** `command:` or `shell:` for something a module can do. Modules are idempotent; raw commands are not.

---

## Bug 9: Variable undefined — missing default

```yaml
# BAD — if my_port is not defined anywhere, this crashes
- name: Configure port
  template:
    src: config.j2
    dest: /etc/app/config.yml
  # Inside template: port: {{ my_port }}

# GOOD — provide a default
  # Inside template: port: {{ my_port | default(8080) }}
```

**How to spot:** Any `{{ variable }}` in a template or task — is it defined in defaults, vars, or inventory? If not, it'll crash with "undefined variable."

---

## Bug 10: `append: false` on user group membership

```yaml
# BAD — append: false REPLACES all existing groups
- name: Add user to docker group
  user:
    name: deploy
    groups: docker
    append: false

# GOOD — append: true ADDS to existing groups
    append: true
```

**How to spot:** `user` module with `groups:` — check `append`. false = destructive.

---

## Bug 11: Firewalld port missing /tcp or /udp

```yaml
# BAD — port needs protocol suffix
- name: Open HTTP
  firewalld:
    port: 80
    permanent: yes
    state: enabled

# GOOD — include /tcp
    port: 80/tcp
```

**How to spot:** Every `firewalld` port must have `/tcp` or `/udp`.

---

## Bug 12: `file` module state `dir` instead of `directory`

```yaml
# BAD
- name: Create directory
  file:
    path: /opt/app
    state: dir

# GOOD
    state: directory
```

**How to spot:** `file` module uses `directory`, `file`, `link`, `absent` — NOT `dir`.

---

## Bug 13: Template file missing `.j2` extension or wrong src path

```yaml
# BAD — template module looks in templates/ directory by default
- name: Deploy config
  template:
    src: config.yaml          # should be config.yaml.j2 if it has variables
    dest: /etc/app/config.yaml

# GOOD
    src: config.yaml.j2       # .j2 tells Ansible to process Jinja2 syntax
```

**How to spot:** `template` module src files should end in `.j2`. If the file has `{{ }}` syntax, it's a template.

---

## Bug 14: `register` + `failed_when: false` missing `changed_when`

```yaml
# BAD — this will ALWAYS show "changed" even when checking status
- name: Check if service running
  command: systemctl is-active nginx
  register: result

# GOOD — mark it as never-changing (it's just a check)
- name: Check if service running
  command: systemctl is-active nginx
  register: result
  changed_when: false
  failed_when: false        # don't fail if service is stopped
```

**How to spot:** Any `command`/`shell` task used for CHECKING (not changing) should have `changed_when: false`.

---

## Bug 15: Missing `immediate: yes` on firewalld

```yaml
# BAD — permanent: yes saves the rule for reboot but doesn't apply NOW
- name: Open port
  firewalld:
    port: 8080/tcp
    permanent: yes
    state: enabled

# GOOD — add immediate: yes to apply right now
    permanent: yes
    immediate: yes
    state: enabled
```

**How to spot:** `firewalld` with `permanent: yes` but missing `immediate: yes` — rule saves but doesn't apply until firewall reload.

---

## Quick Scan Checklist

When Taylor shows you a playbook, scan for these in order:
1. [ ] All `state:` values valid? (present/absent/started/stopped/directory/link)
2. [ ] All `mode:` values quoted strings? ('0644', '0755')
3. [ ] All `notify:` names match handler names exactly?
4. [ ] `become: true` present for privileged tasks?
5. [ ] All `when:` conditions use `==` not `=`?
6. [ ] `loop:` instead of `with_items:`?
7. [ ] Indentation consistent (2 spaces)?
8. [ ] Modules used instead of raw commands where possible?
9. [ ] Variables defined or have defaults?
10. [ ] `append: true` for user group additions?
11. [ ] Firewalld ports have `/tcp` or `/udp`?
12. [ ] `file` state is `directory` not `dir`?
13. [ ] Template files end in `.j2`?
14. [ ] Check commands have `changed_when: false`?
15. [ ] Firewalld has `immediate: yes` with `permanent: yes`?
