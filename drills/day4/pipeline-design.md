# Day 4: Pipeline Design Exercise
# Design a pipeline ON PAPER. No YAML — just describe stages, tools, and reasoning.

---

## Scenario: Anduril Air-Gap Build Pipeline

You need to design a CI/CD pipeline for Anduril's AIS program. The software is built on the corporate (connected) network and must be transferred to an air-gapped classified network for deployment.

**Constraints:**
- Build happens on corporate GitLab
- Air-gap network has NO internet access
- Transfer is via a one-way diode (data IN only)
- Air-gap side has a local Harbor container registry and a local GitLab
- Software is custom C++/Rust code that builds into container images
- Must scan for vulnerabilities before any transfer
- Need to track what was deployed and when

**Design your pipeline:**

### Connected Side Pipeline
```
Stage 1:
  Name:
  What it does:
  Tool:

Stage 2:
  Name:
  What it does:
  Tool:

Stage 3:
  Name:
  What it does:
  Tool:

Stage 4:
  Name:
  What it does:
  Tool:
```

### Transfer Mechanism
```
How does the artifact get from connected to air-gapped?
What format is it in?
How do you validate it wasn't corrupted?
```

### Air-Gap Side Pipeline
```
Stage 1:
  Name:
  What it does:
  Tool:

Stage 2:
  Name:
  What it does:
  Tool:

Stage 3:
  Name:
  What it does:
  Tool:
```

### Tradeoffs — answer these:
```
1. Why scan on the connected side and not the air-gap side?

2. How do you handle a vulnerability found after transfer?

3. How do you handle rollback if the new version breaks?

4. How do you track what's deployed on the air-gap side?
```
