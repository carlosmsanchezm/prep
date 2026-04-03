# Architecture Practice: Air-Gap Software Delivery Flow

## Exercise: Draw and Narrate

**Instructions:**
1. Draw the end-to-end flow from "developer pushes code" to "software running on air-gapped cluster"
2. Show both sides: connected (low-side) and disconnected (high-side)
3. Show the transfer mechanism between them
4. Narrate each step and explain WHY

---

## What You Should Be Able to Draw

### The Flow (left to right)

```
[CONNECTED SIDE]                           [AIR-GAP SIDE]

Developer pushes to GitLab
        ↓
GitLab CI triggers
        ↓
Pull images from Iron Bank
        ↓
Scan with Trivy (CVE check)
        ↓
Bundle with Zarf (images + charts + manifests)
        ↓
Push bundle to S3
        ↓
    ═══════════════════
    ║  Transfer Layer  ║  (diode / USB / S3 sync)
    ═══════════════════
                                           ↓
                              Pull bundle from transfer point
                                           ↓
                              Validate checksums (hash check)
                                           ↓
                              Unpack to local Harbor registry
                                           ↓
                              GitOps: ArgoCD / FluxCD watches local repo
                                           ↓
                              Deploy to air-gapped K8s cluster
                                           ↓
                              Verification jobs run
```

### Key Components

**Build Runner (connected side):**
- Internet access to pull from Iron Bank / upstream registries
- Trivy for vulnerability scanning — blocks HIGH/CRITICAL
- Zarf CLI for bundling: `zarf package create`
- Output: versioned, content-addressed archive (.tar.zst)
- Pushed to S3 or staging area for transfer

**Transfer Layer:**
- Diode (one-way network device) — data flows IN only, nothing leaks OUT
- OR: USB / removable media for highest classification
- OR: S3 cross-account if same cloud, different VPC
- Content-addressed: only transfer what changed (hash comparison)
- Manifest file lists every package + expected checksum

**Receiver (air-gap side):**
- Script or cron job pulls from diode output / transfer point
- Validates checksums against manifest — reject anything that doesn't match
- Unpacks images into Harbor/Nexus registry
- Unpacks Helm charts into chart repository
- Updates local Git repo with new manifests (if GitOps)

**Deployment (air-gap side):**
- ArgoCD watches local Git repo (NOT github.com — local GitLab or bare repo)
- Pulls images from LOCAL Harbor registry (NOT Docker Hub)
- Syncs desired state to cluster
- Verification jobs confirm deployment succeeded

### One-Off Transfers
- "Hey, I need the latest GitLab version on the high side"
- Developer adds package to manifest → pipeline bundles just that package
- Transfer via diode → validate → unpack into registry
- ArgoCD picks up the new image and syncs

---

## Follow-Up Questions (Answer Aloud)

1. **"What happens if a transfer is corrupted?"**
   - Checksum validation catches it before unpacking
   - Bundle is rejected, logged, and the previous version stays active
   - Alert the team → re-transfer
   - Never deploy unvalidated content

2. **"How do you handle dependency updates?"**
   - Manifest file is declarative: list all deps + versions
   - Pipeline pulls listed deps, scans, bundles
   - Transfer includes the full dependency closure
   - On the air-gap side, old versions stay in registry (don't delete — rollback safety)

3. **"How do you know the air-gap cluster is running what you expect?"**
   - Verification jobs run after every deploy stage
   - Compare running images vs. expected images (from Git)
   - Drift detection: if someone manually changes something, next ArgoCD sync reverts it
   - Hash comparison between bundle manifest and running containers

4. **"What's the biggest challenge with air-gap delivery?"**
   - Version skew: when multiple packages have interdependencies
   - Transfer latency: diode throughput can be slow for large bundles
   - One-offs: ad-hoc requests interrupt the planned release cadence
   - Validation: trusting that what you built on the connected side is what's running on the air-gap side

5. **"How does this relate to what Anduril is doing?"**
   - Anduril has the same challenge: build on low-side, deploy to classified networks
   - They just got a diode live and are automating transfers
   - My experience with Zarf bundling + hash validation + registry population maps directly
   - I would audit their current flow, identify manual steps, and automate them declaratively

---

## Answer Keys + Coaching

- **Real architecture reference:** `vivsoft-answers.md` — Section 8 (Package & Bundle Build System)
- **How to present this:** `deep-dive-coaching-guide.md` — System 2
