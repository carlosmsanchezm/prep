# Anduril-Specific Scenarios — Practice These

> These are based on REAL problems described in the interview transcripts. Andy or Taylor may ask you to design solutions for these exact challenges.

---

## Scenario 1: Design an Ansible Validation Pipeline

**Context (from Felipe):** "I'm gonna push my Ansible playbook, it's gonna validate it with Ansible Lint. It's gonna spin up a container, run the playbook there to validate. We're gonna set up an actual host that it can also validate against, and then give us... that's our pipeline."

**Design it on paper. Draw the stages, tools, and data flow.**

### Your Answer Should Include:

```
Stage 1: LINT
  - Trigger: MR pushed to GitLab
  - Runner: GitLab runner (Podman executor)
  - Job: Run ansible-lint on all playbooks in the MR
  - Fail if: any lint errors (syntax, best practice violations)

Stage 2: CONTAINER TEST
  - Runner: GitLab runner spins up a Podman container (RHEL base from Nexus)
  - Job: Run the playbook against the container using ansible-playbook --check
  - Or: Actually run the playbook (not just check mode) and verify state
  - Fail if: playbook errors, non-zero exit code

Stage 3: HOST VALIDATION
  - Runner: GitLab runner targets a dedicated test host (via SSH/Ansible inventory)
  - Job: Run the playbook against the real host
  - Verify: Check that the expected state was achieved (services running, files exist, configs correct)
  - Fail if: verification checks fail

Stage 4: MERGE
  - If all stages pass: MR is approved for merge
  - Playbook becomes part of the "official" playbook repository
```

### Key Design Decisions to Explain:
- **Why lint first?** Catches syntax errors before wasting compute on container/host tests
- **Why container AND host?** Container tests are fast and isolated; host tests catch real-world issues (SELinux, network, hardware-specific)
- **Why Podman, not Docker?** They already use Podman — rootless, no daemon, SELinux-compatible
- **Where does Packer fit?** Packer builds the RHEL base image that Stage 2 uses as the test container

---

## Scenario 2: Scale GitLab Runners Under Pressure

**Context (from Felipe):** "In one month we had 100% increase in jobs running through pipelines... we're starting to see some early signs of resource strain."

**The problem:** Pipeline jobs doubled, hardware is ordered but not here yet. How do you optimize what you have?

### Your Answer Should Include:

1. **Triage: tag-based runner allocation**
   - Tag critical jobs (software builds) to dedicated runners
   - Tag non-critical jobs (linting, docs) to shared runners
   - Priority queues: critical > normal > low

2. **Runner scaling with Podman**
   - Spin up additional runners as Podman containers on underutilized hosts
   - Each runner is a rootless Podman container — lightweight, fast startup
   - Use GitLab runner autoscaling: if queue > threshold, spin up temp runner

3. **Job optimization**
   - Cache dependencies between jobs (node_modules, pip packages, etc.)
   - Use `needs:` to parallelize independent stages
   - Reduce image pull time: use Nexus mirror, pre-pull common images on runners

4. **Resource management**
   - Set CPU/memory limits per runner in config.toml
   - Monitor with Prometheus: track queue wait time, job duration, runner utilization
   - If a host is 90%+ CPU from runners, migrate low-priority jobs elsewhere

5. **When hardware arrives**
   - Dedicated runner hosts for different job types
   - Separate build runners (heavy CPU) from test runners (moderate CPU)

---

## Scenario 3: Classified-Side Package Transfer via Diode

**Context (from Felipe):** "Taylor was walking me through... we need to get Python libraries to our classified side... package it all up, so we can then upload it to Nexus."

**Design the end-to-end flow for getting Python libraries (and container images) from the internet to the classified air-gapped network.**

### Your Answer Should Include:

