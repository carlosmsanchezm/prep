# Day 3 ANSWERS: Firewall and iptables

---

## Scenario 1: iptables

**a) Allow SSH from 10.0.1.0/24 only:**
```bash
iptables -A INPUT -p tcp --dport 22 -s 10.0.1.0/24 -j ACCEPT
```

**b) Allow HTTPS from anywhere:**
```bash
iptables -A INPUT -p tcp --dport 443 -j ACCEPT
```

**c) Allow K8s API from 10.0.0.0/16:**
```bash
iptables -A INPUT -p tcp --dport 6443 -s 10.0.0.0/16 -j ACCEPT
```

**d) Default deny incoming:**
```bash
iptables -A INPUT -j DROP
```
(Note: always add ACCEPT rules BEFORE the DROP rule, since iptables processes in order)

**e) View rules with counts:**
```bash
iptables -L -n -v
```
(-L = list, -n = numeric/no DNS, -v = verbose with packet counts)

---

## Scenario 2: firewalld

**a) List all open ports/services:**
```bash
firewall-cmd --list-all
```

**b) Open RKE2 ports permanently:**
```bash
firewall-cmd --add-port=6443/tcp --permanent
firewall-cmd --add-port=9345/tcp --permanent
firewall-cmd --add-port=10250/tcp --permanent
```

**c) Rich rule — etcd ports from specific subnet:**
```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="10.0.1.0/24" port protocol="tcp" port="2379-2380" accept'
```

**d) Reload:**
```bash
firewall-cmd --reload
```

---

## Scenario 3: Diagnosing RKE2 join failure

**Step 1 (agent node) — test connectivity:**
```bash
nc -zv 10.0.1.10 9345
# or: curl -vk https://10.0.1.10:9345
```
→ If "connection refused" → the port isn't open or the service isn't listening

**Step 2 (server node) — check if RKE2 is listening on 9345:**
```bash
ss -tlnp | grep 9345
```
→ If nothing shows → RKE2 server isn't running or isn't configured to listen on 9345

**Step 3 (server node) — check firewall:**
```bash
firewall-cmd --list-all | grep 9345
```
→ If port isn't listed → the firewall is blocking it
→ Fix: `firewall-cmd --add-port=9345/tcp --permanent && firewall-cmd --reload`

**Step 4 — check RKE2 server status:**
```bash
systemctl status rke2-server
journalctl -u rke2-server -f
```
→ Is the server running? Any errors in the logs?

**RKE2 required ports to remember:**
- 6443 — Kubernetes API server
- 9345 — RKE2 supervisor (agent join)
- 10250 — kubelet
- 2379-2380 — etcd (server nodes only)
- 8472/UDP — VXLAN (Flannel/Canal CNI)
