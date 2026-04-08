# Podman for GitLab Runners — What You Need to Know

> Anduril uses Podman, not Docker. GitLab runners use Podman as the executor. This is the runner-specific stuff.

---

## How GitLab Runner Uses Podman

GitLab Runner supports a "docker" executor that also works with Podman. You configure it to talk to the Podman socket instead of Docker's socket. Same API, different backend.

```toml
# /etc/gitlab-runner/config.toml

[[runners]]
  name = "ansible-runner"
  url = "https://gitlab.dev.internal"
  token = "runner-registration-token"
  executor = "docker"                    # yes, "docker" — not "podman"

  [runners.docker]
    image = "registry.local/rhel9:latest"       # default image for jobs
    host = "unix:///run/user/1000/podman/podman.sock"  # PODMAN socket, not Docker
    tls_verify = false
    privileged = false                           # rootless = no privileged needed
    volumes = ["/cache:/cache:Z"]                # :Z for SELinux relabeling
```

**Key points:**
- Executor is still called `docker` — GitLab doesn't have a separate "podman" executor
- `host` points to the Podman socket instead of `/var/run/docker.sock`
- `:Z` suffix on volume mounts for SELinux (RHEL enforces this)
- `privileged: false` — rootless Podman doesn't need it

---

## Setting Up Podman Socket (the runner needs this)

```bash
# Enable Podman socket for the user running the runner
systemctl --user enable --now podman.socket

# Verify the socket exists
ls -la /run/user/$(id -u)/podman/podman.sock
# Should show: srw-rw---- ... podman.sock

# For the runner to find it, set DOCKER_HOST
export DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock

# Verify it works
podman info    # should show "rootless: true"
```

**If the socket isn't there:**
1. Is Podman installed? `which podman`
2. Is the user lingering enabled? `loginctl enable-linger $USER` (keeps user services running after logout)
3. Is XDG_RUNTIME_DIR set? `echo $XDG_RUNTIME_DIR` should be `/run/user/$UID`

---

## Common Podman + Runner Problems

### "Cannot connect to the Docker daemon"
**Cause:** Runner is looking for Docker socket but Podman socket isn't enabled.
**Fix:** `systemctl --user enable --now podman.socket` + set DOCKER_HOST in config.toml

### "permission denied" on volume mount
**Cause:** SELinux blocks container access to host files.
**Fix:** Add `:Z` to volume mounts in config.toml: `volumes = ["/builds:/builds:Z"]`

### Image pull fails in air-gap
**Cause:** Runner tries docker.io but there's no internet.
**Fix:** Configure `/etc/containers/registries.conf`:
```ini
[registries.search]
registries = ['nexus.local:5000']

[registries.insecure]
registries = ['nexus.local:5000']    # if no TLS on Nexus

[registries.block]
registries = ['docker.io']           # explicitly block public
```

### Runner container can't resolve internal DNS
**Cause:** Container uses Google DNS (8.8.8.8) by default, can't reach internal services.
**Fix:** Set DNS in config.toml:
```toml
[runners.docker]
  dns = ["10.0.1.2"]    # internal DNS server IP
```

### "rootless" errors
**Cause:** Runner running as root but Podman configured rootless, or vice versa.
**Fix:** Ensure the runner service runs as the SAME USER that has the Podman socket. If runner runs as `gitlab-runner` user, that user needs `systemctl --user enable podman.socket`.

---

## Registries.conf vs registries.yaml

Don't confuse these — they're different tools:

| File | Tool | What it configures |
|------|------|--------------------|
| `/etc/containers/registries.conf` | **Podman** | Where Podman pulls images from. Affects podman pull, podman build, and the GitLab runner's docker executor |
| `/etc/rancher/rke2/registries.yaml` | **RKE2/containerd** | Where K8s containerd pulls images from. Affects pod image pulls inside the cluster |

If the runner uses Podman executor → `registries.conf` matters.
If pods run in RKE2 → `registries.yaml` matters.
Both can point to the same Nexus registry — they just configure different container runtimes.