```
UNCLASSIFIED SIDE:
1. Maintain a requirements.txt (or manifest) listing all needed packages + versions
2. GitLab CI job triggers on manifest change:
   a. pip download -r requirements.txt -d ./packages/    (download wheels/tarballs)
   b. podman pull all needed container images
   c. podman save images to .tar files
   d. sha256sum everything → manifest.sha256
   e. tar -czf transfer-bundle-$(date +%Y%m%d).tar.gz packages/ images/ manifest.sha256
3. Push bundle to diode staging directory

TRANSFER:
- Data diode (one-way hardware) — bundle flows to classified side
- No return path — validation happens independently on each side

CLASSIFIED SIDE:
1. Receive bundle from diode output
2. Validate: sha256sum -c manifest.sha256 — reject if any mismatch
3. Unpack Python packages → upload to Nexus PyPI repository
   nexus-cli upload -r pypi-hosted -d ./packages/
4. Unpack container images → podman load < image.tar → podman push to Nexus Docker registry
5. Log: timestamp, bundle name, hash, packages imported, status
6. Developers/admins can now: pip install from Nexus, podman pull from Nexus
```

### Key Points to Make:
- **Manifest-driven:** everything is declared, nothing ad-hoc
- **Checksum verification:** catches corruption or tampering during transfer
- **Nexus as universal registry:** both Python packages AND container images
- **Automatable:** GitLab CI on the unclass side, cron or webhook on the class side

---

## Scenario 4: Introduce Kubernetes to a Podman-First Team

**Context (from Felipe):** "Kubernetes has been a goal... we just haven't had the bandwidth... if you can think of how we can deploy Kubernetes in a way that works and fits our timelines, let's do it."

**How would you propose phasing Kubernetes in without disrupting existing Podman workflows?**

### Your Answer Should Include:

**Phase 0: Prove value (1-2 weeks)**
- Don't touch production. Spin up a single-node RKE2 cluster on a spare machine.
- Run ONE service on it — maybe a GitLab runner — to prove it works.
- Compare: same job on Podman vs K8s. Is there a measurable win?

**Phase 1: CI/CD runners on K8s (2-4 weeks)**
- Move GitLab runners to K8s — this is the lowest-risk migration
- Runners are stateless, ephemeral, easy to roll back
- K8s autoscaling handles the "jobs doubled in a month" problem natively
- Keep all other services on Podman

**Phase 2: Stateless services (month 2-3)**
- Migrate internal tools (documentation pipeline, monitoring dashboards) to K8s
- Use Podman's `podman generate kube` to create initial manifests from existing containers
- Still keep databases and stateful services on Podman/bare-metal

**Phase 3: Full adoption (month 3-6)**
- If Phases 0-2 worked, migrate remaining services
- Stateful services get StatefulSets with persistent volumes
- ArgoCD for GitOps (optional — only if team has bandwidth)

### Key Points to Make:
- **Start with runners** — lowest risk, highest scaling benefit
- **`podman generate kube`** bridges existing Compose → K8s YAML
- **RKE2 for air-gap** — bundled binary, works offline, FIPS support
- **Don't half-ass it** — Felipe's exact words. Phase it so each step is fully tested.
- **Don't disrupt what works** — Podman stays for anything that's stable

---

## Scenario 5: Documentation Pipeline (YAML → GitLab MR → PDF)

**Context (from Felipe):** "I wanna host it in GitLab, 'cause I want revision control... write it in YAML and have a pipeline run that converts it into a PDF."

**Design this pipeline.**

### Your Answer:

```yaml
# .gitlab-ci.yml for docs pipeline
stages:
  - validate
  - build
  - publish

validate-yaml:
  stage: validate
  image: registry.local/python:3.11
  script:
    - pip install yamllint
    - yamllint docs/*.yml
  rules:
    - changes:
        - docs/**

build-pdf:
  stage: build
  image: registry.local/pandoc:latest
  script:
    - for f in docs/*.yml; do
        python3 scripts/yaml-to-markdown.py "$f" > "${f%.yml}.md";
      done
    - for f in docs/*.md; do
        pandoc "$f" -o "${f%.md}.pdf" --pdf-engine=weasyprint;
      done
  artifacts:
    paths:
      - docs/*.pdf
    expire_in: 30 days

publish-to-nexus:
  stage: publish
  script:
    - curl -u admin:$NEXUS_PASSWORD --upload-file docs/*.pdf $NEXUS_URL/repository/docs/
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

### Key Points:
- **YAML source** → version controlled, MR reviews, blame history
- **Pipeline validates** → catches YAML syntax errors before merge
- **Auto-generates PDF** → leadership gets clean docs without anyone touching Word
- **Nexus stores artifacts** → PDFs accessible without GitLab access
- **Tools:** yamllint for validation, Pandoc or mkdocs for rendering, weasyprint for PDF
