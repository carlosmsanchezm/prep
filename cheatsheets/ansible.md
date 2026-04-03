# Ansible Cheatsheet — Memorize This

## Playbook Structure

```yaml
---
- name: Descriptive playbook name
  hosts: all
  become: true
  vars:
    my_var: value
  tasks:
    - name: Task description
      module_name:
        param1: value1
        param2: value2
      notify: handler_name
      when: condition
      register: result

  handlers:
    - name: handler_name
      service:
        name: my_service
        state: restarted
```

## 15 Core Modules

### Package Management
```yaml
- name: Install packages
  apt:                    # or yum/dnf
    name:
      - nginx
      - curl
    state: present
    update_cache: yes
```

### File Operations
```yaml
- name: Copy file
  copy:
    src: local_file.conf
    dest: /etc/app/file.conf
    owner: root
    group: root
    mode: '0644'

- name: Template file (with variables)
  template:
    src: config.j2
    dest: /etc/app/config.conf
    owner: root
    mode: '0644'
  notify: restart app

- name: Create directory
  file:
    path: /opt/myapp
    state: directory
    owner: app_user
    mode: '0755'

- name: Create symlink
  file:
    src: /opt/myapp/current
    dest: /usr/local/bin/myapp
    state: link

- name: Add line to file
  lineinfile:
    path: /etc/sysctl.conf
    line: 'net.ipv4.ip_forward = 1'
    state: present

- name: Add block to file
  blockinfile:
    path: /etc/ssh/sshd_config
    block: |
      PermitRootLogin no
      PasswordAuthentication no
    marker: "# {mark} ANSIBLE MANAGED BLOCK"
```

### Services
```yaml
- name: Start and enable service
  service:
    name: nginx
    state: started
    enabled: yes

- name: Restart via systemd
  systemd:
    name: nginx
    state: restarted
    daemon_reload: yes
```

### Firewall
```yaml
- name: Open port
  firewalld:
    port: 6443/tcp
    permanent: yes
    immediate: yes
    state: enabled
```

### Users
```yaml
- name: Create user
  user:
    name: deploy
    shell: /bin/bash
    groups: wheel
    append: yes
    create_home: yes
```

### Commands
```yaml
- name: Run a command
  command: /usr/local/bin/rke2 server
  args:
    creates: /etc/rancher/rke2/config.yaml   # skip if file exists

- name: Run shell command (supports pipes)
  shell: cat /etc/os-release | grep NAME
  register: os_name
```

### Debugging
```yaml
- name: Print variable
  debug:
    msg: "The value is {{ my_var }}"

- name: Print registered output
  debug:
    var: result.stdout

- name: Fail with message
  fail:
    msg: "Required variable not set"
  when: my_var is not defined

- name: Assert condition
  assert:
    that:
      - my_var is defined
      - my_var | length > 0
    fail_msg: "my_var must be set"
```

### File Info
```yaml
- name: Check if file exists
  stat:
    path: /etc/app/config.conf
  register: config_file

- name: Do something if file exists
  debug:
    msg: "Config exists"
  when: config_file.stat.exists
```

## Key Patterns

### Handler (restart on config change)
```yaml
tasks:
  - name: Update config
    template:
      src: nginx.conf.j2
      dest: /etc/nginx/nginx.conf
    notify: restart nginx

handlers:
  - name: restart nginx
    service:
      name: nginx
      state: restarted
```

### Conditionals
```yaml
- name: Only on RedHat
  yum:
    name: httpd
  when: ansible_os_family == "RedHat"

- name: Only if variable is true
  command: /usr/local/bin/setup.sh
  when: run_setup | bool
```

### Register + Error Handling
```yaml
- name: Check service status
  command: systemctl status rke2-server
  register: rke2_status
  failed_when: false
  changed_when: false

- name: Start if not running
  service:
    name: rke2-server
    state: started
  when: rke2_status.rc != 0
```

### Loops
```yaml
- name: Create multiple users
  user:
    name: "{{ item }}"
    state: present
  loop:
    - alice
    - bob
    - charlie

- name: Install packages from list
  apt:
    name: "{{ item }}"
    state: present
  loop: "{{ required_packages }}"
```

### Ansible Vault
```bash
# Encrypt a file
ansible-vault encrypt vars/secrets.yml

# Edit encrypted file
ansible-vault edit vars/secrets.yml

# Run playbook with vault password
ansible-playbook site.yml --ask-vault-pass

# Use vault password file
ansible-playbook site.yml --vault-password-file ~/.vault_pass
```

## Role Directory Structure

```
roles/
└── my_role/
    ├── tasks/
    │   └── main.yml        # Required: task list
    ├── handlers/
    │   └── main.yml        # Handlers triggered by notify
    ├── defaults/
    │   └── main.yml        # Default variables (lowest precedence)
    ├── vars/
    │   └── main.yml        # Role variables (higher precedence)
    ├── templates/
    │   └── config.conf.j2  # Jinja2 templates
    ├── files/
    │   └── script.sh       # Static files to copy
    └── meta/
        └── main.yml        # Role dependencies
```

## Variable Precedence (low to high)
1. Role defaults
2. Inventory vars
3. Playbook vars
4. Role vars
5. Extra vars (`-e "var=value"`) — always wins

## Inventory Basics
```ini
[webservers]
web1 ansible_host=10.0.1.10
web2 ansible_host=10.0.1.11

[dbservers]
db1 ansible_host=10.0.2.10

[all:vars]
ansible_user=deploy
ansible_ssh_private_key_file=~/.ssh/id_rsa
```
