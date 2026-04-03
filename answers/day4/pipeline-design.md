# Day 4 ANSWERS: Pipeline Design

---

## Connected Side Pipeline

**Stage 1: Build**
- What: Compile C++/Rust code, run unit tests, build container image
- Tool: GitLab CI with Docker/buildah
- Output: Container image tagged with commit SHA (e.g., registry.corp/app:abc123f)

**Stage 2: Scan**
- What: Scan image for CVEs. FAIL pipeline on HIGH/CRITICAL findings.
- Tool: Trivy (or Grype)
- Why here: scan BEFORE transfer — never push unvalidated code to classified network

**Stage 3: Bundle**
- What: Package image + dependencies into a single, versioned, content-addressed archive
- Tool: Zarf (or custom tar + sha256 manifest)
- Output: bundle-v2.3.1.tar.zst + manifest.sha256
- Key: include ALL dependencies (base images, sidecars, configs)

**Stage 4: Stage for Transfer**
- What: Push bundle to diode staging directory + write transfer manifest
- Tool: Script that copies to diode input directory
- Manifest includes: bundle filename, SHA256 hash, timestamp, source commit

## Transfer Mechanism

- **How:** One-way diode — data flows from connected to air-gapped only
- **Format:** Content-addressed archive (tar.zst or tar.gz) + manifest file
- **Validation:** SHA256 checksum generated on connected side, verified on air-gap side
  - If checksum mismatch → reject bundle, alert, re-transfer
  - Diode is one-way so there's no ack — air-gap side validates independently

## Air-Gap Side Pipeline

**Stage 1: Receive + Validate**
- What: Pick up bundle from diode output. Validate checksum against manifest.
- Tool: Cron job or systemd watcher + bash validation script
- Reject if: checksum mismatch, missing files, corrupt archive

**Stage 2: Unpack + Import**
- What: Extract images from bundle, load into local Harbor registry
- Tool: docker load / skopeo copy / zarf deploy
- Also push Helm charts to local chart museum if applicable

**Stage 3: Deploy**
- What: Update deployment manifests in local GitLab, ArgoCD syncs to cluster
- Tool: ArgoCD (watches local Git repo, pulls images from local Harbor)
- Verify: ArgoCD health checks + custom verification job
- Record: tag the deployment in local Git with timestamp + bundle version

## Tradeoffs

**1. Why scan on connected side, not air-gap?**
- Connected side has up-to-date vulnerability databases (CVE feeds)
- Air-gap side can't update vuln DBs without transferring them (extra complexity)
- Scan BEFORE transfer = gate at the boundary. Don't let bad code into classified networks.
- You CAN also scan on the air-gap side with a periodically-transferred vuln DB — belt and suspenders.

**2. How do you handle a vuln found after transfer?**
- If the vuln is already deployed on air-gap: assess severity
- Critical: roll back to previous version immediately (ArgoCD revert + redeploy)
- Non-critical: fix on connected side, rebuild, re-transfer, redeploy
- Keep previous bundle versions in air-gap registry for fast rollback

**3. How do you handle rollback?**
- ArgoCD: revert the Git commit in local repo → ArgoCD syncs to previous state
- Container images: previous versions stay in Harbor registry (never delete on deploy)
- Bundle archives: keep N previous bundles on air-gap side
- Ansible: re-run with previous config vars (idempotent)

**4. How do you track what's deployed?**
- Git tags in local air-gap GitLab: "deployed-v2.3.1-20260401"
- ArgoCD Application status shows current sync state
- Transfer log: every bundle received has a log entry with hash + timestamp
- Audit trail: who transferred what, when, verified how
