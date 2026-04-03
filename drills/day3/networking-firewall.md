# Day 3: Firewall and iptables Exercises
# Write the rules or commands for each scenario.

---

## Scenario 1: iptables rules

Write iptables commands to:

**a) Allow incoming SSH (port 22) from only the 10.0.1.0/24 subnet:**
```
YOUR ANSWER:

```

**b) Allow incoming HTTPS (port 443) from anywhere:**
```
YOUR ANSWER:

```

**c) Allow the Kubernetes API server port (6443) from the 10.0.0.0/16 network:**
```
YOUR ANSWER:

```

**d) Drop all other incoming traffic (default deny):**
```
YOUR ANSWER:

```

**e) View all rules with packet counts:**
```
YOUR ANSWER:

```

---

## Scenario 2: firewalld (RHEL/CentOS — Anduril uses this)

Write firewall-cmd commands to:

**a) List all currently open ports and services:**
```
YOUR ANSWER:

```

**b) Open ports 6443, 9345, 10250 TCP permanently:**
```
YOUR ANSWER:

```

**c) Add a rich rule: allow TCP port 2379-2380 only from 10.0.1.0/24:**
```
YOUR ANSWER:

```

**d) Reload firewall to apply permanent changes:**
```
YOUR ANSWER:

```

---

## Scenario 3: Diagnosing a firewall issue

A newly deployed RKE2 agent node can't join the cluster. The server is on 10.0.1.10.
The error says "connection refused on port 9345."

**What would you check? Write the commands:**
```
Step 1 (on the agent node):

Step 2 (on the server node):

Step 3 (on the server node):

Step 4:

```
