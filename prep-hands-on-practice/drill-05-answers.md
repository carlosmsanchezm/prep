# Drill 05 Answers — 23 Bugs (GitLab/Runner Heavy)

---

## AIR-GAP BUGS (check these FIRST)

**Air-Gap Bug 1:** `image: quay.io/buildah/stable` — pulls from public Quay registry
- No internet in air-gap → image pull fails → build job never starts
- Fix: `image: registry.local/buildah:stable`
- Why: Every image must come from the local registry. quay.io is a public registry — unreachable.

**Air-Gap Bug 2:** `pull_policy = "always"` in config.toml — forces fresh pull every job
- In air-gap, even local registry images should use `if-not-present` to avoid unnecessary pulls and potential failures if Nexus is temporarily unreachable
- Fix: `pull_policy = "if-not-present"`
- Why: `always` means the runner tries to pull the image fresh every time. If the local registry is slow or briefly down, every job fails. `if-not-present` uses the cached image if available.

**Air-Gap Bug 3:** `registries.search` includes `docker.io`
- Podman will try docker.io first when pulling unqualified images → times out in air-gap
- Fix: `registries = ['registry.local']` (remove docker.io entirely)
- Why: Search order matters. If someone runs `podman pull rhel9:latest` without a full path, Podman tries docker.io first, hangs, then eventually tries registry.local. Remove public registries from search.

---

## .gitlab-ci.yml (8 bugs)

**Bug 1:** `stage: lint` but stages defines `validate` — stage name mismatch
- The validate job says `stage: lint` but the pipeline only defines `validate`, `build`, `deploy`, `smoke_test`
- Fix: `stage: validate`
- Why: Job references a stage that doesn't exist → GitLab rejects the pipeline config or the job is ignored

**Bug 2:** YAML anchor defined as `&ansible_base` but referenced as `*ansible_defaults` in deploy job
- `<<: *ansible_defaults` references an anchor that doesn't exist — the defined anchor is `&ansible_base`
- Fix: Either change the definition to `&ansible_defaults` or change the reference to `<<: *ansible_base`
- Why: YAML error — undefined anchor. The deploy job won't inherit the template → no image, no tags, no SSH setup

**Bug 3:** `needs: [build]` but the job is named `build_image` — job name mismatch
- `needs:` references a job called `build` but the actual job name is `build_image`
- Fix: `needs: [build_image]`
- Why: Pipeline config error — GitLab says "build: unknown job" and rejects the pipeline

**Bug 4:** `needs: [deploy_monitoring]` in smoke_test but the job is named `deploy` — job name mismatch
- Same pattern as Bug 3 — wrong job name in `needs:`
- Fix: `needs: [deploy]`
- Why: Pipeline config error — unknown job reference

**Bug 5:** Cache used for build output (should be artifact)
- `cache: paths: - build/output/` on the build job — cache is for dependencies between pipeline RUNS, artifacts are for passing files between STAGES in the same run
- Fix: Change to `artifacts: paths: - build/output/` with `expire_in: 1 hour`
- Why: Cache is best-effort and may not be available. If the deploy job needs the build output, it should be an artifact. Cache is for things like node_modules, pip cache — things that speed up repeated runs.

**Bug 6:** Artifact used for pip cache (should be cache)
- `artifacts: paths: - ~/.pip/cache` on the deploy job — pip cache should be a CACHE (persists between runs), not an artifact (passed between stages)
- Fix: Change to `cache: key: pip-cache` with `paths: - .pip-cache/` and set `PIP_CACHE_DIR: .pip-cache` in variables
- Why: Artifacts are downloaded by the next stage and stored in GitLab. Pip cache is only useful for speeding up repeated runs — that's what cache is for. Also, `~` paths don't work reliably in artifacts.

**Bug 7:** `when: manual` on smoke_test blocks automated verification
- After deploy succeeds, the smoke test requires someone to click "play" in the UI
- Fix: Remove `when: manual` — or if manual approval is needed, put it on the DEPLOY job, not the verification
- Why: In a CI/CD pipeline, verification after deploy should be automatic. Manual gates should be BEFORE deploy (approve deployment), not after (verify it worked).

