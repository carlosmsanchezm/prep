# Tradeoff Questions — Practice Answering Aloud

## Instructions
Pick 5 random questions each day. Answer each one aloud in 60-90 seconds. No notes.

---

## Infrastructure Tradeoffs

### 1. "Why RKE2 over EKS or K3s for air-gap?"
- RKE2: bundled binaries, FIPS support, CIS hardened by default, no cloud dependency
- EKS: managed control plane, but requires internet for API calls, harder to air-gap
- K3s: lightweight, good for edge, but not FIPS compliant, less enterprise features
- **For Anduril:** RKE2 is the right choice for on-prem air-gap because it's self-contained

### 2. "Why Ansible over Terraform on the air-gap side?"
- Ansible: push-based (no state server needed), works offline, agentless (just SSH)
- Terraform: needs state file storage, needs provider plugins (which need internet to download)
- On air-gap: Ansible playbooks are self-contained YAML — transfer the playbook, run it
- Terraform needs: provider binaries, state backend, lock mechanism — all harder offline
- **Note:** Terraform is great for cloud infra (VPCs, EKS). Ansible is great for host config.

### 3. "Why separate IaC from CaC repos?"
- Classification boundary: if they share a repo, the whole repo gets classified on SIPRNET
- Prevents config values from leaking across classification levels
- Allows independent release cadence: config changes don't gate on infra changes
- Tradeoff: more repos = more context switching. Worth it for security.

### 4. "Why Zarf over manual tarballs?"
- Zarf: declarative manifest, versioned, content-addressed, includes validation
- Tarballs: no versioning, no validation, no dependency ordering, manual
- Zarf packages are self-contained: images + charts + manifests in one archive
- UDS handles deployment ordering: core services before enterprise services
- **Key:** hash verification catches corruption or tampering during transfer

### 5. "Why ArgoCD over FluxCD (or vice versa)?"
- ArgoCD: UI for visibility, Application CRD, good for operator visibility
- FluxCD: no UI, Kubernetes-native (HelmRelease CRDs), lighter weight
- At VivSoft: FluxCD for inner loop (Big Bang generates FluxCD resources natively), ArgoCD for mission app delivery
- **For Anduril:** depends on whether they want operator visibility (ArgoCD) or minimal footprint (Flux)

### 6. "Why Crossplane over Terraform for in-cluster resource management?"
- Crossplane: Kubernetes-native, continuously reconciles (if someone deletes a resource, it recreates it)
- Terraform: run-and-done, no continuous reconciliation
- Crossplane fits K8s workflow: declare a claim, platform reconciles
- Terraform fits infra provisioning: plan/apply workflow for VPCs, clusters
- **Use both:** Terraform for base infra, Crossplane for in-cluster self-service

## Operational Tradeoffs

### 7. "Toggle-based pipeline vs. separate pipelines per component?"
- Toggle: single pipeline, deployment order guaranteed, one view of state
- Separate: each component has its own pipeline, more flexible, but no ordering guarantee
- Toggle wins when components have dependencies (core must deploy before enterprise)

### 8. "Ephemeral clusters vs. long-lived dev environments?"
- Ephemeral: clean every time, no state drift, auto-destroy after TTL (8 hours)
- Long-lived: faster to iterate (no wait for provisioning), but drift accumulates
- Best: ephemeral for feature dev, persistent for staging/production

### 9. "Monorepo vs. multi-repo for platform code?"
- Monorepo: one place for everything, easier discovery, atomic commits
- Multi-repo: separation of concerns, classification boundaries, independent release
- Multi-repo won at VivSoft because of classification requirements
- Monorepo might be fine if you're single-classification

### 10. "Hardened custom AMIs vs. runtime hardening?"
- Custom AMIs (Packer + Ansible + OSCAP): hardened at build time, consistent, auditable
- Runtime hardening: apply at boot, slower, risk of drift if hardening fails
- **Always bake it in:** AMI is the baseline, runtime only for dynamic config
- STIG compliance should be measured at build time, not hoped for at runtime

## Air-Gap Specific

### 11. "Diode vs. USB for air-gap transfers?"
- Diode: automated, one-way network device, higher throughput, auditable
- USB: manual, requires physical security, human error risk, but works everywhere
- Diode is better when available — automate the transfer pipeline
- USB for highest classification or when no diode exists

### 12. "How do you handle package updates on air-gap networks?"
- Manifest-driven: maintain a list of all packages + versions
- Pipeline on connected side pulls, scans, bundles on schedule (weekly or on-demand)
- Transfer via diode
- On air-gap side: unpack, validate checksums, update local repos
- Old versions stay in registry for rollback safety

### 13. "Content-addressable storage vs. version-tagged transfers?"
- Content-addressed (hash-based): only transfer what actually changed
- Version-tagged: transfer the full bundle every time
- Content-addressed saves bandwidth on slow diodes
- But version-tagged is simpler and more auditable ("I deployed bundle v2.3.1")
- Best: tag versions AND validate with content hashes

## Security

### 14. "How do you enforce image provenance in K8s?"
- Kyverno admission policy: blocks any image not from Iron Bank / approved registry
- Enforced at API server level — kubectl apply is rejected before pod is created
- Combined with Trivy scanning in the pipeline — images are scanned before bundling
- Defense in depth: scan at build, enforce at admission, monitor at runtime (Neuvector)

### 15. "How do you handle secrets rotation?"
- Vault handles rotation via TTLs on dynamic secrets
- Static secrets: Vault audit log + alert on age
- Certificate rotation: Cert-Manager with automatic renewal
- Application restart: Vault Agent sidecar injects fresh secrets without pod restart
- Never store secrets in Git, env vars, or ConfigMaps
