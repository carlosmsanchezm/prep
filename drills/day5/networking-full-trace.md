# Day 5: Full Network Trace + "What Breaks If" Exercise
# This is the networking deep-dive Anduril tests.

---

## Exercise 1: Full Packet Trace

**Scenario:** You have an RKE2 cluster on an air-gapped network. Pod "build-agent" needs to pull a container image from the local Harbor registry at harbor.local:443.

**Trace every hop:**
```
Step 1:

Step 2:

Step 3:

Step 4:

Step 5:

Step 6:
```

---

## Exercise 2: "What Breaks If..."

For each failure, describe: what symptom the user sees, and how you'd diagnose it.

**a) CoreDNS pods are evicted due to node memory pressure**
```
Symptom:
Diagnosis:
Fix:
```

**b) The Harbor TLS certificate expired**
```
Symptom:
Diagnosis:
Fix:
```

**c) A NetworkPolicy blocks egress from the build-agent namespace**
```
Symptom:
Diagnosis:
Fix:
```

**d) The CNI plugin (Calico) crashes on one node**
```
Symptom:
Diagnosis:
Fix:
```

**e) iptables rules are flushed accidentally on a node**
```
Symptom:
Diagnosis:
Fix:
```

---

## Exercise 3: RKE2 Networking Specifics

**Question: How does RKE2 networking differ from a vanilla K8s cluster?**
```
YOUR ANSWER (3-4 sentences):

```

**Question: What CNI does RKE2 use by default? What are the alternatives?**
```
YOUR ANSWER:

```

**Question: How do you configure a private registry in RKE2 for air-gap?**
```
YOUR ANSWER (describe the file and its location):

```