**Bug 8:** `$CI_DEPLOY_KEY` may be a Protected variable — empty on non-protected branches
- `DEPLOY_KEY: $CI_DEPLOY_KEY` — if CI_DEPLOY_KEY is set as "Protected" in GitLab settings, it's only available on protected branches (main/production)
- Fix: Either make the variable available to all branches, or ensure the deploy job only runs on protected branches (which the rules already do — but validate/lint jobs also use the anchor with SSH setup, so they'd fail on feature branches)
- Why: On a feature branch, `$CI_DEPLOY_KEY` is empty → `chmod 400 ""` fails → `ssh-add` fails → job fails with cryptic error

---

## config.toml — Runner Configuration (4 bugs)

**Bug 9:** `concurrent = 0` — runner won't execute ANY jobs
- Zero concurrent jobs means the runner accepts zero jobs at a time
- Fix: `concurrent = 1` (or higher for parallel jobs)
- Why: Runner registers with GitLab but never picks up jobs. Jobs stuck in "pending" forever.

**Bug 10:** `executor = "docker"` but using Podman — wrong executor
- Anduril uses Podman, not Docker. The executor should reflect this.
- Fix: `executor = "docker"` is actually correct for Podman (Podman uses Docker-compatible API) — BUT the `host` must point to the Podman socket, not Docker socket. This leads to Bug 11.
- Why: The executor name stays "docker" even with Podman because the GitLab runner uses the Docker API. The fix is in the socket path.

**Bug 11:** `host = "unix:///var/run/docker.sock"` — Docker socket, not Podman
- Podman socket is at a different path. `/var/run/docker.sock` doesn't exist if Docker isn't installed.
- Fix: For rootless: `host = "unix:///run/user/1000/podman/podman.sock"`. For root: `host = "unix:///run/podman/podman.sock"`
- Why: Runner tries to connect to Docker daemon → "Cannot connect to the Docker daemon" error. Podman's socket is in a different location.

**Bug 12:** Volume mounts missing `:Z` for SELinux
- `volumes = ["/cache:/cache", "/builds:/builds"]` — on RHEL with SELinux enforcing, containers can't access these without relabeling
- Fix: `volumes = ["/cache:/cache:Z", "/builds:/builds:Z"]`
- Why: SELinux blocks the container from reading/writing the mounted volumes → "Permission denied" on cache or build directories

**Bug 13:** `docker:dind` service — unnecessary and won't work with Podman
- Docker-in-Docker is a Docker concept. Podman doesn't need or support it.
- Fix: Remove the entire `[[runners.docker.services]]` block
- Why: The runner tries to start a `docker:dind` sidecar container that doesn't exist in the local registry and isn't needed for Podman builds

---

## registries.conf (3 bugs — including Air-Gap Bug 3 above)

**Bug 14:** `registries.block` blocks `registry.local` — blocks the LOCAL registry
- This is backwards — should block public registries, not the local one
- Fix: `registries = ['docker.io', 'quay.io', 'gcr.io']` (block public registries)
- Why: Blocks the only registry that works in air-gap. Every image pull fails.

**Bug 15:** `registries.insecure` is empty but local Nexus may use self-signed certs
- If Nexus uses self-signed or internal CA certs, Podman won't trust them
- Fix: `registries = ['registry.local']` (allow insecure/self-signed for local registry) — or better: add the internal CA cert to the system trust store
- Why: `podman pull registry.local/rhel9:latest` fails with "x509: certificate signed by unknown authority"

(Air-Gap Bug 3 is also in this file — docker.io in search registries)

---

## ansible.cfg (2 bugs)

**Bug 16:** `inventory = inventory/production.yml` but actual inventory is `inventory/monitoring.yml`
- Path mismatch — Ansible won't find the right hosts
- Fix: `inventory = inventory/monitoring.yml`
- Why: Ansible uses the wrong inventory file → "No hosts matched" or it runs against production instead of monitoring servers

**Bug 17:** `roles_path = ./roles/galaxy` — roles are likely in `./roles`
- Pointing to a `galaxy` subdirectory that probably doesn't exist
- Fix: `roles_path = ./roles`
- Why: Ansible can't find any roles → "role not found" errors

**Bonus (not a bug but bad practice):** `retry_files_enabled = True` in CI
- Creates `.retry` files in the project directory on failure — clutters the workspace
- Fix: `retry_files_enabled = False`
- Why: In CI, retry files are useless (ephemeral environment) and can cause artifact/cache noise

---

## inventory/monitoring.yml (2 bugs)

**Bug 18:** Group name is `monitoring_servers` but playbook uses `hosts: monitoring` — group name mismatch
- Playbook can't find the host group → "No hosts matched"
- Fix: Either change inventory group to `monitoring:` or change playbook to `hosts: monitoring_servers`
- Why: Ansible matches host patterns against inventory groups. No match = nothing runs.

**Bug 19:** `ansible_port: 2222` — non-standard SSH port, is this intentional?
- If the target hosts use standard SSH (port 22), this will fail → "Connection refused"
- Fix: Remove `ansible_port: 2222` (defaults to 22) or verify the hosts actually use port 2222
- Why: SSH connects to wrong port → timeout or connection refused. This is a common mistake when copying inventory templates.

---

## playbooks/deploy-monitoring.yml (4 bugs)

**Bug 20:** `become: false` at play level — tasks that need root will fail
- Creating system users, copying to /usr/local/bin, writing to /etc/systemd — all need root
- Fix: `become: true`
- Why: "Permission denied" on every task that touches system directories or creates system users

**Bug 21:** `mode: 644` should be `mode: '0644'` — unquoted octal
- Same pattern as drill-04 — YAML treats unquoted 644 as integer, not octal permissions
- Fix: `mode: '0644'`
- Why: File ends up with wrong permissions. Could be a security issue or break execution.

**Bug 22:** `notify: Restart node-exporter` but handler is named `restart_node_exporter` — name mismatch
- Notify uses hyphens, handler uses underscores — they don't match
- Fix: Make them identical: `notify: restart_node_exporter` (match the handler name)
- Why: Handler never fires → systemd doesn't restart after config change → old config still running

**Bug 23:** `systemd` module uses `daemon-reload` (hyphen) instead of `daemon_reload` (underscore)
- Ansible module parameters use underscores, not hyphens
- Fix: `daemon_reload: yes`
- Why: Ansible ignores the unknown parameter → systemd doesn't pick up the new service file → `systemctl start node_exporter` says "Unit not found"

---

## Summary

| File | Bug Count | Key Issues |
|------|-----------|------------|
| .gitlab-ci.yml | 8 | Anchor mismatch, stage mismatch, needs mismatch, cache/artifact swap, manual gate, protected var |
| config.toml | 5 | concurrent=0, Docker socket, missing :Z, pull_policy, dind service |
| registries.conf | 3 | Blocks local registry, includes docker.io, missing insecure |
| ansible.cfg | 2 | Inventory path, roles_path |
| inventory | 2 | Group name mismatch, wrong SSH port |
| playbook | 4 | become:false, mode unquoted, handler name mismatch, hyphen vs underscore |
| **Total** | **23** + 1 bonus | |

## How to spot these bugs — the debugging mindset

1. **Air-gap first:** Any URL, public registry, or `always` pull = broken
2. **Runner config:** Can the runner even run? (concurrent > 0, correct socket, SELinux volumes)
3. **Registry config:** Can images be pulled? (right registries searched, right ones blocked, certs trusted)
4. **Pipeline syntax:** Do stage names, job names, anchor names all match? Are artifacts and caches used correctly?
5. **Ansible config:** Do paths match reality? (inventory file, roles directory)
6. **Ansible code:** Are module parameters spelled correctly? (underscores, not hyphens). Do handler names match exactly?
