# Podman Cheatsheet — Memorize This

> **Anduril uses Podman (rootless), NOT Docker.** No daemon, no root required. Compatible with Docker CLI but fundamentally different architecture.

## Key Differences from Docker

| Feature | Docker | Podman |
|---------|--------|--------|
| Daemon | dockerd runs as root | No daemon — each command is a fork/exec |
| Root | Requires root (or docker group) | Rootless by default — runs as your user |
| Socket | /var/run/docker.sock | /run/user/$UID/podman/podman.sock |
| Compose | docker-compose | podman-compose (or podman compose with plugin) |
| Pods | No native pod concept | Native pods (like K8s pods — multiple containers share network) |
| Security | Shared daemon = shared attack surface | Process isolation — one container compromised ≠ all compromised |
| Systemd | Separate from systemd | Can generate systemd unit files from containers |

## Basic Commands (same as Docker, just swap the name)

```bash
# Pull image
podman pull registry.local/myapp:v1.0

# Run container
podman run -d --name myapp -p 8080:80 registry.local/myapp:v1.0

# Run rootless (default — no sudo needed)
podman run --rm -it registry.local/myapp:v1.0 /bin/bash

# List running
podman ps

# List all (including stopped)
podman ps -a

# Stop / Remove
podman stop myapp
podman rm myapp

# Logs
podman logs myapp
podman logs -f myapp            # follow

# Exec into running container
podman exec -it myapp /bin/bash

# Inspect
podman inspect myapp
```

## Building Images

```bash
# Build from Containerfile (same as Dockerfile)
podman build -t myapp:v1.0 .

# Build with specific file
podman build -t myapp:v1.0 -f Containerfile.prod .

# Multi-stage build (same syntax as Docker)
podman build --target production -t myapp:v1.0 .

# Tag for registry
podman tag myapp:v1.0 registry.local/myapp:v1.0

# Push to registry
podman push registry.local/myapp:v1.0

# Login to registry
podman login registry.local
```

## Rootless Podman (Critical for Anduril)

```bash
# Check if running rootless
podman info | grep rootless
# rootless: true

# Enable user socket (for GitLab runner integration)
systemctl --user enable --now podman.socket
# Creates: /run/user/$UID/podman/podman.sock

# Set DOCKER_HOST for compatibility
export DOCKER_HOST=unix:///run/user/$UID/podman/podman.sock

# User namespace mapping (/etc/subuid, /etc/subgid)
# Each user gets a range of UIDs for container isolation
cat /etc/subuid
# carlos:100000:65536

# If rootless fails with permission errors, check:
# 1. /etc/subuid and /etc/subgid have your user
# 2. User lingering is enabled: loginctl enable-linger $USER
# 3. XDG_RUNTIME_DIR is set: echo $XDG_RUNTIME_DIR
```

### Why Rootless Matters
- No daemon running as root = smaller attack surface
- Container compromise doesn't give root on host
- Meets DoD security requirements without Docker's privilege model
- Each user's containers are isolated from other users

## Podman Compose

```bash
# Install
pip3 install podman-compose

# Run compose file (same syntax as docker-compose.yml)
podman-compose up -d

# Stop
podman-compose down

# View logs
podman-compose logs -f

# Rebuild
podman-compose build
```

### Example compose file (podman-compose.yml):
```yaml
version: "3"
services:
  web:
    image: registry.local/webapp:latest
    ports:
      - "8080:80"
    volumes:
      - ./config:/etc/webapp:Z    # :Z for SELinux relabel
    environment:
      - DB_HOST=db
  db:
    image: registry.local/postgres:16
    volumes:
      - db-data:/var/lib/postgresql/data:Z
    environment:
      - POSTGRES_PASSWORD_FILE=/run/secrets/db_pass

volumes:
  db-data:
```

**Note the `:Z` suffix** — on RHEL with SELinux enforcing, volume mounts need `:Z` (private relabel) or `:z` (shared relabel) to work. Without it, containers can't read the mount.

## Podman Pods (Native K8s-like pods)

```bash
# Create a pod (shared network namespace)
podman pod create --name mypod -p 8080:80

# Run containers in the pod
podman run -d --pod mypod --name web registry.local/nginx:latest
podman run -d --pod mypod --name sidecar registry.local/fluentbit:latest

# List pods
podman pod list

# Stop/remove pod (stops all containers in it)
podman pod stop mypod
podman pod rm mypod

# Generate K8s YAML from a pod (useful for future K8s migration!)
podman generate kube mypod > mypod.yaml
```

## Registry Configuration

```bash
# Registries config (where Podman looks for images)
cat /etc/containers/registries.conf

# Example for air-gapped with local Nexus:
# [registries.search]
# registries = ['registry.local:5000']
#
# [registries.insecure]
# registries = ['registry.local:5000']    # if no TLS
#
# [registries.block]
# registries = ['docker.io']              # block public pulls

# For rootless, user-level config:
# ~/.config/containers/registries.conf
```

## Systemd Integration

```bash
# Generate systemd unit from running container
podman generate systemd --name myapp --new > ~/.config/systemd/user/myapp.service

# Enable and start
systemctl --user daemon-reload
systemctl --user enable --now myapp

# For root containers:
podman generate systemd --name myapp --new > /etc/systemd/system/myapp.service
systemctl daemon-reload
systemctl enable --now myapp
```

## GitLab Runner with Podman

```bash
# Register runner with docker executor but use Podman socket
gitlab-runner register \
  --executor docker \
  --docker-host "unix:///run/user/$UID/podman/podman.sock" \
  --docker-image "registry.local/alpine:latest"

# In config.toml:
# [runners.docker]
#   host = "unix:///run/user/1000/podman/podman.sock"
#   tls_verify = false
#   image = "registry.local/alpine:latest"
#   privileged = false
```

## Troubleshooting

```bash
# Container won't start — check logs
podman logs myapp

# Permission denied on volume mount (SELinux)
# Add :Z to volume mount, or:
setsebool -P container_manage_cgroup on

# Rootless networking issues
# Check slirp4netns (rootless network driver):
podman info | grep network

# Reset Podman (nuclear option)
podman system reset

# Prune unused images/containers
podman system prune -a
```

## Key Things to Know for Anduril Interview

1. **Rootless is the default** — they chose Podman specifically for this security model
2. **SELinux is enforcing** — volume mounts need `:Z` suffix
3. **No daemon** — if Podman process dies, nothing else is affected (unlike dockerd crash)
4. **Compose files work** — podman-compose reads docker-compose.yml syntax
5. **GitLab runners use Podman socket** — DOCKER_HOST points to podman.sock
6. **`podman generate kube`** — can export running pods to K8s YAML (bridge to future K8s migration)
