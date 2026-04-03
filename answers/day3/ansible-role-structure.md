# Day 3 ANSWERS: Ansible Role Structure

## Directory Tree
```
roles/node-hardening/
├── tasks/
│   └── main.yml
├── handlers/
│   └── main.yml
├── defaults/
│   └── main.yml
├── templates/
│   ├── sshd_config.j2
│   └── banner.j2
└── files/
    └── (empty — no static files needed)
```

## tasks/main.yml
```yaml
---
- name: Disable swap
  command: swapoff -a
  changed_when: false

- name: Remove swap from fstab
  lineinfile:
    path: /etc/fstab
    regexp: '.*swap.*'
    state: absent

- name: Set kernel parameters
  sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    sysctl_file: /etc/sysctl.d/99-hardening.conf
    reload: yes
    state: present
  loop:
    - { key: 'net.bridge.bridge-nf-call-iptables', value: '1' }
    - { key: 'net.ipv4.ip_forward', value: '1' }

- name: Configure sshd
  template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    owner: root
    group: root
    mode: '0600'
    validate: '/usr/sbin/sshd -t -f %s'
  notify: restart sshd

- name: Enable and start auditd
  service:
    name: auditd
    state: started
    enabled: yes

- name: Set login banner
  template:
    src: banner.j2
    dest: /etc/issue
    owner: root
    group: root
    mode: '0644'
```

## handlers/main.yml
```yaml
---
- name: restart sshd
  service:
    name: sshd
    state: restarted
```

## defaults/main.yml
```yaml
---
sshd_permit_root_login: "no"
sshd_password_authentication: "no"
sshd_port: 22
login_banner_text: |
  ************************************************************
  WARNING: Authorized users only. All activity is monitored.
  ************************************************************
```

## templates/sshd_config.j2
```
# Managed by Ansible — do not edit manually
Port {{ sshd_port }}
PermitRootLogin {{ sshd_permit_root_login }}
PasswordAuthentication {{ sshd_password_authentication }}
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
```

## templates/banner.j2
```
{{ login_banner_text }}
```
