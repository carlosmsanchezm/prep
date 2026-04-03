# Day 2: Packet Trace Exercise
# Trace the packet through every hop. Write what happens at each step.

---

## Scenario: Pod-to-Pod via Service (same cluster)

Pod "frontend" in namespace "web" calls http://backend-svc.api.svc.cluster.local:8080

**Trace every hop from frontend pod to backend pod:**
```
Step 1:
Step 2:
Step 3:
Step 4:
Step 5:
Step 6:
```

**What would you check if this call is timing out?**
```
YOUR ANSWER:

```

---

## Scenario: Pod-to-External (through NAT)

Pod "worker" needs to reach https://packages.vendor.com to download a library.
The cluster is in a VPC with a NAT Gateway.

**Trace every hop:**
```
Step 1:
Step 2:
Step 3:
Step 4:
Step 5:
Step 6:
Step 7:
Step 8:
```

**What breaks if the NAT Gateway is removed?**
```
YOUR ANSWER:

```

**What breaks if CoreDNS is down?**
```
YOUR ANSWER:

```
